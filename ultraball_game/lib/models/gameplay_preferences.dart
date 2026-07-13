import 'package:flutter/material.dart';
import '../ai/ai_strategy.dart';
import 'game_settings.dart';

/// Runtime display and AI preferences — mutable during a match.
/// Stored on GameState so FieldPainter and AiSystem can read them without
/// separate wiring. All values start at their sensible defaults.
class GameplayPreferences {
  // ── Display ──────────────────────────────────────────────────────────────
  bool showHpBars                  = true;
  bool showPlayerNumbers           = true;
  bool showDamageIndicators        = true;
  bool showPhaseLines              = true;
  bool showScoreboardDebugHeights  = false;
  bool showNextQueuedAbilityRange  = true;
  double targetIndicatorSize       = 2.0;

  // Which ability slot icon (1–10) is currently hovered in the HUD.
  // Read by FieldPainter to draw the world-space range circle.
  int? hoveredAbilitySlot;

  // null means "use the value from GameSettings" (the pre-match selection).
  ViewMode? viewModeOverride;

  // ── Combat text ───────────────────────────────────────────────────────────
  // null = system default; 'Bangers' = bundled display font; 'monospace' = mono
  String? combatFontFamily  = 'Bangers';
  double  combatFontScale   = 1.0;
  bool    combatShadow      = true;
  Color   combatDamageColor = const Color(0xFFFFDD00);
  Color   combatHealColor   = const Color(0xFF44FF88);
  Color   combatKillColor   = const Color(0xFFFF2222);

  // ── Opponent AI overrides ─────────────────────────────────────────────────
  AiStrategy? aiStrategyOverride;
  AiTactics?  aiTacticsOverride;
}
