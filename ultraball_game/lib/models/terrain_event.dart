enum TerrainEventType {
  // Geometry changes
  riseMountain,
  sinkValley,
  flatten,
  openPit,
  closePit,
  fissure,

  // Surface hazards
  lavaPool,
  icePatch,
  mudZone,
  spikeField,
  electricZone,
  poisonCloud,
  acidPool,

  // Force / movement events
  shockwave,
  heatVent,
  windTunnel,

  // Reset
  normalize,
}

class TerrainEvent {
  final TerrainEventType type;
  final double worldX;
  final double worldY;
  final double radius;
  final double intensity;
  final double duration;
  final double? directionRad;
  /// For riseMountain / sinkValley: fraction of radius that is flat plateau.
  /// 0.0 = pure spike, 1.0 = fully flat. Default 0.28.
  final double plateauFrac;

  const TerrainEvent({
    required this.type,
    required this.worldX,
    required this.worldY,
    this.radius = 5.0,
    this.intensity = 1.0,
    this.duration = 6.0,
    this.directionRad,
    this.plateauFrac = 0.28,
  });
}
