const int kTerrainCols = 28;
const int kTerrainRows = 8;
const double kCellW = 5.0;
const double kCellH = 5.0;

enum SurfaceType { normal, ice, mud, lava, spikes, electric, poison, void_, heatVent, acid }
enum HazardType  { none, fire, ice, electric, poison, physical, corrosive, wind }

class TerrainCell {
  double  height       = 0.0;
  double  targetHeight = 0.0;
  double  lerpSpeed    = 2.0;
  SurfaceType surface  = SurfaceType.normal;
  HazardType  hazard   = HazardType.none;
  double  hazardTimer  = 0.0;
  double  hazardDps    = 0.0;
  double  speedMult    = 1.0;
  bool    isPit        = false;

  void reset() {
    targetHeight = 0.0;
    lerpSpeed    = 2.0;
    surface      = SurfaceType.normal;
    hazard       = HazardType.none;
    hazardTimer  = 0.0;
    hazardDps    = 0.0;
    speedMult    = 1.0;
    isPit        = false;
  }
}

class TerrainGrid {
  final List<List<TerrainCell>> cells; // [col][row]

  TerrainGrid()
      : cells = List.generate(kTerrainCols,
            (_) => List.generate(kTerrainRows, (_) => TerrainCell()));

  TerrainCell cellAt(double worldX, double worldY) {
    final col = (worldX / kCellW).floor().clamp(0, kTerrainCols - 1);
    final row = (worldY / kCellH).floor().clamp(0, kTerrainRows - 1);
    return cells[col][row];
  }

  List<TerrainCell> cellsInRadius(double cx, double cy, double radius) {
    final result = <TerrainCell>[];
    final colMin = ((cx - radius) / kCellW).floor().clamp(0, kTerrainCols - 1);
    final colMax = ((cx + radius) / kCellW).floor().clamp(0, kTerrainCols - 1);
    final rowMin = ((cy - radius) / kCellH).floor().clamp(0, kTerrainRows - 1);
    final rowMax = ((cy + radius) / kCellH).floor().clamp(0, kTerrainRows - 1);

    for (int c = colMin; c <= colMax; c++) {
      for (int r = rowMin; r <= rowMax; r++) {
        final cellCx = (c + 0.5) * kCellW;
        final cellCy = (r + 0.5) * kCellH;
        final dx = cellCx - cx;
        final dy = cellCy - cy;
        if (dx * dx + dy * dy <= radius * radius) {
          result.add(cells[c][r]);
        }
      }
    }
    return result;
  }

  void forEach(void Function(int col, int row, TerrainCell cell) callback) {
    for (int c = 0; c < kTerrainCols; c++) {
      for (int r = 0; r < kTerrainRows; r++) {
        callback(c, r, cells[c][r]);
      }
    }
  }
}
