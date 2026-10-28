import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/domain/access_matrix.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/logo.dart';
import 'auth_controller.dart';

/// Shows for 1.5 s, then routes by session state (tap skips the wait).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  static const minDuration = Duration(milliseconds: 1500);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _elapsed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(SplashScreen.minDuration, () {
      _elapsed = true;
      _route();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _route() {
    if (!mounted || !_elapsed) return;
    final auth = ref.read(authControllerProvider);
    switch (auth.status) {
      case AuthStatus.unknown:
        return; // wait for the listener below
      case AuthStatus.signedIn:
        context.go(Routes.beranda);
      case AuthStatus.signedOut:
        context.go(auth.sessionExpired ? '${Routes.login}?expired=1' : Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (_, _) => _route());
    return Scaffold(
      backgroundColor: WipasColors.navy,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _elapsed = true;
          _route();
        },
        child: Stack(children: [
          Positioned.fill(top: null, bottom: 160, child: SizedBox(height: 260, child: CustomPaint(painter: _SplashChart()))),
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 40),
              const WipasLogo(size: 88, inverted: true),
              const SizedBox(height: WipasSpace.xl),
              Text('WIPAS',
                  style: WipasText.kpi.copyWith(color: Colors.white, fontSize: 34, letterSpacing: 3, height: 1.2)),
              const SizedBox(height: WipasSpace.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: WipasSpace.xxl),
                child: Text('Prediksi inbound, alokasi manpower lebih tepat',
                    textAlign: TextAlign.center,
                    style: WipasText.body.copyWith(color: Colors.white.withValues(alpha: 0.9), fontSize: 15)),
              ),
              const SizedBox(height: 220),
            ]),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: Column(children: [
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    color: WipasColors.teal,
                    backgroundColor: Colors.white24,
                    value: WipasMotion.reduced(context) ? 0.6 : null,
                  ),
                ),
              ),
              const SizedBox(height: WipasSpace.lg),
              Text('Warehouse Inbound Prediction & Allocation System',
                  style: WipasText.bodySmall.copyWith(color: Colors.white70)),
              const SizedBox(height: WipasSpace.sm),
              Text('Versi ${AppConfig.appVersion.substring(0, 3)}', style: WipasText.bodySmall.copyWith(color: Colors.white70)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Decorative trend lines behind the splash.
class _SplashChart extends CustomPainter {
  static const _pred = [0.55, 0.75, 0.4, 0.48, 0.25, 0.22, 0.33, 0.15, 0.08, -0.05];
  static const _proj = [0.65, 0.85, 0.5, 0.56, 0.35, 0.3, 0.42, 0.25, 0.2, 0.06];

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = Colors.white10;
    for (var i = 1; i <= 4; i++) {
      final y = size.height * i / 4.5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    Path line(List<double> ys) {
      final p = Path();
      for (var i = 0; i < ys.length; i++) {
        final pt = Offset(size.width * i / (ys.length - 1), size.height * (0.15 + ys[i] * 0.8));
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      return p;
    }

    final proj = Paint()
      ..color = WipasColors.seriesProjection
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final projPath = line(_proj);
    for (final metric in projPath.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 8), proj);
        d += 14;
      }
    }
    canvas.drawPath(
        line(_pred),
        Paint()
          ..color = WipasColors.teal
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
