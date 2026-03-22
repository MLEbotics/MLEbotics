import 'dart:math';

import 'package:flutter/material.dart';

class EveningRiverScene extends StatefulWidget {
  const EveningRiverScene({super.key});

  @override
  State<EveningRiverScene> createState() => _EveningRiverSceneState();
}

class _EveningRiverSceneState extends State<EveningRiverScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_Star> _stars = [];
  final List<_Firefly> _fireflies = [];

  @override
  void initState() {
    super.initState();
    _seedScene();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  void _seedScene() {
    final rng = Random(14);
    _stars
      ..clear()
      ..addAll(
        List.generate(
          70,
          (_) => _Star(
            x: rng.nextDouble(),
            y: rng.nextDouble() * 0.55,
            r: rng.nextDouble() * 1.1 + 0.35,
            a: rng.nextDouble() * 0.55 + 0.25,
            sp: rng.nextDouble() * 1.6 + 0.4,
            ph: rng.nextDouble() * pi * 2,
          ),
        ),
      );

    _fireflies
      ..clear()
      ..addAll(
        List.generate(
          24,
          (_) => _Firefly(
            x: 0.38 + rng.nextDouble() * 0.56,
            y: 0.62 + rng.nextDouble() * 0.34,
            vx: (rng.nextDouble() - 0.5) * 0.0012,
            vy: (rng.nextDouble() - 0.5) * 0.0009,
            r: rng.nextDouble() * 1.4 + 0.5,
            blink: rng.nextDouble() * 2.2 + 0.7,
            ph: rng.nextDouble() * pi * 2,
            warm: rng.nextBool(),
          ),
        ),
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder:
          (_, __) => CustomPaint(
            painter: _EveningRiverPainter(
              time: _controller.value * 18.0,
              stars: _stars,
              fireflies: _fireflies,
            ),
          ),
    );
  }
}

class _EveningRiverPainter extends CustomPainter {
  _EveningRiverPainter({
    required this.time,
    required this.stars,
    required this.fireflies,
  });

  final double time;
  final List<_Star> stars;
  final List<_Firefly> fireflies;

