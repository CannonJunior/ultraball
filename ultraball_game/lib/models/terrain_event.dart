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

  const TerrainEvent({
    required this.type,
    required this.worldX,
    required this.worldY,
    this.radius = 5.0,
    this.intensity = 1.0,
    this.duration = 6.0,
    this.directionRad,
  });
}
