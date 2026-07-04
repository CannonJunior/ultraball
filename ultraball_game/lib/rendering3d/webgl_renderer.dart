import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:html' as html;
import 'package:vector_math/vector_math.dart';
import 'perspective_camera.dart';
import 'mesh.dart';
import 'math/transform3d.dart';
import 'shader_program.dart';

class WebGLRenderer {
  final html.CanvasElement canvas;
  final dynamic gl;

  late ShaderProgram shader;
  late ShaderProgram unlitShader;

  Vector3 lightPosition = Vector3(70, 40, -30);
  Vector3 lightColor = Vector3(1.0, 1.0, 0.95);
  Vector3 ambientColor = Vector3(0.35, 0.35, 0.4);

  final Map<Mesh, _MeshBuffers> _meshBuffers = {};

  WebGLRenderer._(this.canvas, this.gl) {
    _initialize();
  }

  factory WebGLRenderer(html.CanvasElement canvas) {
    final gl = canvas.getContext3d(
      alpha: false,
      depth: true,
      antialias: true,
    );

    if (gl == null) {
      throw Exception('WebGL not supported');
    }

    return WebGLRenderer._(canvas, gl);
  }

  void _initialize() {
    gl.enable(0x0B71); // DEPTH_TEST
    gl.depthFunc(0x0201); // LESS
    gl.enable(0x0B44); // CULL_FACE
    gl.cullFace(0x0405); // BACK
    gl.clearColor(0.05, 0.05, 0.1, 1.0);

    shader = ShaderProgram.fromSource(gl, defaultVertexShader, defaultFragmentShader);
    unlitShader = ShaderProgram.fromSource(gl, unlitVertexShader, unlitFragmentShader);

    debugPrint('[UltraballWebGL] WebGLRenderer initialized');
  }

  void clear() {
    gl.clear(0x00004000 | 0x00000100); // COLOR_BUFFER_BIT | DEPTH_BUFFER_BIT
  }

  void render(Mesh mesh, Transform3d transform, PerspectiveCamera camera) {
    _renderWithShader(mesh, transform, camera, shader, lit: true);
  }

  void renderUnlit(Mesh mesh, Transform3d transform, PerspectiveCamera camera) {
    _renderWithShader(mesh, transform, camera, unlitShader, lit: false);
  }

  void _renderWithShader(
    Mesh mesh,
    Transform3d transform,
    PerspectiveCamera camera,
    ShaderProgram prog,
    {required bool lit}
  ) {
    final buffers = _getOrCreateBuffers(mesh);

    prog.use();

    prog.setUniformMatrix4('uProjection', camera.getProjectionMatrix());
    prog.setUniformMatrix4('uView', camera.getViewMatrix());
    prog.setUniformMatrix4('uModel', transform.toMatrix());

    if (lit) {
      prog.setUniformVector3('uLightPos', lightPosition);
      prog.setUniformVector3('uLightColor', lightColor);
      prog.setUniformVector3('uAmbientColor', ambientColor);
    }

    final positionLoc = prog.getAttribLocation('aPosition');
    if (positionLoc >= 0) {
      gl.bindBuffer(0x8892, buffers.vertexBuffer);
      gl.enableVertexAttribArray(positionLoc);
      gl.vertexAttribPointer(positionLoc, 3, 0x1406, false, 0, 0);
    }

    if (lit) {
      final normalLoc = prog.getAttribLocation('aNormal');
      if (normalLoc >= 0 && buffers.normalBuffer != null) {
        gl.bindBuffer(0x8892, buffers.normalBuffer);
        gl.enableVertexAttribArray(normalLoc);
        gl.vertexAttribPointer(normalLoc, 3, 0x1406, false, 0, 0);
      }
    }

    final colorLoc = prog.getAttribLocation('aColor');
    if (colorLoc >= 0) {
      if (buffers.colorBuffer != null) {
        gl.bindBuffer(0x8892, buffers.colorBuffer);
        gl.enableVertexAttribArray(colorLoc);
        gl.vertexAttribPointer(colorLoc, 4, 0x1406, false, 0, 0);
      } else {
        gl.disableVertexAttribArray(colorLoc);
        gl.vertexAttrib4f(colorLoc, 1.0, 1.0, 1.0, 1.0);
      }
    }

    gl.bindBuffer(0x8893, buffers.indexBuffer);
    gl.drawElements(0x0004, mesh.indices.length, 0x1403, 0);

    if (positionLoc >= 0) gl.disableVertexAttribArray(positionLoc);
    if (lit) {
      final normalLoc = prog.getAttribLocation('aNormal');
      if (normalLoc >= 0) gl.disableVertexAttribArray(normalLoc);
    }
    if (colorLoc >= 0) gl.disableVertexAttribArray(colorLoc);
  }

  _MeshBuffers _getOrCreateBuffers(Mesh mesh) {
    if (_meshBuffers.containsKey(mesh)) {
      return _meshBuffers[mesh]!;
    }

    final buffers = _MeshBuffers(
      vertexBuffer: _createBuffer(0x8892, mesh.vertices),
      indexBuffer: _createBuffer(0x8893, mesh.indices),
      normalBuffer: mesh.normals != null ? _createBuffer(0x8892, mesh.normals!) : null,
      colorBuffer: mesh.colors != null ? _createBuffer(0x8892, mesh.colors!) : null,
    );

    _meshBuffers[mesh] = buffers;
    return buffers;
  }

  dynamic _createBuffer(int target, dynamic data) {
    final buffer = gl.createBuffer();
    if (buffer == null) {
      throw Exception('Failed to create WebGL buffer');
    }

    gl.bindBuffer(target, buffer);
    gl.bufferData(target, data, 0x88E4); // STATIC_DRAW
    gl.bindBuffer(target, null);

    return buffer;
  }

  void deleteMeshBuffers(Mesh mesh) {
    final buffers = _meshBuffers.remove(mesh);
    if (buffers != null) {
      gl.deleteBuffer(buffers.vertexBuffer);
      gl.deleteBuffer(buffers.indexBuffer);
      if (buffers.normalBuffer != null) gl.deleteBuffer(buffers.normalBuffer);
      if (buffers.colorBuffer != null) gl.deleteBuffer(buffers.colorBuffer);
    }
  }

  void resize(int width, int height) {
    canvas.width = width;
    canvas.height = height;
    gl.viewport(0, 0, width, height);
  }

  void dispose() {
    for (final buffers in _meshBuffers.values) {
      gl.deleteBuffer(buffers.vertexBuffer);
      gl.deleteBuffer(buffers.indexBuffer);
      if (buffers.normalBuffer != null) gl.deleteBuffer(buffers.normalBuffer);
      if (buffers.colorBuffer != null) gl.deleteBuffer(buffers.colorBuffer);
    }
    _meshBuffers.clear();

    shader.dispose();
    unlitShader.dispose();

    debugPrint('[UltraballWebGL] WebGLRenderer disposed');
  }
}

class _MeshBuffers {
  final dynamic vertexBuffer;
  final dynamic indexBuffer;
  final dynamic normalBuffer;
  final dynamic colorBuffer;

  _MeshBuffers({
    required this.vertexBuffer,
    required this.indexBuffer,
    this.normalBuffer,
    this.colorBuffer,
  });
}
