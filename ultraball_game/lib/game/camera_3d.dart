import 'dart:math';
import 'package:flutter/material.dart';

class Camera3D {
  double camX = 70.0, camY = -30.0, camZ = 55.0;
  double targetX = 70.0, targetY = 22.0, targetZ = 0.0;
  double fovDegrees = 70.0;
  double near = 0.5, far = 500.0;

  Size _screenSize = Size.zero;
  final _mvp  = List<double>.filled(16, 0.0);
  final _view = List<double>.filled(16, 0.0);
  final _proj = List<double>.filled(16, 0.0);
  double _focalY = 1.0;

  void update(Size screenSize) {
    _screenSize = screenSize;
    final aspect = screenSize.width / screenSize.height;
    _buildLookAt();
    _buildPerspective(aspect);
    _multiply4x4(_proj, _view, _mvp);
  }

  /// Returns (screenOffset, clipZ) or null if behind camera.
  (Offset, double)? projectWithDepth(double wx, double wy, double wz) {
    final m = _mvp;
    final cx = m[0]*wx + m[4]*wy + m[8]*wz  + m[12];
    final cy = m[1]*wx + m[5]*wy + m[9]*wz  + m[13];
    final cz = m[2]*wx + m[6]*wy + m[10]*wz + m[14];
    final cw = m[3]*wx + m[7]*wy + m[11]*wz + m[15];

    if (cw <= 0.0) return null;

    final ndcX =  cx / cw;
    final ndcY =  cy / cw;
    final ndcZ =  cz / cw;

    if (ndcX < -1.5 || ndcX > 1.5 || ndcY < -1.5 || ndcY > 1.5) return null;
    if (ndcZ < -1.0 || ndcZ >  1.0) return null;

    final sx = (ndcX + 1.0) / 2.0 * _screenSize.width;
    final sy = (1.0 - ndcY) / 2.0 * _screenSize.height;
    return (Offset(sx, sy), cw);
  }

  Offset? project(double wx, double wy, double wz) =>
      projectWithDepth(wx, wy, wz)?.$1;

  /// Approximate projected radius for a circle of worldRadius at clip depth cw.
  double projectedRadius(double worldRadius, double cw) =>
      worldRadius * _focalY * _screenSize.height / (2.0 * cw);

  void _buildLookAt() {
    // Forward vector (camera → target)
    double fx = targetX - camX;
    double fy = targetY - camY;
    double fz = targetZ - camZ;
    final fl = sqrt(fx*fx + fy*fy + fz*fz);
    fx /= fl; fy /= fl; fz /= fl;

    // World UP = Z axis
    const ux = 0.0, uy = 0.0, uz = 1.0;

    // Right = forward × up
    double rx = fy*uz - fz*uy;
    double ry = fz*ux - fx*uz;
    double rz = fx*uy - fy*ux;
    final rl = sqrt(rx*rx + ry*ry + rz*rz);
    rx /= rl; ry /= rl; rz /= rl;

    // Corrected up = right × forward
    final vux = ry*fz - rz*fy;
    final vuy = rz*fx - rx*fz;
    final vuz = rx*fy - ry*fx;

    // Column-major view matrix (OpenGL convention)
    final v = _view;
    v[0]=rx;  v[4]=ry;  v[8]=rz;   v[12]=-(rx*camX + ry*camY + rz*camZ);
    v[1]=vux; v[5]=vuy; v[9]=vuz;  v[13]=-(vux*camX + vuy*camY + vuz*camZ);
    v[2]=-fx; v[6]=-fy; v[10]=-fz; v[14]=(fx*camX + fy*camY + fz*camZ);
    v[3]=0;   v[7]=0;   v[11]=0;   v[15]=1;
  }

  void _buildPerspective(double aspect) {
    final fovRad = fovDegrees * pi / 180.0;
    _focalY = 1.0 / tan(fovRad / 2.0);
    final focalX = _focalY / aspect;
    final nf = 1.0 / (near - far);

    final p = _proj;
    p.fillRange(0, 16, 0.0);
    p[0]  = focalX;
    p[5]  = _focalY;
    p[10] = (far + near) * nf;
    p[11] = -1.0;
    p[14] = 2.0 * far * near * nf;
  }

  void _multiply4x4(List<double> a, List<double> b, List<double> out) {
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        var sum = 0.0;
        for (var k = 0; k < 4; k++) {
          sum += a[k*4 + r] * b[c*4 + k];
        }
        out[c*4 + r] = sum;
      }
    }
  }
}
