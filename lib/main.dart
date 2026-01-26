import 'package:flutter/material.dart';
import 'screens/goals_list_screen.dart';
import 'services/service_locator.dart';
import 'services/widget_action_handler.dart';
import 'utils/app_colors.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services early to ensure WidgetUpdateEngine is registered
  // This ensures the listener is set up before any goal operations
  try {
    // Access widgetUpdateEngine to trigger initialization
    final engine = widgetUpdateEngine;
    print('✅ [INIT] WidgetUpdateEngine accessed and should be initialized');
    
    // Verify the repository has a listener registered
    // We can't directly check, but accessing the engine should have registered it
    print('✅ [INIT] Services initialized - ready to track goal changes');
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
        onPrimary: AppColors.textOnDark,
        secondary: AppColors.catBlue,
        onSecondary: AppColors.textOnDark,
        tertiary: AppColors.catGold,
        onTertiary: AppColors.textOnDark,
        surface: AppColors.catCream,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.catCream,
        error: AppColors.error,
        onError: AppColors.textOnDark,
        outline: AppColors.catOrangeLight,
        shadow: AppColors.catOrange.withValues(alpha: 0.2),
      ),
      scaffoldBackgroundColor: AppColors.catCream,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.catOrange,
        foregroundColor: AppColors.textOnDark,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textOnDark),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceWhite,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.catOrange,
        foregroundColor: AppColors.textOnDark,
        elevation: 4,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.catOrange,
          foregroundColor: AppColors.textOnDark,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.catOrangeLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.catOrangeLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.catOrange, width: 2),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.catOrange,
        linearTrackColor: AppColors.catOrangeLight,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.catOrange,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.catCream,
        selectedColor: AppColors.catOrangeLight,
        checkmarkColor: AppColors.catOrange,
        labelStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: AppColors.textPrimary),
        displayMedium: TextStyle(color: AppColors.textPrimary),
        displaySmall: TextStyle(color: AppColors.textPrimary),
        headlineLarge: TextStyle(color: AppColors.textPrimary),
        headlineMedium: TextStyle(color: AppColors.textPrimary),
        headlineSmall: TextStyle(color: AppColors.textPrimary),
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(color: AppColors.textPrimary),
        titleSmall: TextStyle(color: AppColors.textPrimary),
        bodyLarge: TextStyle(color: AppColors.textPrimary),
        bodyMedium: TextStyle(color: AppColors.textPrimary),
        bodySmall: TextStyle(color: AppColors.textSecondary),
        labelLarge: TextStyle(color: AppColors.textPrimary),
        labelMedium: TextStyle(color: AppColors.textPrimary),
        labelSmall: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  Route<dynamic>? _handleDeepLink(RouteSettings settings) {
    // Handle deep links from widgets
    if (settings.name?.startsWith('catalist://') == true) {
      try {
        final uri = Uri.parse(settings.name!);
        if (uri.host == 'log') {
          final goalId = uri.queryParameters['goalId'];
          WidgetActionHandler().processDeepLink(goalId);
        }
      } catch (e, stackTrace) {
        AppLogger.error('Error processing deep link route', e, stackTrace);
      }
    }
    return null;
  }
}
