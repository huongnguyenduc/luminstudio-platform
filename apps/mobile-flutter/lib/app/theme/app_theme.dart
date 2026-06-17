import 'package:flutter/material.dart';

/// Raw brand color tokens for Lumin Studio.
///
/// The palette keeps the signature jade identity but pushes it brighter and
/// pairs it with a warm brass accent so the storefront feels energetic and
/// premium ("bold & vibrant" direction).
abstract final class LuminColors {
  // Brand greens.
  static const jade = Color(0xFF0B8A75);
  static const jadeDeep = Color(0xFF066354);
  static const jadeBright = Color(0xFF15B89A);
  static const teal = Color(0xFF0FA890);

  // Warm accent (sale badges, highlights).
  static const brass = Color(0xFFC8893A);
  static const brassBright = Color(0xFFE6A94E);

  // Discount / "hot deal" accent.
  static const ember = Color(0xFFE8553D);

  // Light surfaces.
  static const ink = Color(0xFF0F1A16);
  static const mist = Color(0xFFF1F6F2);
  static const surfaceLight = Color(0xFFFFFFFF);

  // Dark surfaces.
  static const darkBg = Color(0xFF0B130F);
  static const darkSurface = Color(0xFF14201B);
  static const darkElevated = Color(0xFF1B2A24);
  static const jadeOnDark = Color(0xFF44D6B8);
  static const onDark = Color(0xFFE7F0EB);
}

/// Corner radius scale.
abstract final class LuminRadii {
  static const sm = 12.0;
  static const md = 18.0;
  static const lg = 24.0;
  static const xl = 30.0;
  static const pill = 999.0;
}

/// Reusable elevation shadows tuned per brightness.
abstract final class LuminShadows {
  static List<BoxShadow> card(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 24,
          offset: Offset(0, 12),
        ),
      ];
    }
    return const [
      BoxShadow(
        color: Color(0x14101C18),
        blurRadius: 24,
        offset: Offset(0, 12),
      ),
    ];
  }

  static List<BoxShadow> glow(Color color) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.35),
        blurRadius: 22,
        spreadRadius: -2,
        offset: const Offset(0, 10),
      ),
    ];
  }
}

/// Theme extension carrying brand gradients so widgets resolve the right
/// version for light or dark mode via `Theme.of(context).gradients`.
@immutable
class LuminGradients extends ThemeExtension<LuminGradients> {
  const LuminGradients({
    required this.hero,
    required this.brand,
    required this.mediaBackdrop,
    required this.discount,
  });

  /// Large marketing surfaces (home hero).
  final Gradient hero;

  /// Strong call-to-action surfaces (buttons, selected chips).
  final Gradient brand;

  /// Subtle backdrop behind product media / 3D viewers.
  final Gradient mediaBackdrop;

  /// Sale / discount badge.
  final Gradient discount;

  static const light = LuminGradients(
    hero: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF066354), Color(0xFF0B8A75), Color(0xFF15B89A)],
    ),
    brand: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Color(0xFF0B8A75), Color(0xFF12B89A)],
    ),
    mediaBackdrop: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEFFBF7), Color(0xFFDCF3EC)],
    ),
    discount: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE8553D), Color(0xFFEA7A3C)],
    ),
  );

  static const dark = LuminGradients(
    hero: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0A4439), Color(0xFF0C6354), Color(0xFF12907A)],
    ),
    brand: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Color(0xFF12B89A), Color(0xFF1ED9B6)],
    ),
    mediaBackdrop: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1B2A24), Color(0xFF123129)],
    ),
    discount: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF06647), Color(0xFFF08A4A)],
    ),
  );

  @override
  LuminGradients copyWith({
    Gradient? hero,
    Gradient? brand,
    Gradient? mediaBackdrop,
    Gradient? discount,
  }) {
    return LuminGradients(
      hero: hero ?? this.hero,
      brand: brand ?? this.brand,
      mediaBackdrop: mediaBackdrop ?? this.mediaBackdrop,
      discount: discount ?? this.discount,
    );
  }

  @override
  LuminGradients lerp(ThemeExtension<LuminGradients>? other, double t) {
    if (other is! LuminGradients) {
      return this;
    }
    // Gradients don't interpolate cleanly; snap at the midpoint.
    return t < 0.5 ? this : other;
  }
}

