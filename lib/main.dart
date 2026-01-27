import 'package:flutter/material.dart';
import 'screens/goals_list_screen.dart';
import 'services/service_locator.dart';
import 'services/widget_action_handler.dart';
import 'utils/app_colors.dart';
import 'utils/logger.dart';

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
        primary: AppColors.catOrange,
        onPrimary: Colors.white,
        secondary: AppColors.catBlue,
        onSecondary: Colors.white,
        tertiary: AppColors.catGold,
        onTertiary: Colors.white,
        surface: Colors.white,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.catCream,
        error: AppColors.error,
        onError: Colors.white,
        outline: AppColors.catOrangeLight,
        shadow: AppColors.catOrange.withValues(alpha: 0.2),
      ),
      scaffoldBackgroundColor: AppColors.catCream,
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
        backgroundColor: AppColors.catOrange,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.catOrange,
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
          borderSide: const BorderSide(color: AppColors.catOrange, width: 2),
        ),
        contentPadding: const EdgeInsets.all(20),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.catOrange,
        linearTrackColor: AppColors.catOrangeLight,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.catOrange,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.catOrange,
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
        displayLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        headlineSmall: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(color: AppColors.textPrimary),
        bodyLarge: TextStyle(color: AppColors.textPrimary),
        bodyMedium: TextStyle(color: AppColors.textPrimary),
        bodySmall: TextStyle(color: AppColors.textSecondary),
        labelLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(color: AppColors.textPrimary),
        labelSmall: TextStyle(color: AppColors.textSecondary),
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
