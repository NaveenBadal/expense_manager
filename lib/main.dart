import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/dashboard_screen.dart';
import 'providers/expense_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: ExpenseManagerApp(),
    ),
  );
}

class ExpenseManagerApp extends ConsumerWidget {
  const ExpenseManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trigger settings initialization
    ref.watch(settingsInitializer);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Expense Manager',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: FlexThemeData.light(
        scheme: FlexScheme.materialBaseline,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 7,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 10,
          blendOnColors: false,
          useMaterial3Typography: true,
          useM2StyleDividerInM3: true,
          alignedDropdown: true,
          useInputDecoratorThemeInDialogs: true,
          cardRadius: 28,
          defaultRadius: 20,
          inputDecoratorRadius: 20,
          chipRadius: 999,
          fabUseShape: true,
          fabRadius: 20,
          navigationBarHeight: 72,
        ),
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
        useMaterial3: true,
        fontFamily: GoogleFonts.notoSans().fontFamily,
      ),
      darkTheme: FlexThemeData.dark(
        scheme: FlexScheme.materialBaseline,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 13,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 20,
          useMaterial3Typography: true,
          useM2StyleDividerInM3: true,
          alignedDropdown: true,
          useInputDecoratorThemeInDialogs: true,
          cardRadius: 28,
          defaultRadius: 20,
          inputDecoratorRadius: 20,
          chipRadius: 999,
          fabUseShape: true,
          fabRadius: 20,
          navigationBarHeight: 72,
        ),
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
        useMaterial3: true,
        fontFamily: GoogleFonts.notoSans().fontFamily,
      ),
      home: const DashboardScreen(),
    );
  }
}
