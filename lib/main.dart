import 'package:flutter/material.dart';
import 'screens/goals_list_screen.dart';
import 'services/service_locator.dart';
import 'services/widget_action_handler.dart';
import 'utils/app_colors.dart';
import 'utils/logger.dart';

const _textBold =
    TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold);
const _textW600 =
    TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600);
const _textPrimary = TextStyle(color: AppColors.textPrimary);
const _textSecondary = TextStyle(color: AppColors.textSecondary);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services early to ensure WidgetUpdateEngine is registered
  try {
    final _ = widgetUpdateEngine; // Trigger initialization
  } catch (e, stackTrace) {
    AppLogger.error('Error initializing WidgetUpdateEngine', e, stackTrace);
  }

  // Check for widget actions on app start
  try {
    final actionHandler = WidgetActionHandler();
    await actionHandler.checkAndProcessActions();
  } catch (e, stackTrace) {
    AppLogger.error('Error initializing app', e, stackTrace);
    // Continue app startup even if widget action check fails
  }

  runApp(const GoalTrackerApp());
}

class GoalTrackerApp extends StatelessWidget {
  const GoalTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catalist',
      theme: _buildTheme(),
      home: const GoalsListScreen(),
      debugShowCheckedModeBanner: false,
      onGenerateRoute: _handleDeepLink,
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.catBlue,
        onSecondary: Colors.white,
        tertiary: AppColors.catGold,
        onTertiary: Colors.white,
        surface: Colors.white,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.surfaceTint,
        error: AppColors.error,
        onError: Colors.white,
        outline: AppColors.primaryLight,
        shadow: AppColors.primary.withValues(alpha: 0.2),
      ),
      scaffoldBackgroundColor: AppColors.surfaceTint,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: EdgeInsets.zero,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primaryLight,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.primary,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.primary,
        checkmarkColor: Colors.white,
        labelStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: _textBold,
        displayMedium: _textBold,
        displaySmall: _textBold,
        headlineLarge: _textBold,
        headlineMedium: _textBold,
        headlineSmall: _textBold,
        titleLarge: _textBold,
        titleMedium: _textW600,
        titleSmall: _textPrimary,
        bodyLarge: _textPrimary,
        bodyMedium: _textPrimary,
        bodySmall: _textSecondary,
        labelLarge: _textW600,
        labelMedium: _textPrimary,
        labelSmall: _textSecondary,
      ),
    );
  }

  Route<dynamic>? _handleDeepLink(RouteSettings settings) {
    // Handle deep links from widgets
    final routeName = settings.name;
    if (routeName == null || !routeName.startsWith('catalist://')) {
      return null;
    }

    try {
      // Validate URI before parsing - prevent DoS attacks
      if (routeName.length > 500) {
        AppLogger.warning('Deep link URI too long, potential attack');
        return null;
      }

      // Additional validation: check for suspicious patterns
      if (routeName.contains('..') || routeName.contains('//') || routeName.contains('\n') || routeName.contains('\r')) {
        AppLogger.warning('Deep link contains suspicious characters');
        return null;
      }

      final uri = Uri.tryParse(routeName);
      if (uri == null || uri.scheme != 'catalist') {
        AppLogger.warning('Invalid deep link URI: $routeName');
        return null;
      }

      // Only allow specific hosts for security
      if (uri.host == 'log') {
        final goalId = uri.queryParameters['goalId'];
        // Validation happens in processDeepLink
        WidgetActionHandler().processDeepLink(goalId);
      } else {
        AppLogger.warning('Unknown deep link host: ${uri.host}');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error processing deep link route', e, stackTrace);
    }
    return null;
  }
}
