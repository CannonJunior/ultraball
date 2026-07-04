import 'package:flutter/foundation.dart' show debugPrint;
import 'package:vector_math/vector_math.dart';

class ShaderProgram {
  final dynamic gl;
  final dynamic program;

  final Map<String, dynamic> _uniformLocations = {};
  final Map<String, int> _attribLocations = {};

  ShaderProgram._(this.gl, this.program);

  factory ShaderProgram.fromSource(
    dynamic gl,
    String vertexSource,
    String fragmentSource,
  ) {
    final vertexShader = _compileShader(gl, 0x8B31, vertexSource);
    if (vertexShader == null) {
      throw Exception('Failed to compile vertex shader');
    }

    final fragmentShader = _compileShader(gl, 0x8B30, fragmentSource);
    if (fragmentShader == null) {
      gl.deleteShader(vertexShader);
      throw Exception('Failed to compile fragment shader');
    }

    final program = gl.createProgram();
    if (program == null) {
      gl.deleteShader(vertexShader);
      gl.deleteShader(fragmentShader);
      throw Exception('Failed to create shader program');
    }

    gl.attachShader(program, vertexShader);
    gl.attachShader(program, fragmentShader);
    gl.linkProgram(program);

    if (gl.getProgramParameter(program, 0x8B82) == 0) {
      final error = gl.getProgramInfoLog(program);
      gl.deleteProgram(program);
      gl.deleteShader(vertexShader);
      gl.deleteShader(fragmentShader);
      throw Exception('Failed to link shader program: $error');
    }

    gl.deleteShader(vertexShader);
    gl.deleteShader(fragmentShader);

    return ShaderProgram._(gl, program);
  }

  static dynamic _compileShader(dynamic gl, int type, String source) {
    final shader = gl.createShader(type);
    if (shader == null) return null;

    gl.shaderSource(shader, source);
    gl.compileShader(shader);

    if (gl.getShaderParameter(shader, 0x8B81) == 0) {
      final error = gl.getShaderInfoLog(shader);
      debugPrint('Shader compile error: $error');
      debugPrint('Source:\n$source');
      gl.deleteShader(shader);
      return null;
    }

    return shader;
  }

  void use() {
    gl.useProgram(program);
  }

  dynamic _getUniformLocation(String name) {
    if (_uniformLocations.containsKey(name)) {
      return _uniformLocations[name];
    }

    try {
      final location = gl.getUniformLocation(program, name);
      if (location != null) {
        _uniformLocations[name] = location;
      }
      return location;
    } catch (e) {
      return null;
    }
  }

  int getAttribLocation(String name) {
    if (_attribLocations.containsKey(name)) {
      return _attribLocations[name]!;
    }

    final location = gl.getAttribLocation(program, name);
    _attribLocations[name] = location;
    return location;
  }

  void setUniformMatrix4(String name, Matrix4 matrix) {
    final location = _getUniformLocation(name);
    if (location != null) {
      gl.uniformMatrix4fv(location, false, matrix.storage);
    }
  }

  void setUniformVector3(String name, Vector3 vector) {
    final location = _getUniformLocation(name);
    if (location != null) {
      gl.uniform3f(location, vector.x, vector.y, vector.z);
    }
  }

  void setUniformVector4(String name, Vector4 vector) {
    final location = _getUniformLocation(name);
    if (location != null) {
      gl.uniform4f(location, vector.x, vector.y, vector.z, vector.w);
    }
  }

  void setUniformFloat(String name, double value) {
    final location = _getUniformLocation(name);
    if (location != null) {
      gl.uniform1f(location, value);
    }
  }

  void setUniformInt(String name, int value) {
    final location = _getUniformLocation(name);
    if (location != null) {
      gl.uniform1i(location, value);
    }
  }

  void setUniformBool(String name, bool value) {
    final location = _getUniformLocation(name);
    if (location != null) {
      gl.uniform1i(location, value ? 1 : 0);
    }
  }

  void setUniformSampler2D(String name, int textureUnit) {
    final location = _getUniformLocation(name);
    if (location != null) {
      gl.uniform1i(location, textureUnit);
    }
  }

  void setUniformVector2(String name, double x, double y) {
    final location = _getUniformLocation(name);
    if (location != null) {
      gl.uniform2f(location, x, y);
    }
  }

  void dispose() {
    gl.deleteProgram(program);
    _uniformLocations.clear();
    _attribLocations.clear();
  }
}

const String defaultVertexShader = '''
attribute vec3 aPosition;
attribute vec3 aNormal;
attribute vec4 aColor;

uniform mat4 uProjection;
uniform mat4 uView;
uniform mat4 uModel;

varying vec3 vNormal;
varying vec4 vColor;
varying vec3 vFragPos;

void main() {
  vec4 worldPos = uModel * vec4(aPosition, 1.0);
  vFragPos = worldPos.xyz;
  vNormal = mat3(uModel) * aNormal;
  vColor = aColor;
  gl_Position = uProjection * uView * worldPos;
}
''';

const String defaultFragmentShader = '''
precision mediump float;

varying vec3 vNormal;
varying vec4 vColor;
varying vec3 vFragPos;

uniform vec3 uLightPos;
uniform vec3 uLightColor;
uniform vec3 uAmbientColor;

void main() {
  vec3 ambient = uAmbientColor;

  vec3 norm = normalize(vNormal);
  vec3 lightDir = normalize(uLightPos - vFragPos);
  float diff = max(dot(norm, lightDir), 0.0);
  vec3 diffuse = diff * uLightColor;

  vec3 result = (ambient + diffuse) * vColor.rgb;
  gl_FragColor = vec4(result, vColor.a);
}
''';

const String unlitVertexShader = '''
attribute vec3 aPosition;
attribute vec4 aColor;

uniform mat4 uProjection;
uniform mat4 uView;
uniform mat4 uModel;

varying vec4 vColor;

void main() {
  vColor = aColor;
  gl_Position = uProjection * uView * uModel * vec4(aPosition, 1.0);
}
''';

const String unlitFragmentShader = '''
precision mediump float;

varying vec4 vColor;

void main() {
  gl_FragColor = vColor;
}
''';