/// Convenience accessor for brand gradients.
extension LuminThemeX on BuildContext {
  LuminGradients get gradients =>
      Theme.of(this).extension<LuminGradients>() ?? LuminGradients.light;
}

/// Builds the Lumin Studio [ThemeData] for the given [brightness].
ThemeData buildLuminTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final colorScheme = isDark
      ? const ColorScheme.dark(
          primary: LuminColors.jadeOnDark,
          onPrimary: Color(0xFF00241D),
          primaryContainer: Color(0xFF0E4D41),
          onPrimaryContainer: Color(0xFFB9F4E5),
          secondary: LuminColors.brassBright,
          onSecondary: Color(0xFF3A2700),
          secondaryContainer: Color(0xFF4A3411),
          onSecondaryContainer: Color(0xFFF6DBB0),
          surface: LuminColors.darkSurface,
          onSurface: LuminColors.onDark,
          onSurfaceVariant: Color(0xFFA9BCB4),
          surfaceContainerHighest: Color(0xFF24332D),
          surfaceContainerHigh: Color(0xFF1F2E28),
          surfaceContainer: LuminColors.darkElevated,
          outline: Color(0xFF3C4E47),
          outlineVariant: Color(0xFF2A3833),
          error: Color(0xFFFF9C8C),
          shadow: Color(0xFF000000),
        )
      : ColorScheme.fromSeed(
          seedColor: LuminColors.jade,
          brightness: Brightness.light,
          primary: LuminColors.jade,
          onPrimary: Colors.white,
          secondary: LuminColors.brass,
          surface: LuminColors.surfaceLight,
          onSurface: LuminColors.ink,
        );

  final scaffoldBackground = isDark ? LuminColors.darkBg : LuminColors.mist;
  final baseTextTheme = (isDark ? Typography.whiteMountainView : Typography.blackMountainView);

  final textTheme = baseTextTheme
      .apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      )
      .copyWith(
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: colorScheme.onSurface,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: colorScheme.onSurface,
        ),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          color: colorScheme.onSurface,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: colorScheme.onSurface,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      );

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: scaffoldBackground,
    textTheme: textTheme,
    extensions: <ThemeExtension<dynamic>>[
      isDark ? LuminGradients.dark : LuminGradients.light,
    ],
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: scaffoldBackground,
      foregroundColor: colorScheme.onSurface,
      titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 22),
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LuminRadii.md),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark
          ? LuminColors.darkElevated
          : LuminColors.ink,
      contentTextStyle: TextStyle(
        color: isDark ? LuminColors.onDark : Colors.white,
        fontWeight: FontWeight.w600,
      ),
      actionTextColor: colorScheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LuminRadii.sm),
      ),
      insetPadding: const EdgeInsets.fromLTRB(16, 5, 16, 12),
      elevation: 6,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.primary.withValues(alpha: isDark ? 0.26 : 0.16),
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected
              ? colorScheme.onSurface
              : colorScheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        );
      }),
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll<double>(0),
      backgroundColor: WidgetStatePropertyAll<Color>(colorScheme.surface),
      side: WidgetStatePropertyAll<BorderSide>(
        BorderSide(color: colorScheme.outlineVariant),
      ),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LuminRadii.md),
        ),
      ),
      padding: const WidgetStatePropertyAll<EdgeInsets>(
        EdgeInsets.symmetric(horizontal: 16),
      ),
      hintStyle: WidgetStatePropertyAll<TextStyle>(
        TextStyle(color: colorScheme.onSurfaceVariant),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surface,
      selectedColor: colorScheme.primary.withValues(alpha: isDark ? 0.28 : 0.16),
      side: BorderSide(color: colorScheme.outlineVariant),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LuminRadii.pill),
      ),
      labelStyle: TextStyle(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LuminRadii.md),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LuminRadii.sm),
        ),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
    ),
  );
}
