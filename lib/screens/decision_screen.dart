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
    with TickerProviderStateMixin {
  static const int _countdownDuration = 10;
  static const int _tickSoundCount = 24;
  static const int _doneSoundCount = 26;

  final Map<int, TouchPoint> _touchPoints = {};
  late ColorPalette _colorPalette;
  late Color _uiColor;
  GameState _gameState = GameState.waiting;
  Timer? _countdownTimer;
  int _remainingSeconds = _countdownDuration;
  int? _chosenPointerId;
  bool _shouldFadeOut = false;
  final Random _random = Random();

  // Audio players for sounds
  AudioPlayer? _donePlayer;
  AudioPlayer? _preloadedTickPlayer;
  final List<AudioPlayer> _activeTickPlayers = [];
  bool _audioReady = false;
  int _currentTickSound = 1;
  int _currentDoneSound = 1;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _countdownProgressController;

  @override
  void initState() {
    super.initState();
    _colorPalette = ColorPalette.generate();
    _uiColor = UIColor.random();
    _initAudio();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    _countdownProgressController = AnimationController(
      duration: Duration(seconds: _countdownDuration),
      vsync: this,
    );
  }

  Future<void> _initAudio() async {
    _donePlayer = AudioPlayer();
    await _donePlayer!.setReleaseMode(ReleaseMode.stop);
  }

  Future<void> _prepareRoundSounds() async {
    _audioReady = false;

    // Dispose any leftover tick players
    for (final player in _activeTickPlayers) {
      player.dispose();
    }
    _activeTickPlayers.clear();
    _preloadedTickPlayer?.dispose();

    // Randomly select sounds for this round
    _currentTickSound = _random.nextInt(_tickSoundCount) + 1;
    _currentDoneSound = _random.nextInt(_doneSoundCount) + 1;

    // Create preloaded tick player for first tick
    _preloadedTickPlayer = AudioPlayer();

    // Preload both sounds in parallel
    await Future.wait([
      _preloadedTickPlayer!.setSource(AssetSource('tick_$_currentTickSound.mp3')),
      _donePlayer!.setSource(AssetSource('done_$_currentDoneSound.mp3')),
    ]);

    _audioReady = true;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (final player in _activeTickPlayers) {
      player.dispose();
    }
    _preloadedTickPlayer?.dispose();
    _donePlayer?.dispose();
    _pulseController.dispose();
    _countdownProgressController.dispose();
    super.dispose();
  }

  Future<void> _playTick() async {
    if (!_audioReady) return;

    AudioPlayer tickPlayer;

    // Use preloaded player for first tick (instant playback), create new for subsequent
    if (_preloadedTickPlayer != null) {
      tickPlayer = _preloadedTickPlayer!;
      _preloadedTickPlayer = null;
      tickPlayer.resume();
    } else {
      tickPlayer = AudioPlayer();
      tickPlayer.play(AssetSource('tick_$_currentTickSound.mp3'));
    }

    _activeTickPlayers.add(tickPlayer);

    // Set up auto-cleanup when sound finishes
    tickPlayer.onPlayerComplete.listen((_) {
      _activeTickPlayers.remove(tickPlayer);
      tickPlayer.dispose();
    });

    // 50ms vibration
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(duration: 50);
    }
  }

  Future<void> _playDone() async {
    // Play done sound
    if (_audioReady && _donePlayer != null) {
      await _donePlayer!.seek(Duration.zero);
      await _donePlayer!.resume();
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
      final isNewRound = _gameState == GameState.waiting;

      setState(() {
        _gameState = GameState.countdown;
        _remainingSeconds = _countdownDuration;
      });

      // Reset and start smooth progress animation
      _countdownProgressController.value = 1.0;
      _countdownProgressController.animateTo(0.0,
        duration: Duration(seconds: _countdownDuration),
        curve: Curves.linear,
      );

      if (isNewRound) {
        // Preload sounds for this round, then start countdown
        _prepareRoundSounds().then((_) {
          if (mounted && _gameState == GameState.countdown) {
            _playTick();
            _startCountdownTimer();
          }
        });
      } else {
        // Sounds already loaded, just restart countdown
        _playTick();
        _startCountdownTimer();
      }
    } else {
      _countdownProgressController.stop();
      _countdownProgressController.value = 1.0;
      setState(() {
        _gameState = GameState.waiting;
        _remainingSeconds = _countdownDuration;
      });
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
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
  }

  void _triggerSelection() {
    if (_touchPoints.length < 2) {
      _resetCountdown();
      return;
    }

    // Haptic feedback
    HapticFeedback.heavyImpact();

    // Play done sound
    _playDone();

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

    // Hold for 2 seconds, then trigger fade out
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _shouldFadeOut = true;
        });

        // Wait for fade out animation (800ms) then reset
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            _resetGame();
          }
        });
      }
    });
  }

  void _resetGame() {
    setState(() {
      _touchPoints.clear();
      _colorPalette = ColorPalette.generate();
      _uiColor = UIColor.random();
      _gameState = GameState.waiting;
      _remainingSeconds = _countdownDuration;
      _chosenPointerId = null;
      _shouldFadeOut = false;
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
                  shouldFadeOut: _shouldFadeOut && touchPoint.pointerId == _chosenPointerId,
                );
              }),

              // Countdown indicator - centered, large, ignores touch
              if (_gameState == GameState.countdown || _gameState == GameState.waiting)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: _gameState == GameState.countdown
                          ? _buildCountdownIndicator(timerSize)
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
            'Waiting for everyone to touch',
            style: TextStyle(
              color: _uiColor,
              fontSize: 24,
              fontFamily: 'MarkPro',
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCountdownIndicator(double size) {
    return AnimatedBuilder(
      animation: _countdownProgressController,
      builder: (context, child) {
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
                  value: _countdownProgressController.value,
                  strokeWidth: size * 0.05,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(_uiColor),
                ),
              ),
              Text(
                '$_remainingSeconds',
                style: TextStyle(
                  color: _uiColor,
                  fontSize: size * 0.4,
                  fontFamily: 'MarkPro',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
