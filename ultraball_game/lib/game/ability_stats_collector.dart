import '../models/player.dart';
import '../models/player_class.dart';
import 'game_state.dart';

/// Records every ability use during a game and computes statistics that
/// correlate ability choices with player and team success.
///
/// Usage:
///   gs.abilityStats = AbilityStatsCollector();
///
/// Read results:
///   gs.abilityStats!.printReport();
class AbilityStatsCollector {
  final List<AbilityUseRecord> _log = [];

  // Game-outcome events keyed by game-time for temporal correlation.
  final List<_OutcomeEvent> _outcomes = [];

  // ── Snapshot helpers (called from CombatSystem) ──────────────────────────

  static _GameSnapshot snap(GameState gs, Team forTeam) {
    final enemies = gs.getTeamOnField(
      forTeam == Team.player ? Team.opponent : Team.player,
    );
    double hpSum = 0;
    int ccCount = 0;
    for (final e in enemies) {
      hpSum += e.health;
      if (e.stunTimer > 0 || e.snareTimer > 0 ||
          e.confusedTimer > 0 || e.hexedTimer > 0) ccCount++;
    }
    final holderId = gs.ball.holderId;
    final holderTeam = holderId != null
        ? gs.getPlayerById(holderId)?.team
        : null;
    return _GameSnapshot(
      enemyHpSum: hpSum,
      enemyCCCount: ccCount,
      opponentHasBall: holderTeam != null && holderTeam != forTeam,
    );
  }

  // ── Recording API (called from CombatSystem.useClassAbility) ─────────────

  void recordUse({
    required UltraballPlayer player,
    required int slot,
    required _GameSnapshot before,
    required _GameSnapshot after,
    required double gameTimeRemaining,
  }) {
    final damageDealt = (before.enemyHpSum - after.enemyHpSum).clamp(0, double.infinity);
    final causedFumble = before.opponentHasBall && !after.opponentHasBall;
    final appliedCC = after.enemyCCCount > before.enemyCCCount;

    _log.add(AbilityUseRecord(
      playerId: player.id,
      playerName: player.name,
      playerClass: player.playerClass,
      team: player.team,
      slot: slot,
      abilityName: player.playerClass.abilityNames[slot - 1],
      damageDealt: damageDealt.toDouble(),
      causedFumble: causedFumble,
      appliedCC: appliedCC,
      hitATarget: damageDealt > 0 || causedFumble || appliedCC,
      teamHadBall: !before.opponentHasBall,
      playerHpRatio: player.health / player.maxHealth,
      gameTimeRemaining: gameTimeRemaining,
    ));
  }

  // ── Game-outcome hooks (wire into ActSystem / BallSystem) ─────────────────

  /// Call when a goal is scored.
  void recordGoal(Team scoringTeam, double gameTimeRemaining) {
    _outcomes.add(_OutcomeEvent(
      type: _OutcomeType.goal,
      team: scoringTeam,
      gameTimeRemaining: gameTimeRemaining,
    ));
  }

  /// Call when a player is killed.
  void recordKill(Team killerTeam, double gameTimeRemaining) {
    _outcomes.add(_OutcomeEvent(
      type: _OutcomeType.kill,
      team: killerTeam,
      gameTimeRemaining: gameTimeRemaining,
    ));
  }

  // ── Statistics ────────────────────────────────────────────────────────────

  /// Returns aggregate stats keyed by "<ClassName>/<abilityName>".
  Map<String, PerAbilityStats> get statsPerAbility {
    final map = <String, PerAbilityStats>{};
    for (final r in _log) {
      final key = '${r.playerClass.displayName}/${r.abilityName}';
      final s = map.putIfAbsent(key, () => PerAbilityStats(
        key: key,
        abilityName: r.abilityName,
        playerClass: r.playerClass,
        slot: r.slot,
      ));
      s.uses++;
      if (r.hitATarget)    s.hits++;
      s.totalDamage       += r.damageDealt;
      if (r.causedFumble)  s.fumbles++;
      if (r.appliedCC)     s.ccApplications++;
    }
    return map;
  }

  /// Returns ability keys ordered by impact score (descending).
  List<MapEntry<String, PerAbilityStats>> get rankedByImpact {
    final entries = statsPerAbility.entries.toList();
    entries.sort((a, b) => b.value.impactScore.compareTo(a.value.impactScore));
    return entries;
  }

  /// Correlation of each ability with a kill occurring within [windowSeconds]
  /// after the ability was used. Returns a 0–1 rate.
  Map<String, double> killCorrelation({double windowSeconds = 10.0}) {
    final result = <String, double>{};
    final killTimes = _outcomes
        .where((e) => e.type == _OutcomeType.kill)
        .map((e) => e.gameTimeRemaining)
        .toList();

    for (final r in _log) {
      final key = '${r.playerClass.displayName}/${r.abilityName}';
      result.putIfAbsent(key, () => 0);
    }

    final useCounts = <String, int>{};
    final hitCounts = <String, int>{};

    for (final r in _log) {
      final key = '${r.playerClass.displayName}/${r.abilityName}';
      useCounts[key] = (useCounts[key] ?? 0) + 1;
      // Did a kill happen within windowSeconds after this use (time counts down)?
      final windowEnd = r.gameTimeRemaining - windowSeconds;
      final nearKill = killTimes.any((t) =>
          t <= r.gameTimeRemaining && t >= windowEnd && t >= 0);
      if (nearKill) hitCounts[key] = (hitCounts[key] ?? 0) + 1;
    }

    for (final key in useCounts.keys) {
      final u = useCounts[key]!;
      result[key] = u > 0 ? (hitCounts[key] ?? 0) / u : 0;
    }
    return result;
  }

