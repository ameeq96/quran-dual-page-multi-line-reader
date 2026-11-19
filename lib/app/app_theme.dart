import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Brand decoration tokens that Material's [ColorScheme] has no slot for:
/// the emerald hero gradient, the gold accent and the soft shadow ramp.
@immutable
class AppDecor extends ThemeExtension<AppDecor> {
  const AppDecor({
    required this.heroStart,
    required this.heroEnd,
    required this.onHero,
    required this.gold,
    required this.onGold,
    required this.cardShadow,
    required this.floatShadow,
    required this.accents,
  });

  /// Top-left colour of the emerald hero surface.
  final Color heroStart;

  /// Bottom-right colour of the emerald hero surface.
  final Color heroEnd;

  /// Text and icons placed on the hero surface.
  final Color onHero;

  /// Gold accent used for fills on dark emerald.
  final Color gold;

  /// Text and icons placed on a gold fill.
  final Color onGold;

  /// Resting elevation for cards.
  final List<BoxShadow> cardShadow;

  /// Raised elevation for hero surfaces and floating bars.
  final List<BoxShadow> floatShadow;

  /// Foreground/background pairs for feature icon badges.
  final List<AppAccent> accents;

  LinearGradient get heroGradient => LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [heroStart, heroEnd],
  );

  AppAccent accentAt(int index) => accents[index % accents.length];

  static AppDecor of(BuildContext context) =>
      Theme.of(context).extension<AppDecor>() ?? _fallback;

  static const AppDecor _fallback = AppDecor(
    heroStart: Color(0xFF14604C),
    heroEnd: Color(0xFF0A3329),
    onHero: Color(0xFFF8F1DE),
    gold: Color(0xFFE6C580),
    onGold: Color(0xFF10382D),
    cardShadow: [],
    floatShadow: [],
    accents: [AppAccent(Color(0xFF0E4A3B), Color(0xFFDCEBE2))],
  );

  @override
  AppDecor copyWith({
    Color? heroStart,
    Color? heroEnd,
    Color? onHero,
    Color? gold,
    Color? onGold,
    List<BoxShadow>? cardShadow,
    List<BoxShadow>? floatShadow,
    List<AppAccent>? accents,
  }) {
    return AppDecor(
      heroStart: heroStart ?? this.heroStart,
      heroEnd: heroEnd ?? this.heroEnd,
      onHero: onHero ?? this.onHero,
      gold: gold ?? this.gold,
      onGold: onGold ?? this.onGold,
      cardShadow: cardShadow ?? this.cardShadow,
      floatShadow: floatShadow ?? this.floatShadow,
      accents: accents ?? this.accents,
    );
  }

  @override
  AppDecor lerp(ThemeExtension<AppDecor>? other, double t) {
    if (other is! AppDecor) {
      return this;
    }
    return AppDecor(
      heroStart: Color.lerp(heroStart, other.heroStart, t) ?? heroStart,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t) ?? heroEnd,
      onHero: Color.lerp(onHero, other.onHero, t) ?? onHero,
      gold: Color.lerp(gold, other.gold, t) ?? gold,
      onGold: Color.lerp(onGold, other.onGold, t) ?? onGold,
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
      floatShadow: t < 0.5 ? floatShadow : other.floatShadow,
      accents: t < 0.5 ? accents : other.accents,
    );
  }
}

@immutable
class AppAccent {
  const AppAccent(this.foreground, this.background);
  final Color foreground;
  final Color background;
}

/// Shared corner radii so every surface rounds on the same scale.
abstract final class AppRadii {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
}

abstract final class AppTheme {
  /// Geometric display face for headlines and titles.
  static const String displayFontFamily = 'Outfit';

  /// Humanist text face for body copy and labels.
  static const String bodyFontFamily = 'WorkSans';

  static ThemeData light({
    bool highContrast = false,
    bool largerText = false,
  }) {
    return _theme(
      seed: const Color(0xFF0E4A3B),
      brightness: Brightness.light,
      scaffoldColor: const Color(0xFFF7F4EB),
      surfaceColor: const Color(0xFFFFFDF8),
      dividerColor: const Color(0xFFE7E1D3),
      highContrast: highContrast,
      largerText: largerText,
    );
  }

