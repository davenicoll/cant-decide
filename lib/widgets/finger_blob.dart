import 'dart:math';
import 'package:flutter/material.dart';
import '../models/touch_point.dart';

class FingerBlob extends StatefulWidget {
  final TouchPoint touchPoint;
  final Size screenSize;
  final VoidCallback? onFallComplete;
  final VoidCallback? onChosenAnimationComplete;
  final int remainingSeconds;
  final int totalSeconds;
  final bool shouldFadeOut;

  const FingerBlob({
    super.key,
    required this.touchPoint,
    required this.screenSize,
    this.onFallComplete,
    this.onChosenAnimationComplete,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.shouldFadeOut = false,
  });

  @override
  State<FingerBlob> createState() => _FingerBlobState();
}

class _FingerBlobState extends State<FingerBlob>
    with TickerProviderStateMixin {
  static const double baseSize = 150.0;
  static const double blackHoleSize = 200.0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late AnimationController _chosenController;
  late Animation<double> _scaleAnimation;

  late AnimationController _blackHoleController;
  late Animation<double> _blackHoleAnimation;
  late Animation<double> _textOpacityAnimation;

  late AnimationController _fadeOutController;
  late Animation<double> _fadeOutAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation for idle state - speed based on remaining time
    _pulseController = AnimationController(
      duration: _calculatePulseDuration(),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // Fade animation - quick fade to black (for losers)
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFallComplete?.call();
      }
    });

    // Chosen animation - slow grow to fill screen
    _chosenController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(parent: _chosenController, curve: Curves.easeOutCubic),
    );
    _chosenController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onChosenAnimationComplete?.call();
      }
    });

    // Black hole animation - appears and grows slightly
    _blackHoleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _blackHoleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _blackHoleController, curve: Curves.easeOutCubic),
    );
    _textOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _blackHoleController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );

    // Fade out animation - for end of round
    _fadeOutController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeOutController, curve: Curves.easeOut),
    );
  }

  Duration _calculatePulseDuration() {
    // Start at 1200ms, speed up to 150ms as timer approaches 0
    if (widget.totalSeconds == 0) return const Duration(milliseconds: 1200);
    final ratio = widget.remainingSeconds / widget.totalSeconds;
    final ms = 150 + (ratio * 1050).toInt(); // 150ms to 1200ms
    return Duration(milliseconds: ms);
  }

  @override
  void didUpdateWidget(FingerBlob oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update pulse speed when remaining seconds changes
    if (widget.remainingSeconds != oldWidget.remainingSeconds &&
        widget.touchPoint.state == TouchState.active) {
      final newDuration = _calculatePulseDuration();
      _pulseController.duration = newDuration;
    }

    if (widget.touchPoint.state != oldWidget.touchPoint.state) {
      if (widget.touchPoint.state == TouchState.falling) {
        _pulseController.stop();
        _fadeController.forward();
      } else if (widget.touchPoint.state == TouchState.chosen) {
        _pulseController.stop();
        // Calculate scale needed to fill the screen
        final maxDimension = widget.screenSize.longestSide * 2;
        final targetScale = maxDimension / baseSize;
        _scaleAnimation = Tween<double>(begin: 1.0, end: targetScale).animate(
          CurvedAnimation(parent: _chosenController, curve: Curves.easeOutCubic),
        );
        _chosenController.forward();
        // Start black hole animation after a short delay
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _blackHoleController.forward();
          }
        });
      }
    }

    // Handle fade out for end of round
    if (widget.shouldFadeOut && !oldWidget.shouldFadeOut) {
      _fadeOutController.forward();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _chosenController.dispose();
    _blackHoleController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _pulseController,
        _fadeController,
        _chosenController,
        _blackHoleController,
        _fadeOutController,
      ]),
      builder: (context, child) {
        double scale = _pulseAnimation.value;
        double opacity = 1.0;

        if (widget.touchPoint.state == TouchState.falling) {
          scale = 1.0;
          opacity = _fadeAnimation.value;
        } else if (widget.touchPoint.state == TouchState.chosen) {
          scale = _scaleAnimation.value;
          opacity = _fadeOutAnimation.value;
        }

        final isChosen = widget.touchPoint.state == TouchState.chosen;

        return Stack(
          children: [
            // Main colored blob
            Positioned(
              left: widget.touchPoint.position.dx - (baseSize * scale / 2),
              top: widget.touchPoint.position.dy - (baseSize * scale / 2),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: baseSize * scale,
                  height: baseSize * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.touchPoint.color,
                  ),
                ),
              ),
            ),

            // Black hole with text (only when chosen)
            if (isChosen)
              Positioned(
                left: widget.touchPoint.position.dx - (blackHoleSize / 2),
                top: widget.touchPoint.position.dy - (blackHoleSize / 2),
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: _blackHoleAnimation.value,
                    child: Container(
                      width: blackHoleSize,
                      height: blackHoleSize,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                      ),
                      child: Center(
                        child: Opacity(
                          opacity: _textOpacityAnimation.value,
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'YOU ARE\nTHE CHOSEN\nONE',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: widget.touchPoint.color,
                                  fontSize: 28,
                                  fontFamily: 'MarkPro',
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
