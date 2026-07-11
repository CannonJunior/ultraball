// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
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

/// Ball-focused camera + rolling MediaRecorder for gameplay highlights.
///
/// Each game tick, [update] draws a ball-centred view onto an offscreen
/// canvas; MediaRecorder captures that stream as WebM chunks. A rolling
/// buffer keeps the last ~4s of chunks. When [notifyScore] is called, the
/// pre-buffer is snapshotted and 3s of post-footage is collected; the two
/// are combined into a ~6s clip stored per team.
class HighlightRecorder {
  static const int    _canvasW     = 320;
  static const int    _canvasH     = 180;
  static const int    _fps         = 30;
  static const int    _timesliceMs = 500;   // chunk interval
  static const int    _maxPreChunks = 8;    // ~4s at 500 ms/chunk
  static const double _postSec     = 3.0;

  // World-space viewport (field is 140 × 40 world units)
  static const double _viewW = 36.0;
  static const double _viewH = 20.25; // 16:9 for 320×180 canvas

  late final html.CanvasElement            _canvas;
  late final html.CanvasRenderingContext2D _ctx;

  html.MediaRecorder? _recorder;
  String              _mimeType  = 'video/webm';
  bool                _supported = true;

  // Rolling pre-buffer
  final List<html.Blob> _rollingBuffer = [];

  // Post-score capture state
  bool              _capturingPost = false;
  double            _postTimer     = 0;
  List<html.Blob>   _preSnapshot   = [];
  final List<html.Blob> _postChunks = [];
  String?           _scoringTeam;
  ScoreEvent?       _pendingEvent;

  // Latest clip per team (object URL)
  String? _playerClipUrl;
  String? _opponentClipUrl;

  /// All recorded clips in chronological order (newest last). Max 20.
  final ValueNotifier<List<HighlightClip>> allClips = ValueNotifier([]);

  /// Set this to trigger a specific clip to play in the appropriate panel.
  final ValueNotifier<HighlightClip?> selectedClip = ValueNotifier(null);

  /// Increments each time a clip is finalised; use with ValueListenableBuilder.
  final ValueNotifier<int> clipVersion = ValueNotifier<int>(0);

  HighlightRecorder() {
    _canvas = html.CanvasElement(width: _canvasW, height: _canvasH);
    final ctx = _canvas.getContext('2d');
    if (ctx == null) {
      _supported = false;
      return;
    }
    _ctx = ctx as html.CanvasRenderingContext2D;
    _initRecorder();
  }

  void _initRecorder() {
    try {
      if (html.MediaRecorder.isTypeSupported('video/webm;codecs=vp9')) {
        _mimeType = 'video/webm;codecs=vp9';
      } else if (html.MediaRecorder.isTypeSupported('video/webm;codecs=vp8')) {
        _mimeType = 'video/webm;codecs=vp8';
      }

      // captureStream is not in older Dart html typings — use JS interop
      final stream = js_util.callMethod(_canvas, 'captureStream', [_fps])
          as html.MediaStream;

      final recorder = html.MediaRecorder(stream, {'mimeType': _mimeType});
      recorder.addEventListener('dataavailable', (html.Event event) {
        final dynamic blobEvent = event;
        final blob = blobEvent.data as html.Blob?;
        if (blob != null && (blob.size ) > 0) _onChunk(blob);
      });
      recorder.start(_timesliceMs);
      _recorder = recorder;
    } catch (_) {
      _supported = false;
    }
  }

  void _onChunk(html.Blob chunk) {
    _rollingBuffer.add(chunk);
    if (_rollingBuffer.length > _maxPreChunks) _rollingBuffer.removeAt(0);
    if (_capturingPost) _postChunks.add(chunk);
  }

  /// Call when a scoring event (Ultra or Meta) occurs.
  void notifyScore(ScoreEvent event) {
    if (!_supported || _capturingPost) return;
    _preSnapshot   = List.of(_rollingBuffer);
    _postChunks.clear();
    _capturingPost = true;
    _postTimer     = _postSec;
    _scoringTeam   = event.teamId;
    _pendingEvent  = event;
  }

  /// Render one ball-cam frame and advance post-score timer. Call every tick.
  void update(GameState gs, double dt) {
    if (!_supported) return;
    _renderFrame(gs);
    if (_capturingPost) {
      _postTimer -= dt;
      if (_postTimer <= 0) _finalizeClip();
    }
  }

