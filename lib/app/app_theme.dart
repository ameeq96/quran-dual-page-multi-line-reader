import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppTheme {
  static ThemeData light({
    bool highContrast = false,
    bool largerText = false,
  }) {
    return _theme(
      seed: const Color(0xFF163F35),
      brightness: Brightness.light,
      scaffoldColor: const Color(0xFFF7F3EA),
      surfaceColor: const Color(0xFFFFFCF6),
      dividerColor: const Color(0xFFE2DCCF),
      highContrast: highContrast,
      largerText: largerText,
    );
  }

  static ThemeData dark({
    bool highContrast = false,
    bool largerText = false,
  }) {
    return _theme(
      seed: const Color(0xFFC4D8BA),
      brightness: Brightness.dark,
      scaffoldColor: const Color(0xFF10231D),
      surfaceColor: const Color(0xFF19342A),
      dividerColor: const Color(0xFF3D5143),
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
    final isDark = brightness == Brightness.dark;
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: brightness,
          surface: surfaceColor,
        ).copyWith(
          primary: seed,
          secondary: isDark ? const Color(0xFFD8BD82) : const Color(0xFF8A6933),
          onSecondary: isDark ? const Color(0xFF33280F) : Colors.white,
          secondaryContainer: isDark
              ? const Color(0xFF51452B)
              : const Color(0xFFF0E2BE),
          onSecondaryContainer: isDark
              ? const Color(0xFFF4E5BC)
              : const Color(0xFF5A421F),
          onPrimary: isDark ? const Color(0xFF173D30) : Colors.white,
          primaryContainer: isDark
              ? const Color(0xFF284A39)
              : const Color(0xFFE8ECDD),
          onPrimaryContainer: isDark
              ? const Color(0xFFE4EBD4)
              : const Color(0xFF294938),
          onSurface: isDark ? const Color(0xFFF3EDDB) : const Color(0xFF243C32),
          onSurfaceVariant: isDark
              ? const Color(0xFFB8C1AD)
              : const Color(0xFF6F7567),
          surfaceContainerLowest: isDark
              ? const Color(0xFF0D1D17)
              : Colors.white,
          surfaceContainerLow: isDark
              ? const Color(0xFF1D392D)
              : const Color(0xFFF3F0E5),
          surfaceContainer: isDark
              ? const Color(0xFF243F31)
              : const Color(0xFFEDEDDD),
          surfaceContainerHigh: isDark
              ? const Color(0xFF2D4736)
              : const Color(0xFFE8E8D7),
          surfaceContainerHighest: isDark
              ? const Color(0xFF354F3E)
              : const Color(0xFFE0E3D2),
          outline: isDark ? const Color(0xFF91A38A) : const Color(0xFF8D927C),
          outlineVariant: dividerColor,
        );
    final scale = largerText ? 1.08 : 1.0;
    final effectiveDivider = highContrast
        ? (isDark ? const Color(0xFFB3A68A) : const Color(0xFF837659))
        : dividerColor;

    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldColor,
      dividerColor: effectiveDivider,
      splashFactory: InkRipple.splashFactory,
    );

    final textTheme = baseTheme.textTheme.copyWith(
      headlineLarge: baseTheme.textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: -0.8,
        height: 1.12,
        fontSize: 34 * scale,
      ),
      headlineMedium: baseTheme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: -0.7,
        height: 1.18,
        fontSize: 29 * scale,
      ),
      headlineSmall: baseTheme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.65,
        fontSize: (baseTheme.textTheme.headlineSmall?.fontSize ?? 24) * scale,
      ),
      titleLarge: baseTheme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.45,
        fontSize: (baseTheme.textTheme.titleLarge?.fontSize ?? 22) * scale,
      ),
      titleMedium: baseTheme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
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
      bodySmall: baseTheme.textTheme.bodySmall?.copyWith(
        height: 1.45,
        fontSize: (baseTheme.textTheme.bodySmall?.fontSize ?? 12) * scale,
      ),
      labelLarge: baseTheme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        fontSize: (baseTheme.textTheme.labelLarge?.fontSize ?? 14) * scale,
      ),
      labelMedium: baseTheme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: (baseTheme.textTheme.labelMedium?.fontSize ?? 12) * scale,
      ),
    );

    final fieldFillColor = colorScheme.surfaceContainerLow;

    return baseTheme.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        systemOverlayStyle: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark),
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actionsIconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: effectiveDivider.withValues(alpha: isDark ? 0.42 : 0.68),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: effectiveDivider.withValues(alpha: isDark ? 0.44 : 0.72),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        modalBackgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: effectiveDivider.withValues(alpha: 0.9),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          backgroundColor: Colors.transparent,
          fixedSize: const Size(46, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          foregroundColor: colorScheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: effectiveDivider.withValues(alpha: 0.72)),
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
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: effectiveDivider.withValues(alpha: 0.58)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: effectiveDivider.withValues(alpha: 0.58)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.72),
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
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: effectiveDivider.withValues(alpha: 0.48),
          ),
        ),
        textStyle: textTheme.bodyMedium,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 76,
        indicatorColor: colorScheme.primary,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected)
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
          );
        }),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
      ),
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
          return effectiveDivider.withValues(alpha: 0.62);
        }),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        backgroundColor: fieldFillColor,
        disabledColor: fieldFillColor.withValues(alpha: 0.72),
        selectedColor: colorScheme.primary.withValues(alpha: 0.14),
        side: BorderSide(
          color: effectiveDivider.withValues(alpha: 0.6),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        labelStyle: textTheme.labelMedium,
      ),
      sliderTheme: baseTheme.sliderTheme.copyWith(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: effectiveDivider.withValues(alpha: 0.52),
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
      dividerTheme: DividerThemeData(
        color: effectiveDivider.withValues(alpha: isDark ? 0.52 : 0.68),
        thickness: 1,
        space: 1,
      ),
    );
  }
}
