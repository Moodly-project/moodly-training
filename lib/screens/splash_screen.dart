import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:moodly/screens/login_screen.dart'; // Assuming login screen path
import 'package:moodly/screens/home_screen.dart'; // Correct import for HomeScreen
import 'package:moodly/main.dart'; // Import MyHomePage (temporary home)
import 'package:shared_preferences/shared_preferences.dart'; // To check token
// import 'package:moodly/screens/home_screen.dart'; // Will need home screen later
// import 'package:shared_preferences/shared_preferences.dart'; // To check login state

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 2)); // Delay

    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');

    // Basic token check
    // TODO: Validate token properly
    bool isLoggedIn = token != null && token.isNotEmpty;

    if (!mounted) return;

    if (isLoggedIn) {
      print("Token found -> Home");
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen(title: 'Moodly')), // Navigate to HomeScreen
      );
    } else {
      print("No token -> Login");
      // Limpa todos os dados armazenados se não houver login ativo
      await prefs.clear();
      print("Dados locais limpos devido à ausência de login");
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Replace with your actual logo or splash image
            Icon(Icons.spa, size: 100, color: Colors.deepPurple), 
            SizedBox(height: 20),
            Text(
              'Moodly',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
             SizedBox(height: 10),
             CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
} 