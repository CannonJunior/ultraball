import 'dart:convert';
import 'dart:math' as math;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'ai_strategy.dart';
import 'ai_policy.dart';
import 'game_record.dart';
import 'reward_system.dart';

/// Manages a learned [AiPolicy] for every strategy+tactics combination.
///
/// Algorithm: reward-guided hill-climbing with ε-greedy exploration.
///   1. Before each game: if rng < explorationRate, perturb the policy slightly.
///   2. After each game: compute reward → update exponential moving average →
///      if this episode beat the mean, nudge the stored policy toward the
///      weights that were actually used.
///   3. Policies are persisted to browser localStorage so learning carries
///      across sessions.
class LearningAi {
  static const _storageKey = 'ultraball_ai_policies';

  /// App-wide singleton — persists across game sessions.
  static final LearningAi instance = LearningAi._();
  LearningAi._() { _load(); }

  final math.Random _rng = math.Random();

  // Canonical policy store: one entry per (strategy, tactics) key
  final Map<String, AiPolicy> _policies = {};

  // Policy that was actually used last game (may be perturbed copy)
  AiPolicy? _usedPolicy;
  String?   _usedKey;

  // ---- Public API ----

  /// Returns the policy to use for this game (possibly with exploration noise).
  /// Call this once per game BEFORE the match starts.
  AiPolicy policyFor(AiStrategy strategy, AiTactics tactics) {
    final key = _key(strategy, tactics);
    final base = _policies.putIfAbsent(
      key,
      () => AiPolicy.defaultFor(strategy, tactics),
    );

    AiPolicy used;
    if (_rng.nextDouble() < base.explorationRate) {
      used = base.withExploration(_rng);
    } else {
      used = base;
    }
    _usedPolicy = used;
    _usedKey    = key;
    return used;
  }

  /// Call at game end with the completed [GameRecord] to update the policy.
  void onGameEnd(GameRecord record) {
    final stats = record.stats;
    if (stats == null || _usedPolicy == null || _usedKey == null) return;

    final reward = RewardSystem.compute(stats, record.strategy, record.tactics);
    final key    = _usedKey!;
    final base   = _policies[key] ?? AiPolicy.defaultFor(record.strategy, record.tactics);
    base.update(reward, _usedPolicy!, _rng);
    _policies[key] = base;

    _usedPolicy = null;
    _usedKey    = null;
    _save();
  }

  /// Current policy for display on the settings screen.
  AiPolicy? currentPolicy(AiStrategy strategy, AiTactics tactics) =>
      _policies[_key(strategy, tactics)];

  /// Reset a specific strategy+tactics policy back to defaults.
  void resetFor(AiStrategy strategy, AiTactics tactics) {
    _policies[_key(strategy, tactics)] =
        AiPolicy.defaultFor(strategy, tactics);
    _save();
  }

  /// Reset ALL learned policies.
  void resetAll() {
    _policies.clear();
    try {
      // ignore: avoid_web_libraries_in_flutter
      html.window.localStorage.remove(_storageKey);
    } catch (_) {}
  }

  /// Human-readable summary of all learned policies (for debugging).
  String summary() {
    final buf = StringBuffer();
    for (final entry in _policies.entries) {
      final p = entry.value;
      buf.writeln('${entry.key}  episodes=${p.episodeCount}  '
          'meanR=${p.meanReward.toStringAsFixed(1)}  '
          'aggr=${p.aggression.toStringAsFixed(2)}  '
          'coh=${p.cohesion.toStringAsFixed(2)}  '
          'herd=${p.creatureHerding.toStringAsFixed(2)}  '
          'pass=${p.passEagerness.toStringAsFixed(2)}  '
          'zone=${p.endzonePressure.toStringAsFixed(2)}');
    }
    return buf.toString();
  }

  /// Export learned policies as a JSON download.
  void downloadPolicies() {
    try {
      final data = jsonEncode(_toJsonMap());
      final blob = html.Blob([data], 'application/json');
      final url  = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'ultraball_ai_policies.json')
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (_) {}
  }

  // ---- Persistence ----

  void _save() {
    try {
      html.window.localStorage[_storageKey] = jsonEncode(_toJsonMap());
    } catch (_) {}
  }

  void _load() {
    try {
      final raw = html.window.localStorage[_storageKey];
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in map.entries) {
        _policies[entry.key] =
            AiPolicy.fromJson(entry.value as Map<String, dynamic>);
      }
    } catch (_) {
      // Corrupt or missing — start fresh
      _policies.clear();
    }
  }

  Map<String, dynamic> _toJsonMap() =>
      _policies.map((k, v) => MapEntry(k, v.toJson()));

  static String _key(AiStrategy s, AiTactics t) => '${s.name}_${t.name}';
}
