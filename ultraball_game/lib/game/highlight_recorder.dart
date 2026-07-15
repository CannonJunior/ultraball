// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'package:flutter/foundation.dart';
import '../models/game_settings.dart';
import '../models/player.dart';
import 'game_state.dart';

class HighlightClip {
  final String teamId;
  final String scorerName;
  final String scoreType;
  final int playerScore;
  final int opponentScore;
  final String clipUrl;

  const HighlightClip({
    required this.teamId,
    required this.scorerName,
    required this.scoreType,
    required this.playerScore,
    required this.opponentScore,
    required this.clipUrl,
  });
}

/// Two recording modes, sharing the same clip list:
///
/// AUTO  — Captures the live game canvas (same source as manual recording so
///         the view mode is honoured).  A fresh MediaRecorder starts when the
///         ball carrier crosses the 2nd-to-last phase line heading toward the
///         end zone and stops 3 s after an Ultra is scored.
///
/// MANUAL — Live browser-canvas capture.  Press R for a 6-second clip.
class HighlightRecorder {
  // ── Auto-recording constants ─────────────────────────────────────────────
  static const int    _fps              = 30;
  static const int    _timesliceMs      = 200;
  static const double _postSec          = 3.0;
  static const double _armTimeoutSec    = 15.0;
  // Threshold X-coords for the 2nd-to-last phase line in each direction.
  //   Player team attacks LEFT end zone (x ≤ 20):  2nd-to-last line = x 55
  //   Opponent attacks RIGHT end zone  (x ≥ 120):  2nd-to-last line = x 85
  static const double _playerThreshold   = 55.0;
  static const double _opponentThreshold = 85.0;

  String _mimeType = 'video/webm';

  // ── Auto recording state ─────────────────────────────────────────────────
  html.MediaRecorder?   _autoRecorder;
  final List<html.Blob> _autoChunks = [];
  /// Incremented on every cancel so stale dataavailable/stop events are ignored.
  int                   _autoGen    = 0;

  bool   _armed      = false;
  String? _armedTeam;
  double  _armTimeout = 0.0;

  bool   _capturingPost = false;
  double _postTimer     = 0.0;

  // Metadata written by notifyUltraScored, consumed by _finalizeAutoClip.
  String? _pendingTeam;
  String? _pendingScorerName;
  int     _pendingPlayerScore   = 0;
  int     _pendingOpponentScore = 0;

  // ── Manual (R-key) recording ─────────────────────────────────────────────
  final ValueNotifier<bool> isRecording     = ValueNotifier(false);
  html.CanvasElement?       _sourceCanvas;   // WebGL canvas (3D) or null → auto-detect
  html.MediaRecorder?       _manualRecorder;
  final List<html.Blob>     _manualChunks   = [];
  int _capturedPlayerScore   = 0;
  int _capturedOpponentScore = 0;

  // ── Shared clip storage ──────────────────────────────────────────────────
  final ValueNotifier<List<HighlightClip>> allClips    = ValueNotifier([]);
  final ValueNotifier<int>                 clipVersion = ValueNotifier(0);
  void Function(HighlightClip)?            onPlayClipRequest;

  String? _latestPlayerClipUrl;
  String? _latestOpponentClipUrl;
  String? _latestThirdClipUrl;

  // ────────────────────────────────────────────────────────────────────────
  HighlightRecorder() {
    _selectMimeType();
  }

  void _selectMimeType() {
    if (html.MediaRecorder.isTypeSupported('video/webm;codecs=vp9')) {
      _mimeType = 'video/webm;codecs=vp9';
    } else if (html.MediaRecorder.isTypeSupported('video/webm;codecs=vp8')) {
      _mimeType = 'video/webm;codecs=vp8';
    }
  }

  // ── Per-tick entry points (called by GameWidget) ─────────────────────────

  void update(GameState gs, double dt) {
    if (_armed && !_capturingPost) {
      _armTimeout -= dt;
      if (_armTimeout <= 0) _cancelAutoRecording();
    }

    if (_capturingPost) {
      _postTimer -= dt;
      if (_postTimer <= 0) _stopAutoRecording();
    }
  }

