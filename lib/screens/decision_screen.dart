import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../models/touch_point.dart';
import '../utils/color_palette.dart';
import '../widgets/finger_blob.dart';

enum GameState {
  waiting,
  countdown,
  selecting,
  complete,
}

class DecisionScreen extends StatefulWidget {
  const DecisionScreen({super.key});

  @override
  State<DecisionScreen> createState() => _DecisionScreenState();
}

class _DecisionScreenState extends State<DecisionScreen>
    with SingleTickerProviderStateMixin {
  static const int _countdownDuration = 10;

  final Map<int, TouchPoint> _touchPoints = {};
  late ColorPalette _colorPalette;
  GameState _gameState = GameState.waiting;
  Timer? _countdownTimer;
  int _remainingSeconds = _countdownDuration;
  int? _chosenPointerId;
  final Random _random = Random();

  // Use AudioPool for reliable repeated playback
  AudioPlayer? _tickPlayer;
  bool _audioReady = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _colorPalette = ColorPalette.generate();
    _initAudio();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.1, end: 0.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  Future<void> _initAudio() async {
    _tickPlayer = AudioPlayer();
    await _tickPlayer!.setSource(AssetSource('tick.mp3'));
    await _tickPlayer!.setReleaseMode(ReleaseMode.stop);
    _audioReady = true;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _tickPlayer?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _playTick() async {
    // Play tick sound
    if (_audioReady && _tickPlayer != null) {
      await _tickPlayer!.seek(Duration.zero);
      await _tickPlayer!.resume();
    }

    // 50ms vibration
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(duration: 50);
    }
  }

  void _addTouch(int pointerId, Offset position) {
    if (_gameState == GameState.selecting || _gameState == GameState.complete) {
      return;
    }

    setState(() {
      _touchPoints[pointerId] = TouchPoint(
        pointerId: pointerId,
        position: position,
        color: _colorPalette.getNextColor(),
      );
    });

    _resetCountdown();
  }

  void _updateTouch(int pointerId, Offset position) {
    if (_touchPoints.containsKey(pointerId) &&
        _touchPoints[pointerId]!.state == TouchState.active) {
      setState(() {
        _touchPoints[pointerId] = _touchPoints[pointerId]!.copyWith(position: position);
      });
    }
  }

  void _removeTouch(int pointerId) {
    if (_gameState == GameState.selecting || _gameState == GameState.complete) {
      return;
    }

    setState(() {
      _touchPoints.remove(pointerId);
    });

    _resetCountdown();
  }

  void _resetCountdown() {
    _countdownTimer?.cancel();

    if (_touchPoints.length >= 2) {
      setState(() {
        _gameState = GameState.countdown;
        _remainingSeconds = _countdownDuration;
      });

      _playTick();

      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _remainingSeconds--;
        });

        if (_remainingSeconds > 0) {
          _playTick();
        }

        if (_remainingSeconds <= 0) {
          timer.cancel();
          _triggerSelection();
        }
      });
    } else {
      setState(() {
        _gameState = GameState.waiting;
        _remainingSeconds = _countdownDuration;
      });
    }
  }

  void _triggerSelection() {
    if (_touchPoints.length < 2) {
      _resetCountdown();
      return;
    }

    // Haptic feedback
    HapticFeedback.heavyImpact();

    final pointerIds = _touchPoints.keys.toList();
    final chosenId = pointerIds[_random.nextInt(pointerIds.length)];

    setState(() {
      _gameState = GameState.selecting;
      _chosenPointerId = chosenId;

      // Mark non-chosen as falling - create new objects to trigger didUpdateWidget
      for (final id in _touchPoints.keys.toList()) {
        if (id != chosenId) {
          _touchPoints[id] = _touchPoints[id]!.copyWith(state: TouchState.falling);
        }
      }
    });

    // After losers fade (300ms), brief pause, then trigger winner animation
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted && _chosenPointerId != null && _touchPoints.containsKey(_chosenPointerId)) {
        setState(() {
          _touchPoints[_chosenPointerId!] = _touchPoints[_chosenPointerId!]!.copyWith(state: TouchState.chosen);
        });
      }
    });
  }

  void _onChosenAnimationComplete() {
    setState(() {
      _gameState = GameState.complete;
    });

    // Hold for 3-4 seconds then reset
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _resetGame();
      }
    });
  }

  void _resetGame() {
    setState(() {
      _touchPoints.clear();
      _colorPalette = ColorPalette.generate();
      _gameState = GameState.waiting;
      _remainingSeconds = _countdownDuration;
      _chosenPointerId = null;
    });
  }

  void _onFallComplete(int pointerId) {
    // Remove fallen touch points from the map
    setState(() {
      _touchPoints.remove(pointerId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final timerSize = min(screenSize.width, screenSize.height) * 0.75;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
        child: Listener(
          onPointerDown: (event) => _addTouch(event.pointer, event.localPosition),
          onPointerMove: (event) =>
              _updateTouch(event.pointer, event.localPosition),
          onPointerUp: (event) => _removeTouch(event.pointer),
          onPointerCancel: (event) => _removeTouch(event.pointer),
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              // Finger blobs
              ..._touchPoints.values.map((touchPoint) {
                return FingerBlob(
                  key: ValueKey(touchPoint.pointerId),
                  touchPoint: touchPoint,
                  screenSize: screenSize,
                  remainingSeconds: _remainingSeconds,
                  totalSeconds: _countdownDuration,
                  onFallComplete: () => _onFallComplete(touchPoint.pointerId),
                  onChosenAnimationComplete: touchPoint.pointerId == _chosenPointerId
                      ? _onChosenAnimationComplete
                      : null,
                );
              }),

              // Countdown indicator - centered, large, transparent, ignores touch
              if (_gameState == GameState.countdown || _gameState == GameState.waiting)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: _gameState == GameState.countdown
                          ? Opacity(
                              opacity: 0.3,
                              child: _buildCountdownIndicator(timerSize),
                            )
                          : _buildPulsingText(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildPulsingText() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _pulseAnimation.value,
          child: Text(
            'Place your fingers',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontFamily: 'SpecialGothicExpandedOne',
              fontWeight: FontWeight.w400,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCountdownIndicator(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: _remainingSeconds / _countdownDuration,
              strokeWidth: size * 0.05,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          Text(
            '$_remainingSeconds',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.4,
              fontFamily: 'SpecialGothicExpandedOne',
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
