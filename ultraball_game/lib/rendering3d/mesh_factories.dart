part of 'mesh.dart';

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