  void checkBallCarrierCrossing(GameState gs) {
    if (_capturingPost) return;

    // 3-team field geometry doesn't use the 2-team threshold lines — scoring
    // notifications via notifyUltraScored are sufficient to trigger recording.
    if (gs.settings.matchMode == MatchMode.threeTeams) {
      if (_armed) _cancelAutoRecording();
      return;
    }

    final ball = gs.ball;
    if (!ball.isHeld) {
      if (_armed) _cancelAutoRecording();
      return;
    }

    final holder = gs.getPlayerById(ball.holderId!);
    if (holder == null) return;

    final holderTeam = holder.team == Team.player ? 'player' : 'opponent';

    if (_armed) {
      if (holderTeam != _armedTeam) _cancelAutoRecording();
      return;
    }

    final crossed = holder.team == Team.player
        ? holder.x < _playerThreshold
        : holder.x > _opponentThreshold;

    if (crossed) {
      _armed      = true;
      _armedTeam  = holderTeam;
      _armTimeout = _armTimeoutSec;
      _startAutoRecording();
    }
  }

  void notifyUltraScored(
    String teamId,
    String? scorerName,
    int playerScore,
    int opponentScore,
  ) {
    if (_capturingPost) return;

    // If armed for the wrong team, cancel and start fresh for the actual scorer.
    if (_armed && _armedTeam != teamId) _cancelAutoRecording();

    // If no recording is running (e.g. carrier bypassed the threshold line),
    // start one now so we at least capture post-score footage.
    if (_autoRecorder == null) _startAutoRecording();

    _capturingPost        = true;
    _postTimer            = _postSec;
    _armed                = false;
    _armedTeam            = null;
    _pendingTeam          = teamId;
    _pendingScorerName    = scorerName ?? '—';
    _pendingPlayerScore   = playerScore;
    _pendingOpponentScore = opponentScore;
  }

  // ── Auto recording internals ─────────────────────────────────────────────

  void _startAutoRecording() {
    final canvas = _sourceCanvas ?? _findLargestCanvas();
    if (canvas == null) return;
    // Cancel any in-flight recording first.
    if (_autoRecorder != null) _cancelAutoRecording();

    final gen = ++_autoGen;
    _autoChunks.clear();

    try {
      final stream =
          js_util.callMethod(canvas, 'captureStream', [_fps]) as html.MediaStream;
      final recorder = html.MediaRecorder(stream, {'mimeType': _mimeType});

      recorder.addEventListener('dataavailable', (html.Event event) {
        if (_autoGen != gen) return; // stale event from a cancelled recording
        final dynamic blobEvent = event;
        final blob = blobEvent.data as html.Blob?;
        if (blob != null && blob.size > 0) _autoChunks.add(blob);
      });
      recorder.addEventListener('stop', (html.Event _) {
        if (_autoGen == gen) _finalizeAutoClip();
        // else: cancelled — do nothing (chunks already cleared by _cancelAutoRecording)
      });

      recorder.start(_timesliceMs);
      _autoRecorder = recorder;
    } catch (_) {}
  }

  /// Stop recording and request finalization via the 'stop' event.
  void _stopAutoRecording() {
    // Leave _autoGen unchanged so the 'stop' event triggers _finalizeAutoClip.
    final rec = _autoRecorder;
    _autoRecorder = null;
    try { rec?.stop(); } catch (_) {}
  }

  /// Abort recording and discard all collected chunks.
  void _cancelAutoRecording() {
    ++_autoGen; // invalidates pending dataavailable / stop callbacks
    final rec = _autoRecorder;
    _autoRecorder  = null;
    _autoChunks.clear();
    _armed         = false;
    _armedTeam     = null;
    _armTimeout    = 0.0;
    _capturingPost = false;
    try { rec?.stop(); } catch (_) {}
  }

  void _finalizeAutoClip() {
    _capturingPost = false;

    final chunks = List.of(_autoChunks);
    _autoChunks.clear();
    if (chunks.isEmpty) { _clearPending(); return; }

    final blob   = html.Blob(chunks, _mimeType);
    final url    = html.Url.createObjectUrlFromBlob(blob);
    final teamId = _pendingTeam ?? 'player';

    if (teamId == 'player') {
      _latestPlayerClipUrl = url;
    } else if (teamId == 'third') {
      _latestThirdClipUrl = url;
    } else {
      _latestOpponentClipUrl = url;
    }

    final clip = HighlightClip(
      teamId:        teamId,
      scorerName:    _pendingScorerName ?? '—',
      scoreType:     'Ultra',
      playerScore:   _pendingPlayerScore,
      opponentScore: _pendingOpponentScore,
      clipUrl:       url,
    );

    _addClip(clip);
    _clearPending();
  }

