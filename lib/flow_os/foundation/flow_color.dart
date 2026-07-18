import 'package:flutter/material.dart';

/// Stable proprietary palette for Flow Loom. Material color generation must
/// not redefine these roles.
abstract final class FlowColor {
  static const ink = Color(0xFF090A0F);
  static const inkRaised = Color(0xFF12141C);
  static const inkPlane = Color(0xFF1A1D27);
  static const paper = Color(0xFFF7F7F2);
  static const paperRaised = Color(0xFFFFFFFF);
  static const paperPlane = Color(0xFFECECF3);

  static const loom = Color(0xFF5B4BFF);
  static const loomBright = Color(0xFF8C82FF);
  static const proof = Color(0xFF22D3EE);
  static const mint = Color(0xFF2ED3A7);
  static const coral = Color(0xFFFF5F7A);
  static const amber = Color(0xFFF6B94A);

  static Color canvas(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? ink : paper;

  static Color raised(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? inkRaised : paperRaised;

  static Color plane(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? inkPlane : paperPlane;

  static Color content(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFF0EEF8)
      : const Color(0xFF171821);

  static Color quiet(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFAAA8B8)
      : const Color(0xFF5D5D69);

  static Color rule(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF303340)
      : const Color(0xFFD3D2DC);
}
