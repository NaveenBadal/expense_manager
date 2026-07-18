import 'package:flutter/animation.dart';

abstract final class FlowMotion {
  static const quick = Duration(milliseconds: 160);
  static const spatial = Duration(milliseconds: 240);
  static const settle = Duration(milliseconds: 320);
  static const curve = Cubic(.2, .72, .18, 1);
}