  void _finalizeClip() {
    _capturingPost = false;
    if (_scoringTeam == null) return;

    final chunks = [..._preSnapshot, ..._postChunks];
    if (chunks.isEmpty) { _scoringTeam = null; _pendingEvent = null; return; }

    final blob = html.Blob(chunks, _mimeType);
    final url  = html.Url.createObjectUrlFromBlob(blob);

    if (_scoringTeam == 'player') {
      _playerClipUrl = url;
    } else {
      _opponentClipUrl = url;
    }

    // Build HighlightClip metadata and add to list.
    // Old URLs must NOT be revoked here — they may still be referenced by
    // earlier entries in allClips. Revoke only when an entry is evicted.
    final event = _pendingEvent;
    if (event != null) {
      final clip = HighlightClip(
        teamId:        event.teamId,
        scorerName:    event.scorerName ?? '—',
        scoreType:     event.scoreType,
        playerScore:   event.playerScore,
        opponentScore: event.opponentScore,
        clipUrl:       url,
      );
      final next = [...allClips.value, clip];
      if (next.length > 20) {
        final evicted = next.removeAt(0);
        html.Url.revokeObjectUrl(evicted.clipUrl);
      }
      allClips.value = next;
    }

    _scoringTeam  = null;
    _pendingEvent = null;
    _preSnapshot  = [];
    _postChunks.clear();
    clipVersion.value++;
  }

  /// Returns the latest clip object URL for [teamId] ('player' or 'opponent'),
  /// or null if no clip has been recorded yet.
  String? getLatestClip(String teamId) =>
      teamId == 'player' ? _playerClipUrl : _opponentClipUrl;

  bool get isSupported => _supported;

  // ── Ball-cam renderer ────────────────────────────────────────────────────────

  void _renderFrame(GameState gs) {
    final ball = gs.ball;

    // Centre view on ball, clamped so the viewport never shows outside the field
    final cx = ball.x.clamp(_viewW / 2, 140.0 - _viewW / 2);
    final cy = ball.y.clamp(_viewH / 2,  40.0 - _viewH / 2);

    final sx = _canvasW / _viewW;
    final sy = _canvasH / _viewH;

    double wx(double worldX) => (worldX - cx + _viewW / 2) * sx;
    double wy(double worldY) => (worldY - cy + _viewH / 2) * sy;

    // Field background
    _ctx.fillStyle = '#1b3d1b';
    _ctx.fillRect(0, 0, _canvasW.toDouble(), _canvasH.toDouble());

    // End zones
    _ctx.fillStyle = '#142814';
    final leftEdge = wx(0);
    final leftZone = wx(20);
    if (leftZone > 0) {
      _ctx.fillRect(leftEdge, 0,
          (leftZone - leftEdge).clamp(0, _canvasW.toDouble()), _canvasH.toDouble());
    }
    final rightZone = wx(120);
    final rightEdge = wx(140);
    if (rightZone < _canvasW) {
      _ctx.fillRect(rightZone.clamp(0, _canvasW.toDouble()), 0,
          (rightEdge - rightZone).clamp(0, _canvasW.toDouble()), _canvasH.toDouble());
    }

    // Phase / midfield lines
    _ctx.strokeStyle = 'rgba(255,255,255,0.13)';
    _ctx.lineWidth   = 1;
    for (final lineX in [30.0, 55.0, 70.0, 85.0, 110.0]) {
      final lx = wx(lineX);
      if (lx < 0 || lx > _canvasW) continue;
      _ctx.beginPath();
      _ctx.moveTo(lx, 0);
      _ctx.lineTo(lx, _canvasH.toDouble());
      _ctx.stroke();
    }

    // Players
    for (final p in gs.fieldPlayers) {
      if (!p.isAlive) continue;
      final px = wx(p.x), py = wy(p.y);
      if (px < -14 || px > _canvasW + 14 || py < -14 || py > _canvasH + 14) continue;

      final isHolder = gs.ball.holderId == p.id;
      final r        = isHolder ? 6.5 : 5.0;

      _ctx.fillStyle = p.team == Team.player ? '#4aa3ff' : '#ff5555';
      _ctx.beginPath();
      _ctx.arc(px, py, r, 0, math.pi * 2);
      _ctx.fill();

      if (isHolder) {
        _ctx.strokeStyle = '#ffffff';
        _ctx.lineWidth   = 1.5;
        _ctx.beginPath();
        _ctx.arc(px, py, r + 3, 0, math.pi * 2);
        _ctx.stroke();
      }
    }

    // Ball when loose / in-flight
    if (!ball.isHeld) {
      final bx = wx(ball.x), by = wy(ball.y);
      if (ball.isInFlight) {
        _ctx.shadowColor = 'rgba(255,255,255,0.7)';
        _ctx.shadowBlur  = 10;
      }
      _ctx.fillStyle = '#ffffff';
      _ctx.beginPath();
      _ctx.arc(bx, by, ball.isInFlight ? 4.5 : 3.5, 0, math.pi * 2);
      _ctx.fill();
      if (ball.isInFlight) _ctx.shadowBlur = 0;
    }
  }

  void dispose() {
    try { _recorder?.stop(); } catch (_) {}
    for (final clip in allClips.value) {
      html.Url.revokeObjectUrl(clip.clipUrl);
    }
    allClips.dispose();
    selectedClip.dispose();
    clipVersion.dispose();
  }
}