  // ── Report output ─────────────────────────────────────────────────────────

  void printReport() {
    if (_log.isEmpty) {
      print('[AbilityStats] No data collected yet.');
      return;
    }

    final ranked = rankedByImpact;
    final killCorr = killCorrelation();

    print('');
    print('═══════════════════════════════════════════════════════════════');
    print('  ULTRABALL ABILITY STATS  (${_log.length} uses recorded)');
    print('═══════════════════════════════════════════════════════════════');
    print(_fmtHeader());
    print('─' * 79);

    for (final e in ranked) {
      final s = e.value;
      if (s.uses < 2) continue; // skip single-use noise
      final corr = killCorr[e.key] ?? 0;
      print(_fmtRow(s, corr));
    }

    print('─' * 79);
    print('  Impact = avgDmg + fumbleRate×40 + ccRate×15');
    print('  KillCorr = % of uses followed by a kill within 10s');
    print('═══════════════════════════════════════════════════════════════');
    print('');
  }

  static String _fmtHeader() =>
      '  %-28s %5s %5s %6s %5s %5s %6s'
      .replaceAllMapped(RegExp(r'%-(\d+)s'), (m) => ''.padRight(int.parse(m[1]!)))
      .replaceFirst('', 'Ability'.padRight(28))
      .replaceFirst('', 'Uses'.padLeft(5))
      .replaceFirst('', 'Hit%'.padLeft(5))
      .replaceFirst('', 'AvgDmg'.padLeft(6))
      .replaceFirst('', 'Fmbl%'.padLeft(5))
      .replaceFirst('', 'CC%'.padLeft(5))
      .replaceFirst('', 'Impact'.padLeft(6));

  static String _fmtRow(PerAbilityStats s, double killCorr) {
    final label = '${s.playerClass.displayName}/${s.abilityName}';
    return '  ${label.padRight(28)}'
        '${s.uses.toString().padLeft(5)}'
        '${(s.hitRate * 100).toStringAsFixed(0).padLeft(4)}%'
        '${s.avgDamage.toStringAsFixed(1).padLeft(6)}'
        '${(s.fumbleRate * 100).toStringAsFixed(0).padLeft(4)}%'
        '${(s.ccRate * 100).toStringAsFixed(0).padLeft(4)}%'
        '${s.impactScore.toStringAsFixed(1).padLeft(6)}'
        '  kc:${(killCorr * 100).toStringAsFixed(0)}%';
  }

  int get totalUses => _log.length;
  List<AbilityUseRecord> get log => List.unmodifiable(_log);
  void reset() { _log.clear(); _outcomes.clear(); }
}

// ── Data classes ─────────────────────────────────────────────────────────────

class AbilityUseRecord {
  final String playerId;
  final String playerName;
  final PlayerClass playerClass;
  final Team team;
  final int slot;
  final String abilityName;
  final double damageDealt;
  final bool causedFumble;
  final bool appliedCC;
  final bool hitATarget;
  final bool teamHadBall;
  final double playerHpRatio;
  final double gameTimeRemaining;

  const AbilityUseRecord({
    required this.playerId,
    required this.playerName,
    required this.playerClass,
    required this.team,
    required this.slot,
    required this.abilityName,
    required this.damageDealt,
    required this.causedFumble,
    required this.appliedCC,
    required this.hitATarget,
    required this.teamHadBall,
    required this.playerHpRatio,
    required this.gameTimeRemaining,
  });

  Map<String, dynamic> toJson() => {
    'player_id':          playerId,
    'player_name':        playerName,
    'player_class':       playerClass.displayName,
    'team':               team.name,
    'slot':               slot,
    'ability_name':       abilityName,
    'damage_dealt':       damageDealt,
    'caused_fumble':      causedFumble,
    'applied_cc':         appliedCC,
    'hit_a_target':       hitATarget,
    'team_had_ball':      teamHadBall,
    'player_hp_ratio':    playerHpRatio,
    'game_time_remaining': gameTimeRemaining,
  };
}

class PerAbilityStats {
  final String key;
  final String abilityName;
  final PlayerClass playerClass;
  final int slot;

  int uses = 0;
  int hits = 0;
  double totalDamage = 0;
  int fumbles = 0;
  int ccApplications = 0;

  PerAbilityStats({
    required this.key,
    required this.abilityName,
    required this.playerClass,
    required this.slot,
  });

  double get hitRate      => uses > 0 ? hits / uses : 0;
  double get avgDamage    => uses > 0 ? totalDamage / uses : 0;
  double get fumbleRate   => uses > 0 ? fumbles / uses : 0;
  double get ccRate       => uses > 0 ? ccApplications / uses : 0;

  /// Composite impact: damage contribution + turnover value + CC value.
  double get impactScore => avgDamage + fumbleRate * 40 + ccRate * 15;
}

class _GameSnapshot {
  final double enemyHpSum;
  final int enemyCCCount;
  final bool opponentHasBall;
  const _GameSnapshot({
    required this.enemyHpSum,
    required this.enemyCCCount,
    required this.opponentHasBall,
  });
}

enum _OutcomeType { goal, kill }

class _OutcomeEvent {
  final _OutcomeType type;
  final Team team;
  final double gameTimeRemaining;
  const _OutcomeEvent({
    required this.type,
    required this.team,
    required this.gameTimeRemaining,
  });
}
