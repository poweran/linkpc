import 'dart:math';

/// Mathematical foundation for higher-dimensional geometry (4D Euclidean space ℝ⁴),
/// Clifford torus Hopf fibration embeddings, 4D rotation group SO(4),
/// stereographic projections, and Fourier harmonic synthesis.
class MathConstants {
  static const double phi = 1.618033988749895; // Golden Ratio Φ
  static const double invPhi = 0.618033988749895; // 1 / Φ
  static const double tau = 2 * pi; // Full circle constant τ
  static const double sqrt2 = 1.4142135623730951;
  static const double invSqrt2 = 0.7071067811865475; // 1 / √2
}

/// 4-Dimensional Vector in ℝ⁴: (x, y, z, w).
class Vector4D {
  final double x;
  final double y;
  final double z;
  final double w;

  const Vector4D(this.x, this.y, this.z, this.w);

  static const Vector4D zero = Vector4D(0, 0, 0, 0);

  Vector4D operator +(Vector4D o) => Vector4D(x + o.x, y + o.y, z + o.z, w + o.w);
  Vector4D operator -(Vector4D o) => Vector4D(x - o.x, y - o.y, z - o.z, w - o.w);
  Vector4D operator *(double s) => Vector4D(x * s, y * s, z * s, w * s);
  Vector4D operator /(double s) => Vector4D(x / s, y / s, z / s, w / s);

  double dot(Vector4D o) => x * o.x + y * o.y + z * o.z + w * o.w;
  double get normSq => x * x + y * y + z * z + w * w;
  double get norm => sqrt(normSq);

  Vector4D normalize() {
    final n = norm;
    if (n < 1e-12) return Vector4D.zero;
    return this / n;
  }

  /// Stereographic projection from 3-sphere S³ ⊂ ℝ⁴ to ℝ³.
  /// [distance] represents the projection pole distance along the w-axis.
  Point3D projectStereographic({double distance = 1.6}) {
    final denom = max(0.12, distance - w);
    return Point3D(x / denom, y / denom, z / denom, w: w);
  }

  /// Perspective projection from ℝ⁴ directly into ℝ³ with depth attenuation.
  Point3D projectPerspective({double cameraDistance = 2.4}) {
    final factor = cameraDistance / max(0.2, cameraDistance + w);
    return Point3D(x * factor, y * factor, z * factor, w: w);
  }
}

/// 3-Dimensional Point with depth parameter w preserved for depth-shading.
class Point3D {
  final double x;
  final double y;
  final double z;
  final double w;

  const Point3D(this.x, this.y, this.z, {this.w = 0.0});

  /// Perspective projection from ℝ³ to 2D Screen space ℝ² (sx, sy).
  Point2D projectToScreen(double screenWidth, double screenHeight, {double fov = 340.0, double viewDistance = 3.2}) {
    final denom = max(0.2, viewDistance + z);
    final scale = fov / denom;
    final sx = screenWidth * 0.5 + x * scale;
    final sy = screenHeight * 0.5 + y * scale;
    final depthFactor = (denom / viewDistance).clamp(0.2, 2.5);
    return Point2D(sx, sy, depth: depthFactor, originalW: w);
  }
}

/// 2-Dimensional Screen Coordinate with depth metrics for lighting and alpha.
class Point2D {
  final double x;
  final double y;
  final double depth;
  final double originalW;

  const Point2D(this.x, this.y, {this.depth = 1.0, this.originalW = 0.0});
}

/// 4x4 Transformation Matrix in ℝ⁴ for SO(4) rotation group.
class Matrix4D {
  final List<double> m; // 16 elements row-major

  const Matrix4D(this.m);

  static Matrix4D identity() {
    return const Matrix4D([
      1, 0, 0, 0,
      0, 1, 0, 0,
      0, 0, 1, 0,
      0, 0, 0, 1,
    ]);
  }

  /// Rotation in the X-W plane by angle [rad].
  static Matrix4D rotationXW(double rad) {
    final c = cos(rad);
    final s = sin(rad);
    return Matrix4D([
      c,  0, 0, -s,
      0,  1, 0,  0,
      0,  0, 1,  0,
      s,  0, 0,  c,
    ]);
  }

