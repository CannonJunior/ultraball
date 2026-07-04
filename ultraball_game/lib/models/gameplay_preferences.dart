import '../ai/ai_strategy.dart';

/// Runtime display and AI preferences — mutable during a match.
/// Stored on GameState so FieldPainter and AiSystem can read them without
/// separate wiring. All values start at their sensible defaults.
class GameplayPreferences {
  // ── Display ──────────────────────────────────────────────────────────────
  bool showHpBars          = true;
  bool showPlayerNumbers   = true;
  bool showDamageIndicators = true;
  bool showPhaseLines      = true;

  // ── Opponent AI overrides ─────────────────────────────────────────────────
  // null means "use the value from GameSettings" (the pre-match selection).
  AiStrategy? aiStrategyOverride;
  AiTactics?  aiTacticsOverride;
}
