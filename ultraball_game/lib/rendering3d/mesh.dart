import 'package:vector_math/vector_math.dart';
import 'dart:typed_data';

part 'mesh_factories.dart';

class Mesh {
  final Float32List vertices;
  final Uint16List indices;
  final Float32List? normals;
  final Float32List? texCoords;
  final Float32List? colors;

  Mesh({
    required this.vertices,
    required this.indices,
    this.normals,
    this.texCoords,
    this.colors,
  }) {
    assert(vertices.length % 3 == 0, 'Vertices must be multiple of 3 (x, y, z)');
    assert(indices.length % 3 == 0, 'Indices must be multiple of 3 (triangles)');

    if (normals != null) {
      assert(normals!.length == vertices.length, 'Normals count must match vertices');
    }
    if (texCoords != null) {
      assert(texCoords!.length == (vertices.length / 3) * 2, 'TexCoords must be 2 per vertex');
    }
    if (colors != null) {
      assert(colors!.length == (vertices.length / 3) * 4, 'Colors must be 4 per vertex (RGBA)');
    }
  }

  int get vertexCount => vertices.length ~/ 3;
  int get triangleCount => indices.length ~/ 3;

  factory Mesh.fromVerticesAndIndices({
    required List<double> vertices,
    required List<int> indices,
    int vertexStride = 6,
  }) {
    final numVertices = vertices.length ~/ vertexStride;

    final positions = Float32List(numVertices * 3);
    for (int i = 0; i < numVertices; i++) {
      positions[i * 3 + 0] = vertices[i * vertexStride + 0];
      positions[i * 3 + 1] = vertices[i * vertexStride + 1];
      positions[i * 3 + 2] = vertices[i * vertexStride + 2];
    }

    final colors = Float32List(numVertices * 4);
    for (int i = 0; i < numVertices; i++) {
      colors[i * 4 + 0] = vertices[i * vertexStride + 3];
      colors[i * 4 + 1] = vertices[i * vertexStride + 4];
      colors[i * 4 + 2] = vertices[i * vertexStride + 5];
      colors[i * 4 + 3] = 1.0;
    }

    final indexList = Uint16List.fromList(indices.map((i) => i).toList());

    final normals = Float32List(numVertices * 3);
    for (int i = 0; i < numVertices; i++) {
      normals[i * 3 + 0] = 0.0;
      normals[i * 3 + 1] = 1.0;
      normals[i * 3 + 2] = 0.0;
    }

    return Mesh(
      vertices: positions,
      indices: indexList,
      normals: normals,
      colors: colors,
    );
  }

  factory Mesh.plane({
    double width = 1.0,
    double height = 1.0,
    Vector3? color,
  }) {
    final halfW = width / 2;
    final halfH = height / 2;

    final vertices = Float32List.fromList([
      -halfW, 0, -halfH,
       halfW, 0, -halfH,
       halfW, 0,  halfH,
      -halfW, 0,  halfH,
      -halfW, 0, -halfH,
       halfW, 0, -halfH,
       halfW, 0,  halfH,
      -halfW, 0,  halfH,
    ]);

    final indices = Uint16List.fromList([
      0, 1, 2,
      0, 2, 3,
      4, 6, 5,
      4, 7, 6,
    ]);

    final normals = Float32List.fromList([
      0, 1, 0,  0, 1, 0,  0, 1, 0,  0, 1, 0,
      0, -1, 0,  0, -1, 0,  0, -1, 0,  0, -1, 0,
    ]);

    final texCoords = Float32List.fromList([
      0, 0,  1, 0,  1, 1,  0, 1,
      0, 0,  1, 0,  1, 1,  0, 1,
    ]);

    Float32List? colors;
    if (color != null) {
      colors = Float32List.fromList([
        color.x, color.y, color.z, 1.0,
        color.x, color.y, color.z, 1.0,
        color.x, color.y, color.z, 1.0,
        color.x, color.y, color.z, 1.0,
        color.x, color.y, color.z, 1.0,
        color.x, color.y, color.z, 1.0,
        color.x, color.y, color.z, 1.0,
        color.x, color.y, color.z, 1.0,
      ]);
    }

    return Mesh(
      vertices: vertices,
      indices: indices,
      normals: normals,
      texCoords: texCoords,
      colors: colors,
    );
  }

