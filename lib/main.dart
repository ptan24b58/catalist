import 'package:flutter/material.dart';
import 'screens/goals_list_screen.dart';
import 'services/widget_action_handler.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    // Cat mascot inspired color palette
    // Orange (cat's fur), Cream (lighter areas), Blue (collar), Gold (bell)
    const catOrange = Color(0xFFFF8C42); // Primary orange
    const catOrangeLight = Color(0xFFFFE4D1); // Light orange
    const catCream = Color(0xFFFFF8F0); // Cream background
    const catBlue = Color(0xFF5B9BD5); // Blue collar
    const catGold = Color(0xFFFFB84D); // Golden bell

    return MaterialApp(
      title: 'Goal Tracker',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: catOrange,
          onPrimary: Colors.white,
          secondary: catBlue,
          onSecondary: Colors.white,
          tertiary: catGold,
          onTertiary: Colors.white,
          surface: catCream,
          onSurface: const Color(0xFF2C2C2C),
          surfaceContainerHighest: catCream,
          error: const Color(0xFFE57373),
          onError: Colors.white,
          outline: catOrangeLight,
          shadow: catOrange.withValues(alpha: 0.2),
        ),
        scaffoldBackgroundColor: catCream,
        appBarTheme: const AppBarTheme(
          backgroundColor: catOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: catOrange,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: catOrange,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: catOrangeLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: catOrangeLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: catOrange, width: 2),
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: catOrange,
          linearTrackColor: catOrangeLight,
        ),
        iconTheme: const IconThemeData(
          color: catOrange,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: catCream,
          selectedColor: catOrangeLight,
          checkmarkColor: catOrange,
          labelStyle: const TextStyle(color: Color(0xFF2C2C2C)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Color(0xFF2C2C2C)),
          displayMedium: TextStyle(color: Color(0xFF2C2C2C)),
          displaySmall: TextStyle(color: Color(0xFF2C2C2C)),
          headlineLarge: TextStyle(color: Color(0xFF2C2C2C)),
          headlineMedium: TextStyle(color: Color(0xFF2C2C2C)),
          headlineSmall: TextStyle(color: Color(0xFF2C2C2C)),
          titleLarge:
              TextStyle(color: Color(0xFF2C2C2C), fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: Color(0xFF2C2C2C)),
          titleSmall: TextStyle(color: Color(0xFF2C2C2C)),
          bodyLarge: TextStyle(color: Color(0xFF2C2C2C)),
          bodyMedium: TextStyle(color: Color(0xFF2C2C2C)),
          bodySmall: TextStyle(color: Color(0xFF666666)),
          labelLarge: TextStyle(color: Color(0xFF2C2C2C)),
          labelMedium: TextStyle(color: Color(0xFF2C2C2C)),
          labelSmall: TextStyle(color: Color(0xFF666666)),
        ),
      ),
      home: const GoalsListScreen(),
      debugShowCheckedModeBanner: false,
      onGenerateRoute: (settings) {
        // Handle deep links from widgets
        if (settings.name?.startsWith('goalwidget://') == true) {
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
      },
    );
  }
}
