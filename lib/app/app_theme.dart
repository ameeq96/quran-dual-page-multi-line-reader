import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData light({
    bool highContrast = false,
    bool largerText = false,
  }) {
    return _theme(
      seed: const Color(0xFF1B6B5D),
      brightness: Brightness.light,
      scaffoldColor: const Color(0xFFF0E7D5),
      surfaceColor: const Color(0xFFFCF8F0),
      dividerColor: const Color(0xFFD8CBB5),
      highContrast: highContrast,
      largerText: largerText,
    );
  }

  static ThemeData dark({
    bool highContrast = false,
    bool largerText = false,
  }) {
    return _theme(
      seed: const Color(0xFF73C4B0),
      brightness: Brightness.dark,
      scaffoldColor: const Color(0xFF101311),
      surfaceColor: const Color(0xFF171B18),
      dividerColor: const Color(0xFF3A413C),
      highContrast: highContrast,
      largerText: largerText,
    );
  }

  static ThemeData _theme({
    required Color seed,
    required Brightness brightness,
    required Color scaffoldColor,
    required Color surfaceColor,
    required Color dividerColor,
    required bool highContrast,
    required bool largerText,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      surface: surfaceColor,
    );
    final isDark = brightness == Brightness.dark;
    final scale = largerText ? 1.08 : 1.0;
    final effectiveDivider = highContrast
        ? (isDark ? const Color(0xFF64726A) : const Color(0xFFB0956F))
        : dividerColor;

    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldColor,
      dividerColor: effectiveDivider,
      splashFactory: InkSparkle.splashFactory,
    );

    final textTheme = baseTheme.textTheme.copyWith(
      headlineSmall: baseTheme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.55,
        fontSize: (baseTheme.textTheme.headlineSmall?.fontSize ?? 24) * scale,
      ),
      titleLarge: baseTheme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.35,
        fontSize: (baseTheme.textTheme.titleLarge?.fontSize ?? 22) * scale,
      ),
      titleMedium: baseTheme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.15,
        fontSize: (baseTheme.textTheme.titleMedium?.fontSize ?? 16) * scale,
      ),
      titleSmall: baseTheme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: (baseTheme.textTheme.titleSmall?.fontSize ?? 14) * scale,
      ),
      bodyLarge: baseTheme.textTheme.bodyLarge?.copyWith(
        height: 1.38,
        fontSize: (baseTheme.textTheme.bodyLarge?.fontSize ?? 16) * scale,
      ),
      bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(
        height: 1.36,
        fontSize: (baseTheme.textTheme.bodyMedium?.fontSize ?? 14) * scale,
      ),
      labelLarge: baseTheme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.15,
        fontSize: (baseTheme.textTheme.labelLarge?.fontSize ?? 14) * scale,
      ),
      labelMedium: baseTheme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: (baseTheme.textTheme.labelMedium?.fontSize ?? 12) * scale,
      ),
    );

    final fieldFillColor = isDark
        ? colorScheme.surfaceContainerHighest.withOpacity(0.42)
        : Colors.white.withOpacity(0.74);

    return baseTheme.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actionsIconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w900,
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(
            color: effectiveDivider.withOpacity(isDark ? 0.42 : 0.68),
          ),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colorScheme.surface.withOpacity(isDark ? 0.9 : 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(
            color: effectiveDivider.withOpacity(isDark ? 0.44 : 0.72),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        modalBackgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: effectiveDivider.withOpacity(0.9),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          backgroundColor: Colors.transparent,
          fixedSize: const Size(46, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          foregroundColor: colorScheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          side: BorderSide(color: effectiveDivider.withOpacity(0.72)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFillColor,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        prefixIconColor: colorScheme.primary,
        suffixIconColor: colorScheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: effectiveDivider.withOpacity(0.58)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: effectiveDivider.withOpacity(0.58)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: colorScheme.primary.withOpacity(0.72),
            width: 1.5,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 4,
        ),
        iconColor: colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: effectiveDivider.withOpacity(0.48),
          ),
        ),
        textStyle: textTheme.bodyMedium,
      ),
      tabBarTheme: const TabBarTheme(dividerColor: Colors.transparent),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return colorScheme.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return effectiveDivider.withOpacity(0.62);
        }),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        backgroundColor: fieldFillColor,
        disabledColor: fieldFillColor.withOpacity(0.72),
        selectedColor: colorScheme.primary.withOpacity(0.14),
        side: BorderSide(
          color: effectiveDivider.withOpacity(0.6),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: textTheme.labelMedium,
      ),
      sliderTheme: baseTheme.sliderTheme.copyWith(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: effectiveDivider.withOpacity(0.52),
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withOpacity(0.12),
        trackHeight: 4,
      ),
      dividerTheme: DividerThemeData(
        color: effectiveDivider.withOpacity(isDark ? 0.52 : 0.68),
        thickness: 1,
        space: 1,
      ),
    );
  }
}
