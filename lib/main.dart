import 'dart:convert'; // Needed for json decode
import 'package:flutter/material.dart';
import 'package:moodly/screens/splash_screen.dart';
// MoodEntry model might still be needed if passed around
// import 'package:moodly/models/mood_entry.dart'; 
// import 'package:moodly/screens/add_mood_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Keep for logout
import 'package:intl/intl.dart';
import 'package:moodly/screens/login_screen.dart'; // Keep for logout
import 'package:intl/date_symbol_data_local.dart'; // Import for locale data
import 'package:moodly/services/api_service.dart'; // Use ApiService
// Import the new HomeScreen location
import 'package:moodly/screens/home_screen.dart';

void main() async { // Make main async
  // Ensure widgets binding is initialized before using plugins
  WidgetsFlutterBinding.ensureInitialized(); 
  // Initialize locale data for date formatting
  await initializeDateFormatting('pt_BR', null); 
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moodly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      // Consider routes for cleaner navigation later
    );
  }
}

// HomeScreen has been moved to lib/screens/home_screen.dart
