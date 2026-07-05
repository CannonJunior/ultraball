part of 'mesh.dart';

double _meshSqrt(double x) {
  if (x <= 0) return 0;
  double guess = x / 2;
  for (int i = 0; i < 10; i++) {
    guess = (guess + x / guess) / 2;
  }
  return guess;
}

/// Dashed-rectangle target indicator lying flat on the ground plane.
/// Each side has a dash-gap-dash pattern (2 dashes per side, gap in the middle).
Mesh _buildMeshTargetIndicator({
  required double size,
  required double lineWidth,
  required Vector3 color,
}) {
  final halfSize  = size / 2;
  final dashLength = size / 5;
  final halfLine  = lineWidth / 2;
  const y = 0.02;

  final allVertices = <double>[];
  final allIndices  = <int>[];
  final allNormals  = <double>[];
  final allColors   = <double>[];
  int vertexOffset  = 0;

  void addDash(double x1, double z1, double x2, double z2) {
    final dx  = x2 - x1;
    final dz  = z2 - z1;
    final len = _meshSqrt(dx * dx + dz * dz);
    if (len < 0.001) return;
    final perpX = -dz / len * halfLine;
    final perpZ =  dx / len * halfLine;

    allVertices.addAll([
      x1 + perpX, y, z1 + perpZ,
      x1 - perpX, y, z1 - perpZ,
      x2 - perpX, y, z2 - perpZ,
      x2 + perpX, y, z2 + perpZ,
      x1 + perpX, y, z1 + perpZ,
      x1 - perpX, y, z1 - perpZ,
      x2 - perpX, y, z2 - perpZ,
      x2 + perpX, y, z2 + perpZ,
    ]);
    allIndices.addAll([
      vertexOffset + 0, vertexOffset + 1, vertexOffset + 2,
      vertexOffset + 0, vertexOffset + 2, vertexOffset + 3,
      vertexOffset + 4, vertexOffset + 6, vertexOffset + 5,
      vertexOffset + 4, vertexOffset + 7, vertexOffset + 6,
    ]);
    for (int i = 0; i < 4; i++) {
      allNormals.addAll([0, 1, 0]);
      allColors.addAll([color.x, color.y, color.z, 1.0]);
    }
    for (int i = 0; i < 4; i++) {
      allNormals.addAll([0, -1, 0]);
      allColors.addAll([color.x, color.y, color.z, 1.0]);
    }
    vertexOffset += 8;
  }

  // Front / back sides (along X axis at ±halfSize Z)
  addDash(-halfSize, halfSize, -halfSize + dashLength, halfSize);
  addDash( halfSize - dashLength, halfSize,  halfSize, halfSize);
  addDash(-halfSize, -halfSize, -halfSize + dashLength, -halfSize);
  addDash( halfSize - dashLength, -halfSize,  halfSize, -halfSize);

  // Left / right sides (along Z axis at ±halfSize X)
  addDash(-halfSize, -halfSize, -halfSize, -halfSize + dashLength);
  addDash(-halfSize,  halfSize - dashLength, -halfSize,  halfSize);
  addDash( halfSize, -halfSize,  halfSize, -halfSize + dashLength);
  addDash( halfSize,  halfSize - dashLength,  halfSize,  halfSize);

  return Mesh(
    vertices: Float32List.fromList(allVertices),
    indices:  Uint16List.fromList(allIndices),
    normals:  Float32List.fromList(allNormals),
    colors:   Float32List.fromList(allColors),
  );
}

Mesh _buildMeshBox({
  required double width,
  required double height,
  required double depth,
  Vector3? color,
}) {
  final hw = width / 2;
  final hh = height / 2;
  final hd = depth / 2;

  final verts = Float32List.fromList([
    // Front (+Z)
    -hw, -hh,  hd,   hw, -hh,  hd,   hw,  hh,  hd,  -hw,  hh,  hd,
    // Back (-Z)
     hw, -hh, -hd,  -hw, -hh, -hd,  -hw,  hh, -hd,   hw,  hh, -hd,
    // Top (+Y)
    -hw,  hh,  hd,   hw,  hh,  hd,   hw,  hh, -hd,  -hw,  hh, -hd,
    // Bottom (-Y)
    -hw, -hh, -hd,   hw, -hh, -hd,   hw, -hh,  hd,  -hw, -hh,  hd,
    // Right (+X)
     hw, -hh,  hd,   hw, -hh, -hd,   hw,  hh, -hd,   hw,  hh,  hd,
    // Left (-X)
    -hw, -hh, -hd,  -hw, -hh,  hd,  -hw,  hh,  hd,  -hw,  hh, -hd,
  ]);

  final normals = Float32List.fromList([
    0, 0, 1,  0, 0, 1,  0, 0, 1,  0, 0, 1,
    0, 0, -1,  0, 0, -1,  0, 0, -1,  0, 0, -1,
    0, 1, 0,  0, 1, 0,  0, 1, 0,  0, 1, 0,
    0, -1, 0,  0, -1, 0,  0, -1, 0,  0, -1, 0,
    1, 0, 0,  1, 0, 0,  1, 0, 0,  1, 0, 0,
    -1, 0, 0,  -1, 0, 0,  -1, 0, 0,  -1, 0, 0,
  ]);

  final indices = Uint16List.fromList([
    for (int face = 0; face < 6; face++) ...[
      face * 4,     face * 4 + 1, face * 4 + 2,
      face * 4,     face * 4 + 2, face * 4 + 3,
    ]
  ]);

  Float32List? colors;
  if (color != null) {
    colors = Float32List(24 * 4);
    for (int i = 0; i < 24; i++) {
      colors[i * 4]     = color.x;
      colors[i * 4 + 1] = color.y;
      colors[i * 4 + 2] = color.z;
      colors[i * 4 + 3] = 1.0;
    }
  }

  return Mesh(vertices: verts, indices: indices, normals: normals, colors: colors);
}
