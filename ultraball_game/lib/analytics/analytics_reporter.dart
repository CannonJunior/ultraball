// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import '../game/game_state.dart';

const _kReportUrl = 'http://localhost:8777/report';

class AnalyticsReporter {
  /// Fire-and-forget: serialises the completed game and POSTs to the analytics API.
  static void send(GameState gs) {
    final stats = gs.abilityStats;
    if (stats == null || stats.totalUses == 0) return;

    final act = gs.actState;
    final s   = gs.settings;

    final String winner;
    if (act.playerForfeit) {
      winner = 'away';
    } else if (act.opponentForfeit) {
      winner = 'home';
    } else if (act.playerScore > act.opponentScore) {
      winner = 'home';
    } else if (act.opponentScore > act.playerScore) {
      winner = 'away';
    } else {
      winner = 'draw';
    }

    final payload = jsonEncode({
      'home_team':      s.homeTeamName,
      'away_team':      s.awayTeamName,
      'home_score':     act.playerScore,
      'away_score':     act.opponentScore,
      'winner':         winner,
      'forfeit':        act.playerForfeit || act.opponentForfeit,
      'acts_played':    act.currentAct,
      'ai_strategy':    s.aiStrategy.name,
      'ai_tactics':     s.aiTactics.name,
      'ability_uses':   stats.log.map((r) => r.toJson()).toList(),
    });

    html.HttpRequest.request(
      _kReportUrl,
      method: 'POST',
      requestHeaders: {'Content-Type': 'application/json'},
      sendData: payload,
    );
  }
}
