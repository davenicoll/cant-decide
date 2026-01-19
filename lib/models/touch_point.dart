import 'dart:ui';

enum TouchState {
  active,
  falling,
  chosen,
}

class TouchPoint {
  final int pointerId;
  Offset position;
  final Color color;
  TouchState state;

  TouchPoint({
    required this.pointerId,
    required this.position,
    required this.color,
    this.state = TouchState.active,
  });

  TouchPoint copyWith({
    int? pointerId,
    Offset? position,
    Color? color,
    TouchState? state,
  }) {
    return TouchPoint(
      pointerId: pointerId ?? this.pointerId,
      position: position ?? this.position,
      color: color ?? this.color,
      state: state ?? this.state,
    );
  }
}