  static ThemeData dark({
    bool highContrast = false,
    bool largerText = false,
  }) {
    return _theme(
      seed: const Color(0xFF8ED3B5),
      brightness: Brightness.dark,
      scaffoldColor: const Color(0xFF0B1512),
      surfaceColor: const Color(0xFF13221D),
      dividerColor: const Color(0xFF2A3D35),
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
          onPrimary: isDark ? const Color(0xFF05291F) : Colors.white,
          primaryContainer: isDark
              ? const Color(0xFF1C4B3D)
              : const Color(0xFFDCEBE2),
          onPrimaryContainer: isDark
              ? const Color(0xFFCDEBDD)
              : const Color(0xFF0E3B30),
          secondary: isDark ? const Color(0xFFE3C27A) : const Color(0xFF8A6427),
          onSecondary: isDark ? const Color(0xFF3A2B08) : Colors.white,
          secondaryContainer: isDark
              ? const Color(0xFF4A3C1C)
              : const Color(0xFFF4E6C3),
          onSecondaryContainer: isDark
              ? const Color(0xFFF6E6BC)
              : const Color(0xFF553D12),
          tertiary: isDark ? const Color(0xFF8CCFDC) : const Color(0xFF2B6877),
          onTertiary: isDark ? const Color(0xFF06323B) : Colors.white,
          tertiaryContainer: isDark
              ? const Color(0xFF1D4852)
              : const Color(0xFFD8ECEF),
          onTertiaryContainer: isDark
              ? const Color(0xFFCDEEF4)
              : const Color(0xFF10414C),
          onSurface: isDark ? const Color(0xFFEFEADB) : const Color(0xFF1B2F28),
          onSurfaceVariant: isDark
              ? const Color(0xFFAEB9AD)
              : const Color(0xFF5C685F),
          surfaceContainerLowest: isDark
              ? const Color(0xFF08100E)
              : Colors.white,
          surfaceContainerLow: isDark
              ? const Color(0xFF172822)
              : const Color(0xFFF4F0E5),
          surfaceContainer: isDark
              ? const Color(0xFF1B2E27)
              : const Color(0xFFEEEADD),
          surfaceContainerHigh: isDark
              ? const Color(0xFF21372F)
              : const Color(0xFFE9E5D6),
          surfaceContainerHighest: isDark
              ? const Color(0xFF284038)
              : const Color(0xFFE2DECE),
          outline: isDark ? const Color(0xFF869A8D) : const Color(0xFF7F8777),
          outlineVariant: dividerColor,
          shadow: isDark ? Colors.black : const Color(0xFF16332A),
        );
    final scale = largerText ? 1.08 : 1.0;
    final effectiveDivider = highContrast
        ? (isDark ? const Color(0xFFB3A68A) : const Color(0xFF837659))
        : dividerColor;

    final decor = AppDecor(
      heroStart: isDark ? const Color(0xFF17574A) : const Color(0xFF14604C),
      heroEnd: isDark ? const Color(0xFF0C2A23) : const Color(0xFF0A3329),
      onHero: const Color(0xFFF8F1DE),
      gold: const Color(0xFFE6C580),
      onGold: const Color(0xFF10382D),
      cardShadow: highContrast
          ? const <BoxShadow>[]
          : <BoxShadow>[
              BoxShadow(
                color: colorScheme.shadow.withValues(
                  alpha: isDark ? 0.28 : 0.05,
                ),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: colorScheme.shadow.withValues(
                  alpha: isDark ? 0.18 : 0.03,
                ),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
      floatShadow: <BoxShadow>[
        BoxShadow(
          color: colorScheme.shadow.withValues(alpha: isDark ? 0.45 : 0.16),
          blurRadius: 30,
          offset: const Offset(0, 14),
        ),
        BoxShadow(
          color: colorScheme.shadow.withValues(alpha: isDark ? 0.25 : 0.06),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
      accents: isDark
          ? const [
              AppAccent(Color(0xFF8ED3B5), Color(0xFF1C4B3D)),
              AppAccent(Color(0xFFE3C27A), Color(0xFF4A3C1C)),
              AppAccent(Color(0xFF8CCFDC), Color(0xFF1D4852)),
              AppAccent(Color(0xFFF0B49A), Color(0xFF55301F)),
              AppAccent(Color(0xFFC3B9F0), Color(0xFF39305F)),
            ]
          : const [
              AppAccent(Color(0xFF0E4A3B), Color(0xFFDCEBE2)),
              AppAccent(Color(0xFF7A5516), Color(0xFFF4E6C3)),
              AppAccent(Color(0xFF1F5C6B), Color(0xFFD8ECEF)),
              AppAccent(Color(0xFF8A4326), Color(0xFFF7E0D4)),
              AppAccent(Color(0xFF4B3F8C), Color(0xFFE6E1F7)),
            ],
    );

    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldColor,
      dividerColor: effectiveDivider,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      // Work Sans for reading text; scripts it lacks (Arabic, Urdu) fall
      // back to the platform font automatically.
      fontFamily: bodyFontFamily,
      extensions: <ThemeExtension<dynamic>>[decor],
    );

    final base = baseTheme.textTheme;
    final textTheme = base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.12,
        fontSize: 36 * scale,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.14,
        fontSize: 32 * scale,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.18,
        fontSize: 28 * scale,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.22,
        fontSize: (base.headlineSmall?.fontSize ?? 24) * scale,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
        height: 1.25,
        fontSize: (base.titleLarge?.fontSize ?? 22) * scale,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.3,
        fontSize: (base.titleMedium?.fontSize ?? 16) * scale,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontFamily: displayFontFamily,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.3,
        fontSize: (base.titleSmall?.fontSize ?? 14) * scale,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        height: 1.5,
        letterSpacing: 0,
        fontSize: (base.bodyLarge?.fontSize ?? 16) * scale,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        height: 1.45,
        letterSpacing: 0,
        fontSize: (base.bodyMedium?.fontSize ?? 14) * scale,
      ),
      bodySmall: base.bodySmall?.copyWith(
        height: 1.45,
        letterSpacing: 0,
        fontSize: (base.bodySmall?.fontSize ?? 12) * scale,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        fontSize: (base.labelLarge?.fontSize ?? 14) * scale,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        fontSize: (base.labelMedium?.fontSize ?? 12) * scale,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        fontSize: (base.labelSmall?.fontSize ?? 11) * scale,
      ),
    );

    final fieldFillColor = isDark
        ? colorScheme.surfaceContainerLow
        : colorScheme.surfaceContainerLowest;
    final softBorder = effectiveDivider.withValues(
      alpha: highContrast ? 1 : (isDark ? 0.7 : 0.85),
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);
    const buttonMinSize = Size(48, 48);

    return baseTheme.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        systemOverlayStyle:
            (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
                .copyWith(
                  statusBarColor: Colors.transparent,
                  systemNavigationBarColor: Colors.transparent,
                  systemNavigationBarIconBrightness: isDark
                      ? Brightness.light
                      : Brightness.dark,
                ),
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actionsIconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.3),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          side: BorderSide(color: softBorder.withValues(alpha: 0.5)),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(color: softBorder),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        modalBackgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        modalElevation: 0,
        modalBarrierColor: Colors.black.withValues(alpha: isDark ? 0.6 : 0.42),
        dragHandleColor: colorScheme.outline.withValues(alpha: 0.55),
        dragHandleSize: const Size(44, 5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.xl),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: buttonPadding,
          minimumSize: buttonMinSize,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: buttonPadding,
          minimumSize: buttonMinSize,
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: buttonPadding,
          minimumSize: buttonMinSize,
          foregroundColor: colorScheme.primary,
          shape: buttonShape,
          side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          minimumSize: buttonMinSize,
          foregroundColor: colorScheme.primary,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 3,
        highlightElevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg - 2),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: softBorder)),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? colorScheme.primary
                : fieldFillColor;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? colorScheme.onPrimary
                : colorScheme.onSurface;
          }),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
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
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        prefixIconColor: colorScheme.primary,
        suffixIconColor: colorScheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: softBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: softBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: colorScheme.error, width: 1.8),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        minVerticalPadding: 10,
        iconColor: colorScheme.primary,
        titleTextStyle: textTheme.titleSmall?.copyWith(
          color: colorScheme.onSurface,
          fontSize: (textTheme.titleSmall?.fontSize ?? 14) + 1,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md + 2),
          side: BorderSide(color: softBorder.withValues(alpha: 0.6)),
        ),
        textStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? colorScheme.surfaceContainerHighest
            : const Color(0xFF14342B),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? colorScheme.onSurface : const Color(0xFFF8F1DE),
        ),
        actionTextColor: decor.gold,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFFEFEADB) : const Color(0xFF14342B),
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: textTheme.labelMedium?.copyWith(
          color: isDark ? const Color(0xFF14342B) : const Color(0xFFF8F1DE),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        waitDuration: const Duration(milliseconds: 400),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        height: 72,
        indicatorColor: colorScheme.primary,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primary,
        selectedIconTheme: IconThemeData(color: colorScheme.onPrimary),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorColor: colorScheme.primary,
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          return isDark ? colorScheme.outline : colorScheme.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return colorScheme.outline.withValues(alpha: 0.45);
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: colorScheme.outline, width: 1.6),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        backgroundColor: fieldFillColor,
        disabledColor: fieldFillColor.withValues(alpha: 0.72),
        // Tonal selection: chips across the app keep an onSurface label when
        // selected, so the fill has to stay light enough to read it.
        selectedColor: colorScheme.primaryContainer,
        secondarySelectedColor: colorScheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        checkmarkColor: colorScheme.primary,
        side: BorderSide(color: softBorder),
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onPrimaryContainer,
        ),
      ),
      sliderTheme: baseTheme.sliderTheme.copyWith(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.surfaceContainerHighest,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: 0.12),
        trackHeight: 5,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.primaryContainer,
        circularTrackColor: colorScheme.primaryContainer,
        linearMinHeight: 6,
        borderRadius: BorderRadius.circular(999),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        iconColor: colorScheme.primary,
        collapsedIconColor: colorScheme.onSurfaceVariant,
      ),
      dividerTheme: DividerThemeData(
        color: effectiveDivider.withValues(alpha: isDark ? 0.7 : 0.8),
        thickness: 1,
        space: 1,
      ),
    );
  }
}
