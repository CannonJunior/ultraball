import '../ai/ai_strategy.dart';
import 'game_settings.dart';

/// Runtime display and AI preferences — mutable during a match.
/// Stored on GameState so FieldPainter and AiSystem can read them without
/// separate wiring. All values start at their sensible defaults.
class GameplayPreferences {
  // ── Display ──────────────────────────────────────────────────────────────
  bool showHpBars              = true;
  bool showPlayerNumbers       = true;
  bool showDamageIndicators    = true;
  bool showPhaseLines          = true;
  bool showScoreboardDebugHeights = false;
  double targetIndicatorSize   = 2.0;

  // null means "use the value from GameSettings" (the pre-match selection).
  ViewMode? viewModeOverride;

  // ── Opponent AI overrides ─────────────────────────────────────────────────
  AiStrategy? aiStrategyOverride;
  AiTactics?  aiTacticsOverride;
}
