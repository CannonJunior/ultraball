import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../game/game_state.dart';
import 'scoreboard.dart';

// ── Design constants ──────────────────────────────────────────────────────────
const _kRed  = Color(0xFFFF3B53);
const _kBlue = Color(0xFF2F83FF);

const _kPanelWidth   = 340.0;
const _kRedStripW    = 7.0;
const _kWhiteStripW  = 3.0;
const _kAnimDuration = Duration(milliseconds: 550);

// ── Public widget ─────────────────────────────────────────────────────────────

/// Full-width scoreboard row: [left border+panel] [scoreboard 34%] [right border+panel]
class ScoreboardRow extends StatefulWidget {
  final GameState           gs;
  final ValueNotifier<int>  repaint;

  const ScoreboardRow({super.key, required this.gs, required this.repaint});

  @override
  State<ScoreboardRow> createState() => _ScoreboardRowState();
}

class _ScoreboardRowState extends State<ScoreboardRow> {
  bool _leftOpen  = false;
  bool _rightOpen = false;

  @override
  Widget build(BuildContext context) {
    final gs   = widget.gs;
    final away = gs.settings.awayTeamName;
    final home = gs.settings.homeTeamName;

    return LayoutBuilder(builder: (ctx, con) {
      final sbW = con.maxWidth * 0.34;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Left side ───────────────────────────────────────────────────────
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _leftOpen = !_leftOpen),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Outer red strip (always visible)
                      _BorderStrip(
                        width: _kRedStripW,
                        color: _kRed,
                        glow:  true,
                      ),
                      // Expanding highlight panel
                      ClipRect(
                        child: AnimatedContainer(
                          width:    _leftOpen ? _kPanelWidth : 0,
                          duration: _kAnimDuration,
                          curve:    Curves.easeOutQuart,
                          child: SizedBox(
                            width: _kPanelWidth,
                            child: _HighlightPanel(
                              teamName:   away,
                              teamColor:  _kRed,
                              labelRight: false,
                            ),
                          ),
                        ),
                      ),
                      // Inner white separator (always visible)
                      _BorderStrip(width: _kWhiteStripW, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Scoreboard (center third) ───────────────────────────────────────
          ValueListenableBuilder<int>(
            valueListenable: widget.repaint,
            builder: (_, __, ___) => SizedBox(
              width: sbW,
              child: Scoreboard(gs: gs),
            ),
          ),

          // ── Right side ──────────────────────────────────────────────────────
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _rightOpen = !_rightOpen),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Inner white separator (always visible)
                      _BorderStrip(width: _kWhiteStripW, color: Colors.white),
                      // Expanding highlight panel
                      ClipRect(
                        child: AnimatedContainer(
                          width:    _rightOpen ? _kPanelWidth : 0,
                          duration: _kAnimDuration,
                          curve:    Curves.easeOutQuart,
                          child: SizedBox(
                            width: _kPanelWidth,
                            child: _HighlightPanel(
                              teamName:   home,
                              teamColor:  _kBlue,
                              labelRight: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
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

// ── Highlight panel content ───────────────────────────────────────────────────

class _HighlightPanel extends StatelessWidget {
  final String teamName;
  final Color  teamColor;
  final bool   labelRight; // true = label in top-right corner

  const _HighlightPanel({
    required this.teamName,
    required this.teamColor,
    required this.labelRight,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Diagonal stripe background
        Positioned.fill(
          child: CustomPaint(painter: _DiagStripesPainter()),
        ),

        // Centered content
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Play button circle
              Container(
                width:  48,
                height: 48,
                decoration: BoxDecoration(
                  shape:     BoxShape.circle,
                  color:     teamColor.withValues(alpha: 0.92),
                  boxShadow: [BoxShadow(
                    color:      teamColor.withValues(alpha: 0.60),
                    blurRadius: 24,
                  )],
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: CustomPaint(
                      size: const Size(15, 20),
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
                'drop video clip here',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize:   9,
                  letterSpacing: 1.0,
                  color: Colors.white.withValues(alpha: 0.40),
                ),
              ),
            ],
          ),
        ),

        // Team label in top corner
        Positioned(
          top:   11,
          left:  labelRight ? null : 13,
          right: labelRight ? 13   : null,
          child: Text(
            '● REC  ·  $teamName',
            style: GoogleFonts.chakraPetch(
              fontSize:      9,
              fontWeight:    FontWeight.w700,
              letterSpacing: 2.2,
              color:         teamColor.withValues(alpha: 0.9),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Diagonal stripe background painter ───────────────────────────────────────

class _DiagStripesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Base fill
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0A0C12),
    );

    // Lighter diagonal stripes at 135° (matches CSS repeating-linear-gradient 135deg)
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
