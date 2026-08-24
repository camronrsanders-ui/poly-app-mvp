import 'package:flutter/material.dart';

@immutable
class PolycircleColors extends ThemeExtension<PolycircleColors> {
  const PolycircleColors({
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.borderStrong,
    required this.error,
    required this.onError,
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.shadow,
    required this.focus,
  });

  final Color surface;
  final Color surfaceRaised;
  final Color surfaceMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color borderStrong;
  final Color error;
  final Color onError;
  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color shadow;
  final Color focus;

  static const light = PolycircleColors(
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF4EFF7),
    surfaceMuted: Color(0xFFEDE6F0),
    textPrimary: Color(0xFF21172B),
    textSecondary: Color(0xFF594E61),
    textMuted: Color(0xFF716677),
    border: Color(0xFFD7CCD9),
    borderStrong: Color(0xFF9B8AA2),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    success: Color(0xFF176B43),
    onSuccess: Color(0xFFFFFFFF),
    warning: Color(0xFF7A4A00),
    onWarning: Color(0xFFFFFFFF),
    shadow: Color(0x240F0714),
    focus: AppTheme.accentBlue,
  );

  static const dark = PolycircleColors(
    surface: Color(0xFF120C18),
    surfaceRaised: Color(0xFF1D1426),
    surfaceMuted: Color(0xFF2A1D34),
    textPrimary: Color(0xFFF8F1FF),
    textSecondary: Color(0xFFD4C7DC),
    textMuted: Color(0xFFB7A9C0),
    border: Color(0xFF514458),
    borderStrong: Color(0xFF7D6C86),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    success: Color(0xFF7DDAA8),
    onSuccess: Color(0xFF003921),
    warning: Color(0xFFFFC56C),
    onWarning: Color(0xFF412D00),
    shadow: Color(0xA6000000),
    focus: AppTheme.accentBlue,
  );

  static PolycircleColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<PolycircleColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  PolycircleColors copyWith({
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? borderStrong,
    Color? error,
    Color? onError,
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? shadow,
    Color? focus,
  }) {
    return PolycircleColors(
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      shadow: shadow ?? this.shadow,
      focus: focus ?? this.focus,
    );
  }

  @override
  PolycircleColors lerp(covariant PolycircleColors? other, double t) {
    if (other == null) return this;
    return PolycircleColors(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      error: Color.lerp(error, other.error, t)!,
      onError: Color.lerp(onError, other.onError, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
    );
  }
}

class AppSpacing {
  const AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
}

class AppRadius {
  const AppRadius._();

  static const double sm = 10;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;
}

class AppElevation {
  const AppElevation._();

  static const double none = 0;
  static const double low = 1;
  static const double medium = 3;
  static const double high = 8;
}

class AppTheme {
  const AppTheme._();

  static const Color brandPurple = Color(0xFF2D0B45);
  static const Color accentPink = Color(0xFFE94B9B);
  static const Color accentBlue = Color(0xFF3DC7F3);
  static const Color accentGold = Color(0xFFFFB23F);

  static const double minimumTapTarget = 48;

