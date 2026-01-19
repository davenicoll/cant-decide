import 'package:flutter/material.dart';
import '../models/touch_point.dart';

class FingerBlob extends StatefulWidget {
  final TouchPoint touchPoint;
  final Size screenSize;
  final VoidCallback? onFallComplete;
  final VoidCallback? onChosenAnimationComplete;
  final int remainingSeconds;
  final int totalSeconds;

  const FingerBlob({
    super.key,
    required this.touchPoint,
    required this.screenSize,
    this.onFallComplete,
    this.onChosenAnimationComplete,
    required this.remainingSeconds,
    required this.totalSeconds,
  });

  @override
  State<FingerBlob> createState() => _FingerBlobState();
}

class _FingerBlobState extends State<FingerBlob>
    with TickerProviderStateMixin {
  static const double baseSize = 150.0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late AnimationController _chosenController;
  late Animation<double> _scaleAnimation;

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

    // Fade animation - quick fade to black
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
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _chosenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _pulseController,
        _fadeController,
        _chosenController,
      ]),
      builder: (context, child) {
        double scale = _pulseAnimation.value;
        double opacity = 1.0;

        if (widget.touchPoint.state == TouchState.falling) {
          scale = 1.0;
          opacity = _fadeAnimation.value;
        } else if (widget.touchPoint.state == TouchState.chosen) {
          scale = _scaleAnimation.value;
        }

        return Positioned(
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
        );
      },
    );
  }
}
