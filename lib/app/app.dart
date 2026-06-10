import 'package:flutter/material.dart';

// Import the new Splash Screen instead of the Home Screen
import '../screens/splash/splash_screen.dart';
import 'theme.dart';

class DishAlignerApp extends StatelessWidget {
  const DishAlignerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dish Align Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      // CHANGE THIS LINE to point to the Splash Screen
      home: const SplashScreen(),
    );
  }
}