  static ThemeData get light => _build(
        brightness: Brightness.light,
        semantic: PolycircleColors.light,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        semantic: PolycircleColors.dark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required PolycircleColors semantic,
  }) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: brandPurple,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? const Color(0xFFD8B4FE) : brandPurple,
      onPrimary: isDark ? brandPurple : Colors.white,
      secondary: accentPink,
      onSecondary: const Color(0xFF2A071C),
      tertiary: accentBlue,
      onTertiary: brandPurple,
      surface: semantic.surface,
      onSurface: semantic.textPrimary,
      error: semantic.error,
      onError: semantic.onError,
      outline: semantic.borderStrong,
      shadow: semantic.shadow,
    );

    final typography = _typography(semantic);
    final rounded16 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: semantic.border),
    );

    final baseButtonPadding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.sm,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0B0710) : const Color(0xFFF9F7FB),
      textTheme: typography,
      extensions: <ThemeExtension<dynamic>>[semantic],
      dividerColor: semantic.border,
      disabledColor: semantic.textMuted.withValues(alpha: 0.48),
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, minimumTapTarget),
          padding: baseButtonPadding,
          foregroundColor: scheme.onPrimary,
          backgroundColor: scheme.primary,
          disabledForegroundColor: semantic.textMuted,
          disabledBackgroundColor: semantic.surfaceMuted,
          elevation: AppElevation.low,
          shadowColor: semantic.shadow,
          shape: rounded16,
          textStyle: typography.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, minimumTapTarget),
          padding: baseButtonPadding,
          foregroundColor: scheme.onPrimary,
          backgroundColor: scheme.primary,
          disabledForegroundColor: semantic.textMuted,
          disabledBackgroundColor: semantic.surfaceMuted,
          shape: rounded16,
          textStyle: typography.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, minimumTapTarget),
          padding: baseButtonPadding,
          foregroundColor: scheme.primary,
          backgroundColor: Colors.transparent,
          disabledForegroundColor: semantic.textMuted,
          side: BorderSide(color: semantic.borderStrong),
          shape: rounded16,
          textStyle: typography.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, minimumTapTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          foregroundColor: scheme.primary,
          disabledForegroundColor: semantic.textMuted,
          shape: rounded16,
          textStyle: typography.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: semantic.surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        labelStyle: typography.bodyMedium?.copyWith(
          color: semantic.textSecondary,
        ),
        floatingLabelStyle: typography.bodySmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: typography.bodyMedium?.copyWith(color: semantic.textMuted),
        helperStyle:
            typography.bodySmall?.copyWith(color: semantic.textSecondary),
        errorStyle: typography.bodySmall?.copyWith(color: semantic.error),
        prefixIconColor: semantic.textSecondary,
        suffixIconColor: semantic.textSecondary,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: semantic.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: semantic.error, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: semantic.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: semantic.shadow,
        elevation: AppElevation.none,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: semantic.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: semantic.surfaceRaised,
        selectedColor: scheme.primary.withValues(alpha: isDark ? 0.28 : 0.12),
        disabledColor: semantic.surfaceMuted,
        checkmarkColor: scheme.primary,
        labelStyle: typography.labelMedium?.copyWith(
          color: semantic.textPrimary,
        ),
        secondaryLabelStyle: typography.labelMedium?.copyWith(
          color: semantic.textPrimary,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        side: BorderSide(color: semantic.border),
        shape: const StadiumBorder(),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: semantic.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: semantic.textMuted,
        showUnselectedLabels: true,
        elevation: AppElevation.medium,
        selectedLabelStyle: typography.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: typography.labelSmall,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFFF0E5F6)
            : const Color(0xFF2A1E30),
        contentTextStyle: typography.bodyMedium?.copyWith(
          color: isDark ? const Color(0xFF21172B) : const Color(0xFFF9F2FD),
        ),
        actionTextColor: isDark ? brandPurple : const Color(0xFFE3C3FF),
        elevation: AppElevation.medium,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: semantic.surface,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.high,
        shadowColor: semantic.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: semantic.border),
        ),
        titleTextStyle: typography.headlineSmall?.copyWith(
          color: semantic.textPrimary,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: typography.bodyMedium?.copyWith(
          color: semantic.textSecondary,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: semantic.surface,
        foregroundColor: semantic.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.none,
        scrolledUnderElevation: AppElevation.low,
        shadowColor: semantic.shadow,
        centerTitle: false,
        titleSpacing: AppSpacing.md,
        titleTextStyle: typography.titleLarge?.copyWith(
          color: semantic.textPrimary,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(color: semantic.textPrimary),
        actionsIconTheme: IconThemeData(color: semantic.textPrimary),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: semantic.textSecondary,
        indicatorColor: scheme.primary,
        dividerColor: semantic.border,
        labelStyle: typography.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: typography.labelLarge,
      ),
    );
  }

  static TextTheme _typography(PolycircleColors semantic) {
    TextStyle style({
      required double size,
      required double height,
      required FontWeight weight,
      double letterSpacing = 0,
    }) {
      return TextStyle(
        color: semantic.textPrimary,
        fontSize: size,
        height: height,
        fontWeight: weight,
        letterSpacing: letterSpacing,
      );
    }

    return TextTheme(
      displayLarge: style(
        size: 57,
        height: 1.12,
        weight: FontWeight.w700,
        letterSpacing: -0.25,
      ),
      displayMedium: style(
        size: 45,
        height: 1.16,
        weight: FontWeight.w700,
      ),
      displaySmall: style(
        size: 36,
        height: 1.22,
        weight: FontWeight.w700,
      ),
      headlineLarge: style(
        size: 32,
        height: 1.25,
        weight: FontWeight.w800,
      ),
      headlineMedium: style(
        size: 28,
        height: 1.28,
        weight: FontWeight.w800,
      ),
      headlineSmall: style(
        size: 24,
        height: 1.3,
        weight: FontWeight.w700,
      ),
      titleLarge: style(
        size: 22,
        height: 1.28,
        weight: FontWeight.w700,
      ),
      titleMedium: style(
        size: 16,
        height: 1.5,
        weight: FontWeight.w700,
        letterSpacing: 0.15,
      ),
      titleSmall: style(
        size: 14,
        height: 1.45,
        weight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      bodyLarge: style(
        size: 16,
        height: 1.5,
        weight: FontWeight.w400,
        letterSpacing: 0.5,
      ),
      bodyMedium: style(
        size: 14,
        height: 1.45,
        weight: FontWeight.w400,
        letterSpacing: 0.25,
      ),
      bodySmall: style(
        size: 12,
        height: 1.4,
        weight: FontWeight.w400,
        letterSpacing: 0.4,
      ),
      labelLarge: style(
        size: 14,
        height: 1.4,
        weight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      labelMedium: style(
        size: 12,
        height: 1.35,
        weight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
      labelSmall: style(
        size: 11,
        height: 1.35,
        weight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }
}
