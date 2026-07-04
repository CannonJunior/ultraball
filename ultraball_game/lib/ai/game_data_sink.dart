abstract class GameDataSink {
  void tick(double dt);
  void onUltra(String teamId);
  void onMeta(String teamId);
  void onKilla(String killingTeamId);
  void onCreatureKill(String victimTeamId);
  void onPass(String teamId);
  void onTackle(String teamId);
  void onSlam(String teamId);
  void onExplosion(String holderTeamId);
  void onActEnd(int actNumber);
}
