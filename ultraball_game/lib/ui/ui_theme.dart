import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Singleton holding every visual token for Ultraball's UI.
///
/// Loaded from `assets/ui/theme.json` at startup. Any field missing from the
/// JSON file falls back to the hardcoded default. If the file is malformed or
/// absent the full default theme is used silently — the game always runs.
///
/// To override: edit `assets/ui/theme.json` and hot-restart.
class UiTheme {
  static UiTheme _instance = const UiTheme._();
  static UiTheme get instance => _instance;

  // ── Team / accent ──────────────────────────────────────────────────────────
  final Color homeTeamColor;
  final Color awayTeamColor;
  final Color accentColor;

  // ── Score type ─────────────────────────────────────────────────────────────
  final Color scoreUltraColor;
  final Color scoreMetaColor;
  final Color scoreKillaColor;

  // ── Surfaces ───────────────────────────────────────────────────────────────
  final Color backgroundColor;
  final Color surfaceColor;
  final Color borderSubtleColor;
  final Color borderAccentColor;

  // ── Class colors ───────────────────────────────────────────────────────────
  final Color classSpectreColor;
  final Color classCorsairColor;
  final Color classGeomancerColor;
  final Color classArchonColor;
  final Color classWardenColor;
  final Color classTricksterColor;
  final Color classWreckerColor;

  // ── Field / phase ──────────────────────────────────────────────────────────
  final Color phaseActiveColor;
  final Color phaseInactiveColor;

  // ── Status ─────────────────────────────────────────────────────────────────
  final Color aliveColor;
  final Color deadColor;

  // ── Scoreboard knobs ───────────────────────────────────────────────────────
  final double scoreboardScoreSize;
  final double scoreboardTimerSize;
  final double scoreboardTeamNameSize;
  final double scoreboardSubInfoSize;
  final bool scoreboardShowAliveCount;
  final bool scoreboardShowScoreBreakdown;
  final bool scoreboardShowActHistory;
  final double scoreboardBackgroundOpacity;
  final double scoreboardBorderOpacity;

  // ── Damage meter ───────────────────────────────────────────────────────────
  final bool damageMeterDefaultVisible;
  final String damageMeterDefaultTab;
  final bool damageMeterShowPassiveHealing;
  final double damageMeterWidth;

  // ── Summary screen ─────────────────────────────────────────────────────────
  final String summaryDefaultTab;
  final bool summaryShowHealingColumn;
  final String summaryDefaultSortColumn;

  // ── Phase line overlay ─────────────────────────────────────────────────────
  final bool phaseLineShowBallPosition;

  const UiTheme._({
    this.homeTeamColor               = const Color(0xFF1E88E5),
    this.awayTeamColor               = const Color(0xFFE53935),
    this.accentColor                 = const Color(0xFFFFCC00),
    this.scoreUltraColor             = const Color(0xFFFFCC00),
    this.scoreMetaColor              = const Color(0xFF44BBFF),
    this.scoreKillaColor             = const Color(0xFFFF7744),
    this.backgroundColor             = const Color(0xFF0D0D1A),
    this.surfaceColor                = const Color(0xFF08080F),
    this.borderSubtleColor           = const Color(0xFF222244),
    this.borderAccentColor           = const Color(0xFF334466),
    this.classSpectreColor           = const Color(0xFF44FFCC),
    this.classCorsairColor           = const Color(0xFFFF44AA),
    this.classGeomancerColor         = const Color(0xFFFF5544),
    this.classArchonColor            = const Color(0xFF4488FF),
    this.classWardenColor            = const Color(0xFFFFCC44),
    this.classTricksterColor         = const Color(0xFFAA44FF),
    this.classWreckerColor           = const Color(0xFFFF7700),
    this.phaseActiveColor            = const Color(0xFF00FFFF),
    this.phaseInactiveColor          = const Color(0xFF333333),
    this.aliveColor                  = const Color(0xFF44FF88),
    this.deadColor                   = const Color(0xFFFF4444),
    this.scoreboardScoreSize         = 36.0,
    this.scoreboardTimerSize         = 24.0,
    this.scoreboardTeamNameSize      = 11.0,
    this.scoreboardSubInfoSize       = 9.0,
    this.scoreboardShowAliveCount    = true,
    this.scoreboardShowScoreBreakdown = true,
    this.scoreboardShowActHistory    = true,
    this.scoreboardBackgroundOpacity = 0.9,
    this.scoreboardBorderOpacity     = 0.15,
    this.damageMeterDefaultVisible   = false,
    this.damageMeterDefaultTab       = 'damage',
    this.damageMeterShowPassiveHealing = false,
    this.damageMeterWidth            = 220.0,
    this.summaryDefaultTab           = 'scoreboard',
    this.summaryShowHealingColumn    = true,
    this.summaryDefaultSortColumn    = 'damage',
    this.phaseLineShowBallPosition   = true,
  });

  // ── Convenience helpers ────────────────────────────────────────────────────

  Color get homeTeamDim => homeTeamColor.withValues(alpha: 0.6);
  Color get awayTeamDim => awayTeamColor.withValues(alpha: 0.6);

  static bool _loaded = false;

