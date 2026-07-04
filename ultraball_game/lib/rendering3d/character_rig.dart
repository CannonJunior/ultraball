import 'package:vector_math/vector_math.dart';
import 'mesh.dart';
import 'math/transform3d.dart';

enum AnimationState { idle, walk, attack, hit, death }

class RigPart {
  final Mesh mesh;
  final String name;

  final Vector3 restPosition;
  final Vector3 restRotation;
  final Vector3 scale;

  Vector3 animRotation = Vector3.zero();

  RigPart({
    required this.mesh,
    required this.name,
    required this.restPosition,
    Vector3? restRotation,
    Vector3? scale,
  })  : restRotation = restRotation?.clone() ?? Vector3.zero(),
        scale = scale?.clone() ?? Vector3(1, 1, 1);

  Transform3d getWorldTransform(Transform3d character) {
    final charMatrix = character.toMatrix();
    final worldPos = restPosition.clone();
    charMatrix.transform3(worldPos);

    final worldRot = character.rotation +
        Vector3(
          restRotation.x + animRotation.x,
          restRotation.y + animRotation.y,
          restRotation.z + animRotation.z,
        );

    return Transform3d(
      position: worldPos,
      rotation: worldRot,
      scale: scale.clone(),
    );
  }
}

class CharacterRig {
  final List<RigPart> parts;

  AnimationState animState = AnimationState.idle;
  double animTime = 0.0;

  bool isMoving = false;
  double moveSpeed = 0.0;

  double attackTimer = 0.0;
  double hitTimer = 0.0;

  bool isDead = false;
  double deathTimer = 0.0;

  CharacterRig({required this.parts});

  RigPart? _part(String name) {
    for (final p in parts) {
      if (p.name == name) return p;
    }
    return null;
  }

  RigPart? get head => _part('head');
  RigPart? get upperTorso => _part('upperTorso');
  RigPart? get lowerTorso => _part('lowerTorso');
  RigPart? get rightUpperArm => _part('rightUpperArm');
  RigPart? get leftUpperArm => _part('leftUpperArm');
  RigPart? get rightForearm => _part('rightForearm');
  RigPart? get leftForearm => _part('leftForearm');
  RigPart? get rightThigh => _part('rightThigh');
  RigPart? get leftThigh => _part('leftThigh');
  RigPart? get rightShin => _part('rightShin');
  RigPart? get leftShin => _part('leftShin');

  void triggerAttack() {
    attackTimer = 0.5;
  }

  void triggerHit() {
    hitTimer = 0.3;
  }

  void triggerDeath() {
    isDead = true;
    deathTimer = 0.0;
  }

  void resetDeath() {
    isDead = false;
    deathTimer = 0.0;
    attackTimer = 0.0;
    hitTimer = 0.0;
  }
}