  /// Rotation in the Y-Z plane by angle [rad].
  static Matrix4D rotationYZ(double rad) {
    final c = cos(rad);
    final s = sin(rad);
    return Matrix4D([
      1, 0,  0, 0,
      0, c, -s, 0,
      0, s,  c, 0,
      0, 0,  0, 1,
    ]);
  }

  /// Rotation in the Z-W plane by angle [rad].
  static Matrix4D rotationZW(double rad) {
    final c = cos(rad);
    final s = sin(rad);
    return Matrix4D([
      1, 0, 0,  0,
      0, 1, 0,  0,
      0, 0, c, -s,
      0, 0, s,  c,
    ]);
  }

  /// Rotation in the X-Y plane by angle [rad].
  static Matrix4D rotationXY(double rad) {
    final c = cos(rad);
    final s = sin(rad);
    return Matrix4D([
      c, -s, 0, 0,
      s,  c, 0, 0,
      0,  0, 1, 0,
      0,  0, 0, 1,
    ]);
  }

  /// Rotation in the X-Z plane by angle [rad].
  static Matrix4D rotationXZ(double rad) {
    final c = cos(rad);
    final s = sin(rad);
    return Matrix4D([
      c,  0, s, 0,
      0,  1, 0, 0,
     -s,  0, c, 0,
      0,  0, 0, 1,
    ]);
  }

  /// Rotation in the Y-W plane by angle [rad].
  static Matrix4D rotationYW(double rad) {
    final c = cos(rad);
    final s = sin(rad);
    return Matrix4D([
      1, 0, 0,  0,
      0, c, 0, -s,
      0, 0, 1,  0,
      0, s, 0,  c,
    ]);
  }

  /// Multiply this 4x4 matrix by another 4x4 matrix.
  Matrix4D operator *(Matrix4D o) {
    final res = List<double>.filled(16, 0.0);
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        double sum = 0.0;
        for (int k = 0; k < 4; k++) {
          sum += m[r * 4 + k] * o.m[k * 4 + c];
        }
        res[r * 4 + c] = sum;
      }
    }
    return Matrix4D(res);
  }

  /// Transform a 4D vector by this matrix.
  Vector4D transform(Vector4D v) {
    final nx = m[0] * v.x + m[1] * v.y + m[2] * v.z + m[3] * v.w;
    final ny = m[4] * v.x + m[5] * v.y + m[6] * v.z + m[7] * v.w;
    final nz = m[8] * v.x + m[9] * v.y + m[10] * v.z + m[11] * v.w;
    final nw = m[12] * v.x + m[13] * v.y + m[14] * v.z + m[15] * v.w;
    return Vector4D(nx, ny, nz, nw);
  }
}

/// 4D Clifford Torus generator embedded in 3-Sphere S³ ⊂ ℝ⁴.
/// Parameterized by:
///   x₁ = r₁ cos(u),  x₂ = r₁ sin(u)
///   x₃ = r₂ cos(v),  x₄ = r₂ sin(v)
/// where r₁ = r₂ = 1 / √2.
class CliffordTorus4D {
  static final List<List<Vector4D>> ringFamilies = _generateRings();

  static List<List<Vector4D>> _generateRings() {
    const int uRings = 14; // Family of nested circles
    const int vSteps = 36; // Discretization per circle
    final result = <List<Vector4D>>[];
    const r1 = MathConstants.invSqrt2;
    const r2 = MathConstants.invSqrt2;

    for (int i = 0; i < uRings; i++) {
      final u = (i / uRings) * MathConstants.tau;
      final ring = <Vector4D>[];
      final cosU = cos(u);
      final sinU = sin(u);

      for (int j = 0; j <= vSteps; j++) {
        final v = (j / vSteps) * MathConstants.tau;
        // Point in ℝ⁴ on S³
        final p = Vector4D(
          r1 * cosU,
          r1 * sinU,
          r2 * cos(v),
          r2 * sin(v),
        );
        ring.add(p);
      }
      result.add(ring);
    }
    return result;
  }

  /// Villarceau Hopf Fibers (isoclinic circles winding simultaneously in u and v).
  static final List<List<Vector4D>> hopfFibers = _generateHopfFibers();

