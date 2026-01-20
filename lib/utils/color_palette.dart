import 'dart:math';
import 'package:flutter/material.dart';

class ColorPalette {
  final List<Color> colors;
  int _nextIndex = 0;

  ColorPalette._(this.colors);

  factory ColorPalette.generate({int count = 10, int? seed}) {
    final random = seed != null ? Random(seed) : Random();
    final colors = <Color>[];

    for (int i = 0; i < count; i++) {
      colors.add(_generateNeonColor(random));
    }

    return ColorPalette._(colors);
  }

  static Color _generateNeonColor(Random random) {
    // Use HSL color space with high saturation (80-100%) and medium-high lightness (50-70%)
    final hue = random.nextDouble() * 360;
    final saturation = 0.8 + random.nextDouble() * 0.2; // 80-100%
    final lightness = 0.5 + random.nextDouble() * 0.2; // 50-70%

    return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
  }

  Color getNextColor() {
    final color = colors[_nextIndex % colors.length];
    _nextIndex++;
    return color;
  }

  void reset() {
    _nextIndex = 0;
  }
}

class UIColor {
  static final List<Color> _colors = [
    Color(0xFF5B23FF), // Purple/Blue
    Color(0xFF008BFF), // Blue
    Color(0xFFE4FF30), // Yellow/Lime
    Color(0xFF9929EA), // Purple
    Color(0xFFFF0087), // Pink/Magenta
    Color(0xFF48B3AF), // Teal
    Color(0xFFF93827), // Red
    Color(0xFFFF9D23), // Orange
  ];

  static Color random() {
    final random = Random();
    return _colors[random.nextInt(_colors.length)];
  }
}
