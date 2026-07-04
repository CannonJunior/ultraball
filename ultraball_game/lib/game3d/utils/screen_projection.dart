import 'dart:ui';
import 'package:vector_math/vector_math.dart';

/// Project a 3D world position to 2D screen coordinates.
///
/// Returns null if the point is behind the camera (clipVec.w <= 0).
Offset? worldToScreen(
  Vector3 worldPos,
  Matrix4 viewMatrix,
  Matrix4 projMatrix,
  Size screenSize,
) {
  final worldVec = Vector4(worldPos.x, worldPos.y, worldPos.z, 1.0);
  final viewVec = viewMatrix.transform(worldVec);
  final clipVec = projMatrix.transform(viewVec);

  if (clipVec.w <= 0.0) return null;

  final ndcX = clipVec.x / clipVec.w;
  final ndcY = clipVec.y / clipVec.w;

  // Y is flipped: WebGL NDC top=-1 maps to Flutter screen top=0
  final screenX = ((ndcX + 1.0) / 2.0) * screenSize.width;
  final screenY = ((1.0 - ndcY) / 2.0) * screenSize.height;

  return Offset(screenX, screenY);
}
