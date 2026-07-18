import 'package:flutter/material.dart';

/// Quiet Current palette.
///
/// The legacy names remain as compatibility aliases while older feature
/// widgets are migrated. Their values now carry the calm semantic roles below.
abstract final class FlowColor {
  static const ink = Color(0xFF121614);
  static const inkRaised = Color(0xFF191E1B);
  static const inkPlane = Color(0xFF222824);
  static const paper = Color(0xFFF6F5F0);
  static const paperRaised = Color(0xFFFCFBF8);
  static const paperPlane = Color(0xFFECEBE5);

  static const current = Color(0xFF476F86);
  static const currentDark = Color(0xFF81A9BC);
  static const moss = Color(0xFF4F765F);
  static const mossDark = Color(0xFF82AC90);
  static const clay = Color(0xFFA4604D);
  static const clayDark = Color(0xFFD39480);
  static const ochre = Color(0xFFA47C3B);
  static const ochreDark = Color(0xFFD2AA68);

  // Transitional semantic aliases. They intentionally no longer use neon.
  static const loom = current;
  static const loomBright = currentDark;
  static const proof = current;
  static const mint = moss;
  static const coral = clay;
  static const amber = ochre;

  static bool _dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color canvas(BuildContext context) => _dark(context) ? ink : paper;
  static Color raised(BuildContext context) =>
      _dark(context) ? inkRaised : paperRaised;
  static Color plane(BuildContext context) =>
      _dark(context) ? inkPlane : paperPlane;
  static Color content(BuildContext context) =>
      _dark(context) ? const Color(0xFFEEF1EC) : const Color(0xFF202522);
  static Color quiet(BuildContext context) =>
      _dark(context) ? const Color(0xFFA8B0AA) : const Color(0xFF68706B);
  static Color rule(BuildContext context) =>
      _dark(context) ? const Color(0xFF343B36) : const Color(0xFFDCDDD7);
  static Color intelligence(BuildContext context) =>
      _dark(context) ? currentDark : current;
  static Color income(BuildContext context) => _dark(context) ? mossDark : moss;
  static Color expense(BuildContext context) =>
      _dark(context) ? clayDark : clay;
  static Color review(BuildContext context) =>
      _dark(context) ? ochreDark : ochre;
}
