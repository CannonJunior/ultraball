// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/game_state.dart';
import '../game/highlight_recorder.dart';
import 'scoreboard.dart';

// ── Design constants ──────────────────────────────────────────────────────────

const _kPanelWidth   = 340.0;
const _kRedStripW    = 7.0;
const _kWhiteStripW  = 3.0;
const _kAnimDuration = Duration(milliseconds: 550);

// ── Public widget ─────────────────────────────────────────────────────────────

/// Full-width scoreboard row: [left border+panel] [scoreboard 34%] [right border+panel]
class ScoreboardRow extends StatefulWidget {
  final GameState           gs;
  final ValueNotifier<int>  repaint;
  final HighlightRecorder?  recorder;

  const ScoreboardRow({
    super.key,
    required this.gs,
    required this.repaint,
    this.recorder,
  });

  @override
  State<ScoreboardRow> createState() => _ScoreboardRowState();
}

class _ScoreboardRowState extends State<ScoreboardRow>
    with TickerProviderStateMixin {
  late final AnimationController _leftCtrl;
  late final AnimationController _rightCtrl;
  late final Animation<double>   _leftAnim;
  late final Animation<double>   _rightAnim;

  // GlobalKeys give imperative access to each panel's video element.
  final GlobalKey<_HighlightPanelState> _leftPanelKey  = GlobalKey();
  final GlobalKey<_HighlightPanelState> _rightPanelKey = GlobalKey();

  // Track last-seen clip URLs to detect which team just scored.
  String? _lastPlayerUrl;
  String? _lastOpponentUrl;

  @override
  void initState() {
    super.initState();
    _leftCtrl  = AnimationController(vsync: this, duration: _kAnimDuration);
    _rightCtrl = AnimationController(vsync: this, duration: _kAnimDuration);
    _leftAnim  = CurvedAnimation(parent: _leftCtrl,  curve: Curves.easeOutQuart);
    _rightAnim = CurvedAnimation(parent: _rightCtrl, curve: Curves.easeOutQuart);
    widget.recorder?.clipVersion.addListener(_onNewClip);
    widget.recorder?.onPlayClipRequest = _handlePlayClipRequest;
  }

  @override
  void dispose() {
    widget.recorder?.clipVersion.removeListener(_onNewClip);
    widget.recorder?.onPlayClipRequest = null;
    _leftCtrl.dispose();
    _rightCtrl.dispose();
    super.dispose();
  }

  // Called when HighlightRecorder finalizes a new clip.
  void _onNewClip() {
    final rec = widget.recorder;
    if (rec == null) return;

    final playerUrl = rec.getLatestClip('player');
    final oppUrl    = rec.getLatestClip('opponent');

    if (oppUrl != null && oppUrl != _lastOpponentUrl) {
      _lastOpponentUrl = oppUrl;
      _playOnPanel(panelKey: _leftPanelKey, ctrl: _leftCtrl, url: oppUrl);
    }
    if (playerUrl != null && playerUrl != _lastPlayerUrl) {
      _lastPlayerUrl = playerUrl;
      _playOnPanel(panelKey: _rightPanelKey, ctrl: _rightCtrl, url: playerUrl);
    }
  }

  // Called directly (synchronous callback) when the user taps a clip in the list.
  void _handlePlayClipRequest(HighlightClip clip) {
    if (clip.teamId == 'opponent') {
      _playOnPanel(panelKey: _leftPanelKey, ctrl: _leftCtrl, url: clip.clipUrl);
    } else {
      _playOnPanel(panelKey: _rightPanelKey, ctrl: _rightCtrl, url: clip.clipUrl);
    }
  }

  // Start playing a URL in a panel, expand the panel, and force-play after it opens.
  void _playOnPanel({
    required GlobalKey<_HighlightPanelState> panelKey,
    required AnimationController ctrl,
    required String url,
  }) {
    panelKey.currentState?.playUrl(url);
    if (ctrl.value < 1.0) {
      ctrl.forward().whenComplete(() => panelKey.currentState?.forcePlay());
    } else {
      panelKey.currentState?.forcePlay();
    }
  }

  void _toggleLeft() {
    if (_leftCtrl.isDismissed || _leftCtrl.status == AnimationStatus.reverse) {
      _leftCtrl.forward();
    } else {
      _leftCtrl.reverse();
    }
  }

  void _toggleRight() {
    if (_rightCtrl.isDismissed || _rightCtrl.status == AnimationStatus.reverse) {
      _rightCtrl.forward();
    } else {
      _rightCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gs        = widget.gs;
    final away      = gs.settings.awayTeamName;
    final home      = gs.settings.homeTeamName;
    final awayColor = Color(gs.settings.awayTeamPrimary);
    final homeColor = Color(gs.settings.homeTeamPrimary);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Left side (away / opponent) ─────────────────────────────────────
        // Stack+Positioned(top:0,bottom:0) propagates the tight row height
        // (set by IntrinsicHeight + crossAxisAlignment.stretch) into the inner
        // Row, so the panel fills the full scoreboard height. Align(centerRight)
        // was replaced because Align always converts tight constraints to loose,
        // making the inner Row size to its children's intrinsic height instead.
        Expanded(
          flex: 33,
          child: Stack(
            children: [
              Positioned(
                top: 0, bottom: 0, right: 0,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _toggleLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _BorderStrip(width: _kRedStripW, color: awayColor, glow: true),
                        SizeTransition(
                          sizeFactor:    _leftAnim,
                          axis:          Axis.horizontal,
                          axisAlignment: 1.0,
                          child: SizedBox(
                            width: _kPanelWidth,
                            child: _HighlightPanel(
                              key:          _leftPanelKey,
                              teamName:     away,
                              teamColor:    awayColor,
                              labelRight:   false,
                              openFraction: _leftAnim,
                            ),
                          ),
                        ),
                        _BorderStrip(width: _kWhiteStripW, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Scoreboard (center ~34%) ────────────────────────────────────────
        Expanded(
          flex: 34,
          child: ValueListenableBuilder<int>(
            valueListenable: widget.repaint,
            builder: (_, __, ___) => Scoreboard(gs: gs),
          ),
        ),

        // ── Right side (home / player) ──────────────────────────────────────
        Expanded(
          flex: 33,
          child: Stack(
            children: [
              Positioned(
                top: 0, bottom: 0, left: 0,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _toggleRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _BorderStrip(width: _kWhiteStripW, color: Colors.white),
                        SizeTransition(
                          sizeFactor:    _rightAnim,
                          axis:          Axis.horizontal,
                          axisAlignment: -1.0,
                          child: SizedBox(
                            width: _kPanelWidth,
                            child: _HighlightPanel(
                              key:          _rightPanelKey,
                              teamName:     home,
                              teamColor:    homeColor,
                              labelRight:   true,
                              openFraction: _rightAnim,
                            ),
                          ),
                        ),
                        _BorderStrip(width: _kRedStripW, color: homeColor, glow: true),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Thin always-visible border strip ─────────────────────────────────────────

class _BorderStrip extends StatelessWidget {
  final double width;
  final Color  color;
  final bool   glow;

  const _BorderStrip({required this.width, required this.color, this.glow = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: color,
        boxShadow: glow
          ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 16)]
          : null,
      ),
    );
  }
}

// ── Highlight panel — stable video element, controlled imperatively ───────────

class _HighlightPanel extends StatefulWidget {
  final String            teamName;
  final Color             teamColor;
  final bool              labelRight;
  /// The same Animation<double> driving SizeTransition — used to skip
  /// placeholder rendering when the panel is collapsed (value ≈ 0), avoiding
  /// layout assertions on fixed-size children at zero width.
  final Animation<double> openFraction;

  const _HighlightPanel({
    super.key,
    required this.teamName,
    required this.teamColor,
    required this.labelRight,
    required this.openFraction,
  });

  @override
  State<_HighlightPanel> createState() => _HighlightPanelState();
}

class _HighlightPanelState extends State<_HighlightPanel> {
  late final String _viewType;
  html.VideoElement? _videoEl;
  String? _pendingUrl; // queued until factory creates _videoEl
  bool _hasClip = false;

  @override
  void initState() {
    super.initState();
    // Unique viewType per state instance — never changes, never re-registered.
    _viewType = 'ultraball-panel-${identityHashCode(this)}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
      final el = html.VideoElement()
        ..muted    = true
        ..loop     = true
        ..controls = false
        ..setAttribute('playsinline', '')
        ..style.width     = '100%'
        ..style.height    = '100%'
        ..style.objectFit = 'cover';
      _videoEl = el;
      // Play any URL that arrived before the factory was called.
      if (_pendingUrl != null) {
        el.src = _pendingUrl!;
        el.load();
        el.play().catchError((_) {});
        if (mounted) setState(() => _hasClip = true);
      }
      return el;
    });
  }

  /// Start playing [url] in this panel. Safe to call before the factory fires.
  void playUrl(String url) {
    _pendingUrl = url;
    if (_videoEl != null) {
      _videoEl!.src = url;
      _videoEl!.load();
      _videoEl!.play().catchError((_) {});
      if (!_hasClip && mounted) setState(() => _hasClip = true);
    }
    // If _videoEl is null, factory not yet called — _pendingUrl is consumed there.
  }

  /// Re-issue play() after the panel animation completes to defeat browser throttling.
  void forcePlay() => _videoEl?.play().catchError((_) {});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.openFraction,
      builder: (_, __) {
        final panelOpen = widget.openFraction.value > 0.01;
        return Stack(
      children: [
        // Diagonal stripe background
        Positioned.fill(
          child: CustomPaint(painter: _DiagStripesPainter()),
        ),

        // Always-present video element (factory called on first paint)
        Positioned.fill(
          child: HtmlElementView(viewType: _viewType),
        ),

        // Placeholder shown until first clip arrives (hidden when collapsed)
        if (panelOpen && !_hasClip)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width:  48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape:     BoxShape.circle,
                    color:     widget.teamColor.withValues(alpha: 0.92),
                    boxShadow: [BoxShadow(
                      color:      widget.teamColor.withValues(alpha: 0.60),
                      blurRadius: 24,
                    )],
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: CustomPaint(
                        size:    const Size(15, 20),
                        painter: _PlayTrianglePainter(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 11),
                Text(
                  'GAMEPLAY HIGHLIGHT',
                  style: GoogleFonts.chakraPetch(
                    fontSize:      11,
                    fontWeight:    FontWeight.w700,
                    letterSpacing: 2.0,
                    color:         Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'score to record a clip',
                  style: TextStyle(
                    fontFamily:    'monospace',
                    fontSize:      9,
                    letterSpacing: 1.0,
                    color:         Colors.white.withValues(alpha: 0.40),
                  ),
                ),
              ],
            ),
          ),

        // Team label in top corner (hidden when collapsed)
        if (panelOpen)
          Positioned(
            top:   11,
            left:  widget.labelRight ? null : 13,
            right: widget.labelRight ? 13   : null,
            child: Text(
              '● REC  ·  ${widget.teamName}',
              style: GoogleFonts.chakraPetch(
                fontSize:      9,
                fontWeight:    FontWeight.w700,
                letterSpacing: 2.2,
                color:         widget.teamColor.withValues(alpha: 0.9),
              ),
            ),
          ),
      ],
        );
      },
    );
  }
}

// ── Diagonal stripe background painter ───────────────────────────────────────

class _DiagStripesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0A0C12),
    );

    final stripePaint = Paint()..color = const Color(0xFF0F1118);
    const pitch = 26.0;
    for (double x = -size.height; x < size.width + size.height; x += pitch) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + 13, 0)
        ..lineTo(x + 13 + size.height, size.height)
        ..lineTo(x + size.height, size.height)
        ..close();
      canvas.drawPath(path, stripePaint);
    }
  }

  @override
  bool shouldRepaint(_DiagStripesPainter _) => false;
}

// ── Play button triangle painter ──────────────────────────────────────────────

class _PlayTrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size sz) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(sz.width, sz.height / 2)
      ..lineTo(0, sz.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_PlayTrianglePainter _) => false;
}
