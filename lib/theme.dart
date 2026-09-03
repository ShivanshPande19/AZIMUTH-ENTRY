import 'package:flutter/material.dart';

/// Centralised, modern Material 3 theme for the whole app.
///
/// Goals: soft rounded surfaces with gentle depth, calm indigo brand colour,
/// comfortable spacing and legible typography — a clean, current look that
/// works in both light and dark mode.
class AppTheme {
  AppTheme._();

  // ---- Brand colour system --------------------------------------------------
  /// Primary (dominant): deep navy — trust, authority, professionalism.
  /// Used for headers, brand surfaces and section accents.
  static const Color primaryNavy = Color(0xFF1E3A8A);

  /// Secondary (action): bright royal blue — primary buttons, active states.
  static const Color actionBlue = Color(0xFF2563EB);

  /// Success (check-in / "Inside now").
  static const Color success = Color(0xFF10B981);

  /// Warning / alert (pending, flagged).
  static const Color warning = Color(0xFFF59E0B);

  /// Error / danger (blacklisted, unauthorized).
  static const Color danger = Color(0xFFEF4444);

  /// Light-mode background — soft slate-tinted off-white.
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color darkBg = Color(0xFF0F1115);

  /// Kept for older references. `seed` drives the ColorScheme.
  static const Color seed = primaryNavy;
  static const Color accent = actionBlue;

  static const double radius = 18;
  static const double fieldRadius = 14;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryNavy,
      brightness: brightness,
      // Actions use the bright royal blue; navy stays for headers/accents.
      primary: isDark ? null : actionBlue,
      secondary: actionBlue,
      error: danger,
    ).copyWith(
      error: danger,
    );

    final baseText = ThemeData(brightness: brightness).textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? darkBg : lightBg,
      splashFactory: InkSparkle.splashFactory,

      textTheme: baseText.copyWith(
        headlineSmall: baseText.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? darkBg : lightBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),

      cardTheme: CardThemeData(
        // A touch of elevation in light mode gives the cards gentle depth
        // (less flat / dull); dark mode relies on a hairline border instead.
        elevation: isDark ? 0 : 1.5,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: primaryNavy.withValues(alpha: 0.16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.4 : 0.5),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.4)
            : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        prefixIconColor: scheme.onSurfaceVariant,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: scheme.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: scheme.error, width: 1.8),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Min HEIGHT of 52 for a comfortable tap target, but a finite min
          // width (0). Using Size.fromHeight here forces an infinite min width,
          // which crashes when a FilledButton sits inside a Row. Full-width
          // primary buttons still stretch via their parent Column.
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(fieldRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(fieldRadius),
          ),
          side: BorderSide(color: scheme.outline),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(fieldRadius),
            ),
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
        ),
      ),

      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        elevation: 3,
        height: 68,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.6),
        thickness: 1,
      ),
    );
  }

  /// Brand gradient for hero / header areas: deep navy into royal blue.
  static LinearGradient brandGradient(Brightness brightness) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryNavy, actionBlue],
    );
  }
}

/// Deterministic soft avatar colour from a name/string.
Color avatarColor(String seedStr, ColorScheme scheme) {
  const palette = [
    Color(0xFF1E3A8A), // navy
    Color(0xFF2563EB), // royal blue
    Color(0xFF0EA5E9), // sky
    Color(0xFF0D9488), // teal
    Color(0xFF10B981), // emerald
    Color(0xFF64748B), // slate
  ];
  if (seedStr.isEmpty) return scheme.primary;
  final idx = seedStr.codeUnits.fold<int>(0, (a, b) => a + b) % palette.length;
  return palette[idx];
}

/// First one or two initials from a name.
String initialsOf(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}