  static const List<_Lamp> _lamps = [
    _Lamp(0.10, -1, 0.0),
    _Lamp(0.10, 1, 0.7),
    _Lamp(0.35, -1, 1.2),
    _Lamp(0.35, 1, 1.9),
    _Lamp(0.62, -1, 2.4),
    _Lamp(0.62, 1, 3.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final hz = h * 0.58;

    // Sky
    final skyRect = Rect.fromLTWH(0, 0, w, hz + 1);
    final skyPaint =
        Paint()
          ..shader = const LinearGradient(
            colors: [
              Color(0xFF06041A),
              Color(0xFF100A28),
              Color(0xFF2C1026),
              Color(0xFF5D1900),
              Color(0xFF8A2A00),
            ],
            stops: [0.0, 0.28, 0.6, 0.82, 1.0],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(skyRect);
    canvas.drawRect(skyRect, skyPaint);

    // Horizon glow
    final glowPaint =
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0x44FF641C),
              const Color(0x1FDF5A0A),
              const Color(0x00000000),
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(
            Rect.fromCircle(center: Offset(w * 0.38, hz), radius: w * 0.55),
          );
    canvas.drawRect(skyRect, glowPaint);

    // Stars
    for (final s in stars) {
      final tw = 0.32 + 0.68 * sin(time * s.sp + s.ph).abs();
      final alpha = (s.a * tw).clamp(0.0, 1.0);
      final paint = Paint()..color = Colors.white.withOpacity(alpha);
      canvas.drawCircle(Offset(s.x * w, s.y * h), s.r, paint);
    }

    // Moon
    final moon = Offset(w * 0.77, h * 0.17);
    final mr = min(w, h) * 0.042;
    final haloPaint =
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0x1FFFF8D2),
              const Color(0x0DFFE6A5),
              const Color(0x00FFD26E),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: moon, radius: mr * 9));
    canvas.drawCircle(moon, mr * 9, haloPaint);

    final coronaPaint =
        Paint()
          ..shader = RadialGradient(
            colors: [const Color(0x47FFFFF0), const Color(0x00FFF8C8)],
            stops: const [0.0, 1.0],
          ).createShader(Rect.fromCircle(center: moon, radius: mr * 2.5));
    canvas.drawCircle(moon, mr * 2.5, coronaPaint);
    canvas.drawCircle(moon, mr, Paint()..color = const Color(0xFFFFFBF0));

    // Ground
    final groundRect = Rect.fromLTWH(0, hz, w, h - hz);
    final groundPaint =
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF0B0D09), Color(0xFF060706)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(groundRect);
    canvas.drawRect(groundRect, groundPaint);

    // River / waterway
    final rx = w * 0.56;
    final waterRect = Rect.fromLTWH(rx, hz, w - rx, h - hz);
    final waterPaint =
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF091726), Color(0xFF050C12)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(waterRect);
    canvas.drawRect(waterRect, waterPaint);

    // Water shimmer
    for (int i = 0; i < 11; i++) {
      final wy = hz + (waterRect.height / 12) * (i + 0.5) + 5;
      final sa = 0.035 + 0.07 * (sin(time * 1.35 + i * 0.9)).abs();
      final sw = 24 + 56 * (sin(time * 0.65 + i * 1.55)).abs();
      final sx =
          rx + 8 + (sin(time * 0.38 + i)).abs() * (waterRect.width - sw - 18);
      final shimmer =
          Paint()
            ..color = const Color(0xFF69AFEB).withOpacity(sa)
            ..strokeWidth = 1.5;
      canvas.drawLine(Offset(sx, wy), Offset(sx + sw, wy), shimmer);
    }

    // Moon reflection
    canvas.save();
    canvas.clipRect(waterRect);
    final refX = rx + (moon.dx / w) * waterRect.width;
    final refPaint =
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0x33FFF8D2), Color(0x00FFF8D2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(waterRect);
    final rw = 26 + 9 * sin(time * 0.52);
    canvas.drawRect(
      Rect.fromLTWH(refX - rw * 0.5 + 5 * sin(time * 1.1), hz, rw, h - hz),
      refPaint,
    );
    canvas.restore();

    // Pathway
    final pcx = w * 0.36;
    final ptw = w * 0.018;
    final pbw = w * 0.115;
    final path =
        Path()
          ..moveTo(pcx - ptw, hz)
          ..lineTo(pcx + ptw, hz)
          ..lineTo(pcx + pbw, h)
          ..lineTo(pcx - pbw, h)
          ..close();
    final pathPaint =
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF171310), Color(0xFF1F1C14)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(groundRect);
    canvas.drawPath(path, pathPaint);

    final edgePaint =
        Paint()
          ..color = const Color(0xFF584C34).withOpacity(0.22)
          ..strokeWidth = 1;
    canvas.drawLine(Offset(pcx - ptw, hz), Offset(pcx - pbw, h), edgePaint);
    canvas.drawLine(Offset(pcx + ptw, hz), Offset(pcx + pbw, h), edgePaint);

    // Far treeline
    final far = Path()..moveTo(0, hz + 1);
    for (int i = 0; i <= 30; i++) {
      final tx = w * 0.30 * (i / 30);
      far.lineTo(tx, hz - (42 + 36 * (sin(i * 1.85 + 0.4)).abs()));
    }
    far.lineTo(w * 0.30, hz + 1);
    far.close();
    canvas.drawPath(far, Paint()..color = const Color(0xFF08090B));

    // Left treeline
    final lEdge = pcx - pbw * 0.92;
    final left =
        Path()
          ..moveTo(0, h)
          ..lineTo(0, hz - 8);
    for (int i = 0; i <= 24; i++) {
      final tx = lEdge * (i / 24);
      left.lineTo(tx, hz - (88 + 135 * (sin(i * 2.25 + 0.85)).abs()));
    }
    left
      ..lineTo(lEdge, hz)
      ..lineTo(lEdge, h)
      ..close();
    canvas.drawPath(left, Paint()..color = const Color(0xFF050709));

    // Right treeline (between path and river)
    final rStart = pcx + pbw * 0.92;
    final right =
        Path()
          ..moveTo(rStart, h)
          ..lineTo(rStart, hz);
    for (int i = 0; i <= 18; i++) {
      final tx = rStart + (rx - rStart) * (i / 18);
      right.lineTo(tx, hz - (72 + 115 * (sin(i * 2.6 + 1.35)).abs()));
    }
    right
      ..lineTo(rx + 4, hz)
      ..lineTo(rx, h)
      ..close();
    canvas.drawPath(right, Paint()..color = const Color(0xFF040608));

    // Lamp posts
    for (final lp in _lamps) {
      final pathW = ptw + (pbw - ptw) * lp.prog;
      final lx = pcx + lp.side * (pathW * 1.18 + 5);
      final ly = hz + (h - hz) * lp.prog;
      final ls = 1.2 + 5.8 * lp.prog;
      final flk = 0.7 + 0.3 * sin(time * 4.2 + lp.phase).abs();

      final glow =
          Paint()
            ..shader = RadialGradient(
              colors: [
                Color.lerp(
                  const Color(0x00FF6E0A),
                  const Color(0x84FFAF3A),
                  flk,
                )!,
                Color.lerp(
                  const Color(0x00FF5A0A),
                  const Color(0x2BFF8C26),
                  flk,
                )!,
                const Color(0x00FF5A0A),
              ],
              stops: const [0.0, 0.28, 1.0],
            ).createShader(
              Rect.fromCircle(center: Offset(lx, ly), radius: ls * 14),
            );
      canvas.drawCircle(Offset(lx, ly), ls * 14, glow);

      final bulb =
          Paint()..color = const Color(0xFFFFF6C8).withOpacity(0.96 * flk);
      canvas.drawCircle(Offset(lx, ly), ls * 0.62, bulb);
    }

    // Fireflies
    for (final p in fireflies) {
      final px = ((p.x + p.vx * time) % 1.0) * w;
      final py = ((p.y + p.vy * time) % 1.0) * h;
      if (py < hz) continue;
      final a = 0.16 + 0.4 * sin(time * p.blink + p.ph).abs();
      final color = p.warm ? const Color(0xFFFFBC58) : const Color(0xFF87D2FF);
      final firePaint = Paint()..color = color.withOpacity(a);
      canvas.drawCircle(Offset(px, py), p.r, firePaint);
    }

    // Runner silhouette (natural stride)
    final runProg = (time % 18.0) / 18.0;
    final runX = w * (1.12 - 1.26 * runProg);
    final scale = (w / 500).clamp(0.9, 1.4);
    final stride = time * 6.2;
    final step = sin(stride);
    final groundY = hz + (h - hz) * 0.60;
    final runY = groundY - 28 * scale - 4 * sin(stride * 0.5).abs();

    final runner =
        Paint()
          ..color = const Color(0xFF06040A)
          ..strokeWidth = 3.2 * scale
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

    final hip = Offset(runX, runY);
    final shoulder = Offset(runX + 4 * scale, runY - 20 * scale);

    // Head
    canvas.drawCircle(
      Offset(shoulder.dx + 4 * scale, shoulder.dy - 8 * scale),
      6 * scale,
      runner,
    );

    // Torso
    canvas.drawLine(
      Offset(shoulder.dx, shoulder.dy + 2 * scale),
      Offset(hip.dx, hip.dy),
      runner,
    );

    // Arms (opposite to legs)
    final armSwing = step;
    canvas.drawLine(
      Offset(shoulder.dx, shoulder.dy + 2 * scale),
      Offset(shoulder.dx + 14 * scale * armSwing, shoulder.dy - 6 * scale),
      runner,
    );
    canvas.drawLine(
      Offset(shoulder.dx - 2 * scale, shoulder.dy + 4 * scale),
      Offset(shoulder.dx - 12 * scale * armSwing, shoulder.dy + 10 * scale),
      runner,
    );

    // Legs
    void drawLeg(double swing, double phase) {
      final liftAmt =
          10 * scale * (0.3 + 0.7 * (0.5 - 0.5 * cos(stride + phase)).abs());
      final footY = groundY - (swing > 0 ? liftAmt : 2 * scale);
      final footX = hip.dx + swing * 16 * scale;
      final kneeX = hip.dx + swing * 9 * scale;
      final kneeY = hip.dy + 14 * scale - (swing > 0 ? liftAmt * 0.5 : 0);

      canvas.drawLine(hip, Offset(kneeX, kneeY), runner);
      canvas.drawLine(Offset(kneeX, kneeY), Offset(footX, footY), runner);
    }

    drawLeg(step, 0.0);
    drawLeg(-step, pi);

    // Ground shadow to anchor the figure
    final shadow = Paint()..color = Colors.black.withOpacity(0.35);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(runX, groundY + 2 * scale),
        width: 28 * scale,
        height: 6 * scale,
      ),
      shadow,
    );

    // Horizon mist
    final mist =
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0x0058341C), Color(0x0F58341C), Color(0x0058341C)],
            stops: [0.0, 0.42, 1.0],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(0, hz - 28, w, 66));
    canvas.drawRect(Rect.fromLTWH(0, hz - 28, w, 66), mist);
  }

  @override
  bool shouldRepaint(_EveningRiverPainter oldDelegate) {
    return oldDelegate.time != time;
  }
}

class _Star {
  _Star({
    required this.x,
    required this.y,
    required this.r,
    required this.a,
    required this.sp,
    required this.ph,
  });

  final double x;
  final double y;
  final double r;
  final double a;
  final double sp;
  final double ph;
}

class _Firefly {
  _Firefly({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.r,
    required this.blink,
    required this.ph,
    required this.warm,
  });

  final double x;
  final double y;
  final double vx;
  final double vy;
  final double r;
  final double blink;
  final double ph;
  final bool warm;
}

class _Lamp {
  const _Lamp(this.prog, this.side, this.phase);

  final double prog;
  final double side;
  final double phase;
}
