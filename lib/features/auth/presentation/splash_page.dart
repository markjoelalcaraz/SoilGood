/// Index splash played once every time SoilGood opens.
///
/// Hills rise, then the leaf, name, and tagline. It covers login or the farm
/// until the motion finishes, then calls [onFinished]. Not a shell tab.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

/// True after the opening splash has finished. Login uses this so its photo
/// starts moving when the splash clears, not while it is still covered.
class AppReveal extends InheritedWidget {
  const AppReveal({required this.ready, required super.child, super.key});

  final bool ready;

  /// Whether the opening splash is done. Missing scope means already revealed.
  static bool readyOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppReveal>();
    return scope?.ready ?? true;
  }

  @override
  bool updateShouldNotify(AppReveal oldWidget) => ready != oldWidget.ready;
}

/// Illustrated open screen. [onFinished] runs after the fade.
class SplashPage extends StatefulWidget {
  const SplashPage({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        widget.onFinished();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _span(double start, double end) {
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fade = _span(0.84, 1);
    return FadeTransition(
      opacity: ReverseAnimation(fade),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7FBFF),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Pop(
                      animation: _span(0.16, 0.36),
                      child: const Icon(
                        Icons.eco,
                        size: 72,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Rise(
                      animation: _span(0.25, 0.45),
                      child: Text(
                        'SoilGood',
                        style: GoogleFonts.literata(
                          fontSize: 42,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _Rise(
                      animation: _span(0.34, 0.52),
                      child: const Text(
                        'Know your soil before you water',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 180,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _HillSlide(
                      animation: _span(0.02, 0.28),
                      painter: const _HillPainter(front: false),
                    ),
                    _HillSlide(
                      animation: _span(0.08, 0.36),
                      painter: const _HillPainter(front: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pop extends StatelessWidget {
  const _Pop({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.7, end: 1).animate(animation),
        child: child,
      ),
    );
  }
}

class _Rise extends StatelessWidget {
  const _Rise({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.35),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

class _HillSlide extends StatelessWidget {
  const _HillSlide({required this.animation, required this.painter});

  final Animation<double> animation;
  final CustomPainter painter;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1.1),
          end: Offset.zero,
        ).animate(animation),
        child: CustomPaint(painter: painter, child: const SizedBox.expand()),
      ),
    );
  }
}

/// One of the two splash hills. [front] is the darker, lower hill.
class _HillPainter extends CustomPainter {
  const _HillPainter({required this.front});

  final bool front;

  @override
  void paint(Canvas canvas, Size size) {
    final path = front ? _front(size) : _back(size);
    final color = front ? const Color(0xFF6FBF45) : const Color(0xFF8ED15A);
    canvas.drawPath(path, Paint()..color = color);
  }

  Path _back(Size size) {
    return Path()
      ..moveTo(0, size.height * 0.42)
      ..cubicTo(
        size.width * 0.23,
        size.height * 0.18,
        size.width * 0.38,
        size.height * 0.55,
        size.width * 0.59,
        size.height * 0.34,
      )
      ..cubicTo(
        size.width * 0.77,
        size.height * 0.16,
        size.width * 0.87,
        size.height * 0.28,
        size.width,
        size.height * 0.12,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  Path _front(Size size) {
    return Path()
      ..moveTo(0, size.height * 0.68)
      ..cubicTo(
        size.width * 0.26,
        size.height * 0.5,
        size.width * 0.41,
        size.height * 0.82,
        size.width * 0.62,
        size.height * 0.64,
      )
      ..cubicTo(
        size.width * 0.8,
        size.height * 0.48,
        size.width * 0.9,
        size.height * 0.58,
        size.width,
        size.height * 0.48,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _HillPainter oldDelegate) =>
      front != oldDelegate.front;
}
