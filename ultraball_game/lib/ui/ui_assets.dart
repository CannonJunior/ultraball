import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/player_class.dart';
import 'ui_theme.dart';

/// Central access point for SVG icon assets.
///
/// Every icon has a fallback widget (plain colored text/shape) so the game
/// renders correctly even if an SVG file is missing. To replace an icon, drop
/// a new SVG into the matching path in `assets/ui/` and hot-restart.
///
/// SVG files must use `fill="currentColor"` so the [colorFilter] tinting works.
class UiAssets {
  UiAssets._();

  static const _classIconDir = 'assets/ui/class_icons';
  static const _scoreIconDir = 'assets/ui/score_icons';

  // ── Class icons ────────────────────────────────────────────────────────────

  /// Returns an SVG icon for the given class, tinted to [color].
  /// Falls back to a small colored text label if the asset fails to load.
  static Widget classIcon(
    PlayerClass cls, {
    double size = 20,
    Color? color,
  }) {
    final tint = color ?? classColor(cls);
    return SvgPicture.asset(
      '$_classIconDir/${cls.name}.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
    );
  }

  /// Fallback text badge for contexts where SVG is not appropriate.
  static Widget classBadge(PlayerClass cls, {double fontSize = 8}) {
    final color = classColor(cls);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(
        cls.displayName,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ── Score type icons ───────────────────────────────────────────────────────

  /// Returns an SVG icon for a score type: 'ultra', 'meta', or 'killa'.
  static Widget scoreIcon(
    String type, {
    double size = 14,
    Color? color,
  }) {
    final tint = color ?? _scoreColor(type);
    return SvgPicture.asset(
      '$_scoreIconDir/$type.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
    );
  }

  // ── Color lookups (mirrors UiTheme for convenience) ───────────────────────

  static Color classColor(PlayerClass cls) {
    final t = UiTheme.instance;
    return switch (cls) {
      PlayerClass.spectre   => t.classSpectreColor,
      PlayerClass.corsair   => t.classCorsairColor,
      PlayerClass.geomancer => t.classGeomancerColor,
      PlayerClass.archon    => t.classArchonColor,
      PlayerClass.warden    => t.classWardenColor,
      PlayerClass.trickster => t.classTricksterColor,
      PlayerClass.wrecker   => t.classWreckerColor,
    };
  }

  static Color _scoreColor(String type) {
    final t = UiTheme.instance;
    return switch (type) {
      'ultra' => t.scoreUltraColor,
      'meta'  => t.scoreMetaColor,
      'killa' => t.scoreKillaColor,
      _       => t.accentColor,
    };
  }
}