  /// Load theme.json from assets, falling back to defaults on any error.
  static Future<void> loadFromAsset() async {
    assert(!_loaded, 'UiTheme.loadFromAsset() called more than once');
    _loaded = true;
    try {
      final raw  = await rootBundle.loadString('assets/ui/theme.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _instance  = UiTheme._fromJson(json);
    } catch (_) {
      // Defaults already set; silent fallback keeps the game running.
    }
  }

  // ── JSON deserialisation ───────────────────────────────────────────────────

  factory UiTheme._fromJson(Map<String, dynamic> j) {
    final c  = (j['colors']      as Map?)?.cast<String, dynamic>() ?? {};
    final sb = (j['scoreboard']  as Map?)?.cast<String, dynamic>() ?? {};
    final dm = (j['damageMeter'] as Map?)?.cast<String, dynamic>() ?? {};
    final sm = (j['summary']     as Map?)?.cast<String, dynamic>() ?? {};
    final pl = (j['phaseLine']   as Map?)?.cast<String, dynamic>() ?? {};

    return UiTheme._(
      homeTeamColor:               _hex(c['homeTeam'],       0xFF1E88E5),
      awayTeamColor:               _hex(c['awayTeam'],       0xFFE53935),
      accentColor:                 _hex(c['accent'],         0xFFFFCC00),
      scoreUltraColor:             _hex(c['scoreUltra'],     0xFFFFCC00),
      scoreMetaColor:              _hex(c['scoreMeta'],      0xFF44BBFF),
      scoreKillaColor:             _hex(c['scoreKilla'],     0xFFFF7744),
      backgroundColor:             _hex(c['background'],     0xFF0D0D1A),
      surfaceColor:                _hex(c['surface'],        0xFF08080F),
      borderSubtleColor:           _hex(c['borderSubtle'],   0xFF222244),
      borderAccentColor:           _hex(c['borderAccent'],   0xFF334466),
      classSpectreColor:           _hex(c['classSpectre'],   0xFF44FFCC),
      classCorsairColor:           _hex(c['classCorsair'],   0xFFFF44AA),
      classGeomancerColor:         _hex(c['classGeomancer'], 0xFFFF5544),
      classArchonColor:            _hex(c['classArchon'],    0xFF4488FF),
      classWardenColor:            _hex(c['classWarden'],    0xFFFFCC44),
      classTricksterColor:         _hex(c['classTrickster'], 0xFFAA44FF),
      classWreckerColor:           _hex(c['classWrecker'],  0xFFFF7700),
      phaseActiveColor:            _hex(c['phaseActive'],    0xFF00FFFF),
      phaseInactiveColor:          _hex(c['phaseInactive'],  0xFF333333),
      aliveColor:                  _hex(c['alive'],          0xFF44FF88),
      deadColor:                   _hex(c['dead'],           0xFFFF4444),
      scoreboardScoreSize:         math.max(4.0, _d(sb['scoreSize'],     36.0)),
      scoreboardTimerSize:         math.max(4.0, _d(sb['timerSize'],     24.0)),
      scoreboardTeamNameSize:      math.max(4.0, _d(sb['teamNameSize'],  11.0)),
      scoreboardSubInfoSize:       math.max(4.0, _d(sb['subInfoSize'],    9.0)),
      scoreboardShowAliveCount:    _b(sb['showAliveCount'],     true),
      scoreboardShowScoreBreakdown: _b(sb['showScoreBreakdown'], true),
      scoreboardShowActHistory:    _b(sb['showActHistory'],     true),
      scoreboardBackgroundOpacity: _opacity(sb['backgroundOpacity'], 0.9),
      scoreboardBorderOpacity:     _opacity(sb['borderOpacity'],     0.15),
      damageMeterDefaultVisible:   _b(dm['defaultVisible'],     false),
      damageMeterDefaultTab:       _s(dm['defaultTab'],         'damage'),
      damageMeterShowPassiveHealing: _b(dm['showPassiveHealing'], false),
      damageMeterWidth:            _d(dm['width'],              220.0),
      summaryDefaultTab:           _s(sm['defaultTab'],         'scoreboard'),
      summaryShowHealingColumn:    _b(sm['showHealingColumn'],  true),
      summaryDefaultSortColumn:    _s(sm['defaultSortColumn'],  'damage'),
      phaseLineShowBallPosition:   _b(pl['showBallPosition'],   true),
    );
  }

  // ── Parse helpers ──────────────────────────────────────────────────────────

  static Color _hex(dynamic v, int fallback) {
    if (v is! String) return Color(fallback);
    try {
      final s = v.replaceAll('#', '');
      if (s.length != 6 && s.length != 8) return Color(fallback);
      return Color(int.parse(s.length == 6 ? 'FF$s' : s, radix: 16));
    } catch (_) {
      return Color(fallback);
    }
  }

  static double _d(dynamic v, double fallback) =>
      v is num ? v.toDouble() : fallback;

  static double _opacity(dynamic v, double fallback) =>
      _d(v, fallback).clamp(0.0, 1.0);

  static bool _b(dynamic v, bool fallback) =>
      v is bool ? v : fallback;

  static String _s(dynamic v, String fallback) =>
      v is String ? v : fallback;
}