  factory Mesh.cube({
    double size = 1.0,
    Vector3? color,
  }) {
    final s = size / 2;

    final vertices = Float32List.fromList([
      -s, -s,  s,
       s, -s,  s,
       s,  s,  s,
      -s,  s,  s,
      -s, -s, -s,
       s, -s, -s,
       s,  s, -s,
      -s,  s, -s,
    ]);

    final indices = Uint16List.fromList([
      0, 1, 2,  0, 2, 3,
      5, 4, 7,  5, 7, 6,
      3, 2, 6,  3, 6, 7,
      4, 5, 1,  4, 1, 0,
      1, 5, 6,  1, 6, 2,
      4, 0, 3,  4, 3, 7,
    ]);

    final normals = Float32List.fromList([
      0, 0, 1,  0, 0, 1,  0, 0, 1,  0, 0, 1,
      0, 0, -1,  0, 0, -1,  0, 0, -1,  0, 0, -1,
    ]);

    Float32List? colors;
    if (color != null) {
      colors = Float32List(8 * 4);
      for (int i = 0; i < 8; i++) {
        colors[i * 4 + 0] = color.x;
        colors[i * 4 + 1] = color.y;
        colors[i * 4 + 2] = color.z;
        colors[i * 4 + 3] = 1.0;
      }
    }

    return Mesh(
      vertices: vertices,
      indices: indices,
      normals: normals,
      colors: colors,
    );
  }

  static Float32List computeNormals(Float32List vertices, Uint16List indices) {
    final normals = Float32List(vertices.length);

    for (int i = 0; i < indices.length; i += 3) {
      final i0 = indices[i] * 3;
      final i1 = indices[i + 1] * 3;
      final i2 = indices[i + 2] * 3;

      final v0 = Vector3(vertices[i0], vertices[i0 + 1], vertices[i0 + 2]);
      final v1 = Vector3(vertices[i1], vertices[i1 + 1], vertices[i1 + 2]);
      final v2 = Vector3(vertices[i2], vertices[i2 + 1], vertices[i2 + 2]);

      final edge1 = v1 - v0;
      final edge2 = v2 - v0;
      final normal = edge1.cross(edge2).normalized();

      for (final idx in [i0, i1, i2]) {
        normals[idx] += normal.x;
        normals[idx + 1] += normal.y;
        normals[idx + 2] += normal.z;
      }
    }

    for (int i = 0; i < normals.length; i += 3) {
      final normal = Vector3(normals[i], normals[i + 1], normals[i + 2]).normalized();
      normals[i] = normal.x;
      normals[i + 1] = normal.y;
      normals[i + 2] = normal.z;
    }

    return normals;
  }

  Mesh withComputedNormals() {
    return Mesh(
      vertices: vertices,
      indices: indices,
      normals: computeNormals(vertices, indices),
      texCoords: texCoords,
      colors: colors,
    );
  }

  factory Mesh.triangle({
    double size = 1.0,
    Vector3? color,
  }) {
    final halfSize = size / 2;

    final vertices = Float32List.fromList([
      0, 0, halfSize,
      -halfSize, 0, -halfSize,
      halfSize, 0, -halfSize,
      0, 0, halfSize,
      -halfSize, 0, -halfSize,
      halfSize, 0, -halfSize,
    ]);

    final indices = Uint16List.fromList([
      0, 1, 2,
      3, 5, 4,
    ]);

    final normals = Float32List.fromList([
      0, 1, 0,  0, 1, 0,  0, 1, 0,
      0, -1, 0,  0, -1, 0,  0, -1, 0,
    ]);

    Float32List? colors;
    if (color != null) {
      colors = Float32List.fromList([
        color.x, color.y, color.z, 1.0,
        color.x, color.y, color.z, 1.0,
        color.x, color.y, color.z, 1.0,
        color.x, color.y, color.z, 1.0,
        color.x, color.y, color.z, 1.0,
        color.x, color.y, color.z, 1.0,
      ]);
    }

    return Mesh(
      vertices: vertices,
      indices: indices,
      normals: normals,
      colors: colors,
    );
  }

  factory Mesh.box({
    required double width,
    required double height,
    required double depth,
    Vector3? color,
  }) => _buildMeshBox(width: width, height: height, depth: depth, color: color);

  @override
  String toString() {
    return 'Mesh(vertices: $vertexCount, triangles: $triangleCount)';
  }
}
