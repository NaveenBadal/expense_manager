import 'package:flutter/widgets.dart';

abstract final class FlowGeometry {
  static const grid = 4.0;
  static const page = 20.0;
  static const readingMax = 620.0;
  static const evidenceMax = 760.0;
  static const commandRailHeight = 76.0;
  static const controlRadius = 16.0;
  static const planeRadius = 24.0;
  static const ledgerCut = 12.0;

  static EdgeInsets contentInsets(double width, {double max = readingMax}) =>
      EdgeInsets.symmetric(
        horizontal: width > max + 40 ? (width - max) / 2 : page,
      );
}
