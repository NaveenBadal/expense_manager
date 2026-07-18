import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../flow_os/foundation/flow_color.dart';
import 'app_tokens.dart';

/// Platform integration for Flow Loom. Product surfaces use `flow_os`
/// primitives directly; this theme only governs unavoidable Flutter/platform
/// controls and deliberately avoids Material component styling as identity.
class AppTheme {
  const AppTheme._();
  static const _tabular = [FontFeature.tabularFigures()];

  static ThemeData light(ColorScheme? _) => _build(Brightness.light);
  static ThemeData dark(ColorScheme? _) => _build(Brightness.dark);
  static ThemeData highContrastLight(ColorScheme? _) =>
      _build(Brightness.light, highContrast: true);
  static ThemeData highContrastDark(ColorScheme? _) =>
      _build(Brightness.dark, highContrast: true);

  static ThemeData _build(Brightness brightness, {bool highContrast = false}) {
    final dark = brightness == Brightness.dark;
    final canvas = dark ? FlowColor.ink : FlowColor.paper;
    final raised = dark ? FlowColor.inkRaised : FlowColor.paperRaised;
    final plane = dark ? FlowColor.inkPlane : FlowColor.paperPlane;
    final content = dark ? const Color(0xFFF0EEF8) : const Color(0xFF171821);
    final quiet = dark ? const Color(0xFFAAA8B8) : const Color(0xFF5D5D69);
    final rule = dark ? const Color(0xFF303340) : const Color(0xFFD3D2DC);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: FlowColor.loom,
      onPrimary: Colors.white,
      secondary: FlowColor.proof,
      onSecondary: FlowColor.ink,
      error: FlowColor.coral,
      onError: Colors.white,
      surface: canvas,
      onSurface: content,
      surfaceContainerLowest: canvas,
      surfaceContainerLow: raised,
      surfaceContainer: raised,
      surfaceContainerHigh: plane,
      surfaceContainerHighest: plane,
      onSurfaceVariant: quiet,
      outline: highContrast ? content : quiet,
      outlineVariant: highContrast ? quiet : rule,
      inverseSurface: content,
      onInverseSurface: canvas,
      inversePrimary: FlowColor.loomBright,
      shadow: Colors.black,
      scrim: Colors.black,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      fontFamily: 'Inter',
      visualDensity: VisualDensity.standard,
      splashFactory: NoSplash.splashFactory,
    );
    final raw = base.textTheme.apply(bodyColor: content, displayColor: content);
    TextStyle? display(TextStyle? style, FontWeight weight, double tracking) =>
        style?.copyWith(
          fontFamily: 'Space Grotesk',
          fontWeight: weight,
          letterSpacing: tracking,
          height: 1.04,
        );
    const cut8 = BeveledRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    );
    const cut12 = BeveledRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    );
    return base.copyWith(
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
      textTheme: raw.copyWith(
        displayLarge: display(raw.displayLarge, FontWeight.w700, -1.5),
        displayMedium: display(raw.displayMedium, FontWeight.w700, -1.2),
        displaySmall: display(raw.displaySmall, FontWeight.w700, -1),
        headlineLarge: display(raw.headlineLarge, FontWeight.w700, -.8),
        headlineMedium: display(raw.headlineMedium, FontWeight.w700, -.6),
        headlineSmall: display(raw.headlineSmall, FontWeight.w700, -.4),
        titleLarge: display(raw.titleLarge, FontWeight.w700, -.2),
        titleMedium: raw.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        titleSmall: raw.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        bodyLarge: raw.bodyLarge?.copyWith(height: 1.45),
        bodyMedium: raw.bodyMedium?.copyWith(height: 1.45),
        labelLarge: raw.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: .3,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: content,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: plane,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: rule),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: FlowColor.proof, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: FlowColor.coral),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: cut8,
        ),
      ),
      dividerTheme: DividerThemeData(color: rule, thickness: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: FlowColor.proof,
        linearTrackColor: Colors.transparent,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 3,
        borderRadius: BorderRadius.zero,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: raised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: cut8,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const ShapeDecoration(
          color: FlowColor.inkPlane,
          shape: cut8,
        ),
        textStyle: const TextStyle(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        preferBelow: false,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: raised,
        surfaceTintColor: Colors.transparent,
        shape: cut12,
        headerBackgroundColor: FlowColor.loom,
        headerForegroundColor: Colors.white,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: raised,
        shape: cut12,
        hourMinuteShape: cut8,
        dayPeriodShape: cut8,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: content,
        contentTextStyle: TextStyle(color: canvas, fontWeight: FontWeight.w700),
        shape: cut8,
        insetPadding: const EdgeInsets.all(16),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: const BeveledRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: raised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: cut12,
      ),
      extensions: [dark ? FinanceColors.dark : FinanceColors.light],
    );
  }

  static TextStyle money(TextStyle? base) => (base ?? const TextStyle())
      .copyWith(fontFeatures: _tabular, fontWeight: FontWeight.w700);
}