  void _clearPending() {
    _pendingTeam          = null;
    _pendingScorerName    = null;
    _pendingPlayerScore   = 0;
    _pendingOpponentScore = 0;
  }

  // ── Manual R-key recording ───────────────────────────────────────────────

  void setSourceCanvas(html.CanvasElement? canvas) => _sourceCanvas = canvas;

  void startRecording(GameState gs) {
    if (isRecording.value) return;

    final canvas = _sourceCanvas ?? _findLargestCanvas();
    if (canvas == null) return;

    try {
      final stream =
          js_util.callMethod(canvas, 'captureStream', [_fps]) as html.MediaStream;

      _manualChunks.clear();
      _capturedPlayerScore   = gs.actState.playerScore;
      _capturedOpponentScore = gs.actState.opponentScore;

      final recorder = html.MediaRecorder(stream, {'mimeType': _mimeType});
      recorder.addEventListener('dataavailable', (html.Event event) {
        final dynamic blobEvent = event;
        final blob = blobEvent.data as html.Blob?;
        if (blob != null && blob.size > 0) _manualChunks.add(blob);
      });
      recorder.addEventListener('stop', (html.Event _) => _finalizeManualClip());

      recorder.start(200);
      _manualRecorder   = recorder;
      isRecording.value = true;

      Future.delayed(const Duration(seconds: 6), _stopManualRecording);
    } catch (_) {}
  }

  html.CanvasElement? _findLargestCanvas() {
    final nodes = html.document.querySelectorAll('canvas');
    html.CanvasElement? largest;
    int largestArea = 0;
    for (final node in nodes) {
      if (node is! html.CanvasElement) continue;
      final area = (node.width ?? 0) * (node.height ?? 0);
      if (area > largestArea) {
        largestArea = area;
        largest = node;
      }
    }
    return largest;
  }

  void _stopManualRecording() {
    final rec = _manualRecorder;
    _manualRecorder = null;
    try { rec?.stop(); } catch (_) {}
  }

  void _finalizeManualClip() {
    isRecording.value = false;

    final chunks = List.of(_manualChunks);
    _manualChunks.clear();
    if (chunks.isEmpty) return;

    final blob = html.Blob(chunks, _mimeType);
    final url  = html.Url.createObjectUrlFromBlob(blob);
    _latestPlayerClipUrl = url;

    final now   = DateTime.now();
    final label = '${now.hour.toString().padLeft(2, '0')}'
                  ':${now.minute.toString().padLeft(2, '0')}'
                  ':${now.second.toString().padLeft(2, '0')}';

    final clip = HighlightClip(
      teamId:        'player',
      scorerName:    label,
      scoreType:     'REC',
      playerScore:   _capturedPlayerScore,
      opponentScore: _capturedOpponentScore,
      clipUrl:       url,
    );

    _addClip(clip);
  }

  // ── Shared helpers ───────────────────────────────────────────────────────

  void _addClip(HighlightClip clip) {
    final next = [...allClips.value, clip];
    if (next.length > 20) {
      final evicted = next.removeAt(0);
      html.Url.revokeObjectUrl(evicted.clipUrl);
    }
    allClips.value = next;
    clipVersion.value++;
  }

  String? getLatestClip(String teamId) => switch (teamId) {
    'player'   => _latestPlayerClipUrl,
    'third'    => _latestThirdClipUrl,
    _          => _latestOpponentClipUrl,
  };

  static void downloadClip(HighlightClip clip) {
    try {
      final ts   = clip.scorerName.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
      final name = '${clip.teamId}_${clip.scoreType}_${ts}'
                   '_${clip.playerScore}-${clip.opponentScore}.webm';
      final a = html.AnchorElement()
        ..href     = clip.clipUrl
        ..download = name;
      html.document.body?.children.add(a);
      a.click();
      Future.delayed(const Duration(milliseconds: 100), () => a.remove());
    } catch (_) {}
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  void dispose() {
    ++_autoGen; // invalidate any in-flight dataavailable / stop callbacks
    try { _autoRecorder?.stop(); } catch (_) {}
    try { _manualRecorder?.stop(); } catch (_) {}
    isRecording.dispose();
    for (final clip in allClips.value) {
      html.Url.revokeObjectUrl(clip.clipUrl);
    }
    allClips.dispose();
    clipVersion.dispose();
    onPlayClipRequest = null;
  }
}
