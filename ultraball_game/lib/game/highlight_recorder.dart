// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'package:flutter/foundation.dart';
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

/// Records gameplay by capturing the browser's main render canvas.
///
/// Press R in-game to start a 6-second recording. The clip is added to
/// [allClips] and downloaded automatically when recording finishes.
class HighlightRecorder {
  static const int _fps = 30;

  String _mimeType = 'video/webm';

  final ValueNotifier<bool>             isRecording = ValueNotifier(false);
  html.MediaRecorder?                   _recorder;
  final List<html.Blob>                 _chunks     = [];
  html.Blob?                            _headerChunk;

  // Scores captured at recording-start time (not 6 s later).
  int _capturedPlayerScore   = 0;
  int _capturedOpponentScore = 0;

  // The WebGL canvas supplied by GameWidget for full-3D view mode.
  // Null → auto-detect the largest canvas in the DOM.
  html.CanvasElement? _sourceCanvas;

  String? _latestPlayerClipUrl;

  final ValueNotifier<List<HighlightClip>> allClips    = ValueNotifier([]);
  final ValueNotifier<int>                 clipVersion = ValueNotifier(0);
  void Function(HighlightClip)?            onPlayClipRequest;

  HighlightRecorder() {
    if (html.MediaRecorder.isTypeSupported('video/webm;codecs=vp9')) {
      _mimeType = 'video/webm;codecs=vp9';
    } else if (html.MediaRecorder.isTypeSupported('video/webm;codecs=vp8')) {
      _mimeType = 'video/webm;codecs=vp8';
    }
  }

  /// Called by GameWidget to supply the WebGL canvas in full-3D mode.
  void setSourceCanvas(html.CanvasElement? canvas) => _sourceCanvas = canvas;

  /// Start a 6-second recording of the current game view. No-ops if already
  /// recording or no suitable canvas is found.
  void startRecording(GameState gs) {
    if (isRecording.value) return;

    final canvas = _sourceCanvas ?? _findLargestCanvas();
    if (canvas == null) return;

    try {
      final stream =
          js_util.callMethod(canvas, 'captureStream', [_fps]) as html.MediaStream;

      _chunks.clear();
      _headerChunk               = null;
      _capturedPlayerScore   = gs.actState.playerScore;
      _capturedOpponentScore = gs.actState.opponentScore;

      final recorder = html.MediaRecorder(stream, {'mimeType': _mimeType});
      recorder.addEventListener('dataavailable', (html.Event event) {
        final dynamic blobEvent = event;
        final blob = blobEvent.data as html.Blob?;
        if (blob != null && blob.size > 0) {
          _headerChunk ??= blob;
          _chunks.add(blob);
        }
      });
      recorder.addEventListener('stop', (html.Event _) => _finalizeClip());

      recorder.start(200);
      _recorder       = recorder;
      isRecording.value = true;

      Future.delayed(const Duration(seconds: 6), _stopRecording);
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

  void _stopRecording() {
    final rec = _recorder;
    _recorder = null;
    try { rec?.stop(); } catch (_) {}
  }

  void _finalizeClip() {
    isRecording.value = false;

    final header = _headerChunk;
    final chunks = (header != null)
        ? [header, ..._chunks.where((c) => c != header)]
        : List.of(_chunks);

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

    final next = [...allClips.value, clip];
    if (next.length > 20) {
      final evicted = next.removeAt(0);
      html.Url.revokeObjectUrl(evicted.clipUrl);
    }
    allClips.value = next;
    clipVersion.value++;

    downloadClip(clip);
  }

  String? getLatestClip(String teamId) =>
      teamId == 'player' ? _latestPlayerClipUrl : null;

  bool get isSupported => true;

  /// Download [clip] to the browser's downloads folder. Must be called from a
  /// user-gesture handler; the auto-download in [_finalizeClip] works because
  /// Chrome permits programmatic anchor clicks for local file saves.
  static void downloadClip(HighlightClip clip) {
    try {
      final ts   = clip.scorerName.replaceAll(':', '-');
      final name = 'highlight_${clip.scoreType}_${ts}'
                   '_${clip.playerScore}-${clip.opponentScore}.webm';
      final a = html.AnchorElement()
        ..href     = clip.clipUrl
        ..download = name;
      html.document.body?.children.add(a);
      a.click();
      Future.delayed(const Duration(milliseconds: 100), () => a.remove());
    } catch (_) {}
  }

  void dispose() {
    try { _recorder?.stop(); } catch (_) {}
    isRecording.dispose();
    for (final clip in allClips.value) {
      html.Url.revokeObjectUrl(clip.clipUrl);
    }
    allClips.dispose();
    clipVersion.dispose();
    onPlayClipRequest = null;
  }
}
