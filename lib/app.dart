import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_constants.dart';
import 'ui/screens/home_screen.dart';

class LinkpcApp extends StatelessWidget {
  static final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

  const LinkpcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      navigatorObservers: [routeObserver],
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.cyberCyan,
        fontFamily: 'monospace',
        colorScheme: const ColorScheme.dark(
          primary: AppColors.cyberCyan,
          secondary: AppColors.neonEmerald,
          surface: AppColors.surface,
          error: AppColors.error,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.voidDark,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: AppColors.textSecondary),
        ),
        cardTheme: const CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