  static List<List<Vector4D>> _generateHopfFibers() {
    const int fiberCount = 12;
    const int steps = 48;
    final result = <List<Vector4D>>[];
    const r1 = MathConstants.invSqrt2;
    const r2 = MathConstants.invSqrt2;

    for (int k = 0; k < fiberCount; k++) {
      final delta = (k / fiberCount) * MathConstants.tau;
      final fiber = <Vector4D>[];

      for (int s = 0; s <= steps; s++) {
        final t = (s / steps) * MathConstants.tau;
        final u = t;
        final v = t + delta; // Villarceau Hopf geodesic
        fiber.add(Vector4D(
          r1 * cos(u),
          r1 * sin(u),
          r2 * cos(v),
          r2 * sin(v),
        ));
      }
      result.add(fiber);
    }
    return result;
  }
}

/// 4D Regular Tesseract (Hypercube) with 16 vertices and 32 edges.
class Tesseract4D {
  static final List<Vector4D> vertices = _generateVertices();
  static final List<EdgeIndex> edges = _generateEdges();

  static List<Vector4D> _generateVertices() {
    final list = <Vector4D>[];
    for (int i = 0; i < 16; i++) {
      final x = (i & 1) != 0 ? 0.65 : -0.65;
      final y = (i & 2) != 0 ? 0.65 : -0.65;
      final z = (i & 4) != 0 ? 0.65 : -0.65;
      final w = (i & 8) != 0 ? 0.65 : -0.65;
      list.add(Vector4D(x, y, z, w));
    }
    return list;
  }

  static List<EdgeIndex> _generateEdges() {
    final edgeList = <EdgeIndex>[];
    for (int i = 0; i < 16; i++) {
      for (int j = i + 1; j < 16; j++) {
        final diff = i ^ j;
        // If they differ by exactly one bit (power of 2), there is an edge
        if (diff != 0 && (diff & (diff - 1)) == 0) {
          edgeList.add(EdgeIndex(i, j));
        }
      }
    }
    return edgeList;
  }
}

class EdgeIndex {
  final int a;
  final int b;
  const EdgeIndex(this.a, this.b);
}

/// Critically damped smoothing filter for continuous C² transitions without overshoot.
class SmoothDamp {
  double current;
  double velocity;

  SmoothDamp({this.current = 0.0, this.velocity = 0.0});

  double update(double target, double smoothTime, double dt, {double maxSpeed = double.infinity}) {
    smoothTime = max(0.0001, smoothTime);
    final omega = 2.0 / smoothTime;
    final x = omega * dt;
    final expFactor = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x);
    var change = current - target;
    final originalTo = target;

    final maxChange = maxSpeed * smoothTime;
    change = change.clamp(-maxChange, maxChange);
    target = current - change;

    final temp = (velocity + omega * change) * dt;
    velocity = (velocity - omega * temp) * expFactor;
    var output = target + (change + temp) * expFactor;

    if ((originalTo - current > 0.0) == (output > originalTo)) {
      output = originalTo;
      velocity = dt > 0 ? (output - originalTo) / dt : 0.0;
    }

    current = output;
    return current;
  }
}

/// Continuous phase and momentum integrator for jerk-free rotational and wave dynamics.
/// Guaranteed C¹ continuity: θ(t) = ∫ ω(t) dt.
class PhaseIntegrator {
  double phase = 0.0;
  double currentSpeed = 0.0;

  PhaseIntegrator({this.phase = 0.0, this.currentSpeed = 0.0});

  double update(double targetSpeed, double dt, {double responsiveness = 4.5}) {
    final blend = 1.0 - exp(-responsiveness * dt);
    currentSpeed += (targetSpeed - currentSpeed) * blend;
    phase += currentSpeed * dt;
    return phase;
  }
}

/// Fourier series generator for network flow harmonics.
/// y(x, t) = Σ [ Aₖ · sin(k·ω·x - ωₖ·t + φₖ) ]
class FourierFlowHarmonics {
  static double evaluate({
    required double normalizedX,
    required double time,
    required double baseFrequency,
    required double fundamentalAmp,
    required int harmonicCount,
  }) {
    double value = 0.0;
    double amp = fundamentalAmp;

    for (int k = 1; k <= harmonicCount; k++) {
      final kD = k.toDouble();
      final phase = kD * baseFrequency * normalizedX * MathConstants.tau - (time * kD * 1.5) + (kD * 0.45);
      value += amp * sin(phase);
      // Power-law harmonic decay: 1 / k^1.2 (approximating 1/f network spectral density)
      amp = fundamentalAmp / pow(kD + 1.0, 1.2);
    }
    return value;
  }
}
