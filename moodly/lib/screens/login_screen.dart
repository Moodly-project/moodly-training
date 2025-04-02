import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:moodly/screens/register_screen.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moodly/screens/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    print("Token saved");
  }

  Future<void> _login() async {
    if (_isLoading) return;
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      final url = Uri.parse('http://10.0.2.2:3000/api/v1/auth/login'); // Emulator IP
      String errorMessage = 'Credenciais inválidas.';
      bool loginSuccess = false;

      try {
         final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'email': _emailController.text,
            'password': _passwordController.text,
          }),
        ).timeout(const Duration(seconds: 10));

        final responseData = json.decode(response.body);

        if (response.statusCode == 200 && responseData['success'] == true) {
            loginSuccess = true;
            final token = responseData['token'] as String?;
            if (token != null) {
              await _saveToken(token);
            } else {
               print("Login OK, no token?");
               loginSuccess = false; 
               errorMessage = 'Erro no token.';
            }
        } else {
          errorMessage = responseData['message'] ?? 'Falha login (${response.statusCode})';
        }
      } catch (error) {
         print("Login API Error: $error");
         errorMessage = 'Erro conexão.';
      }

      if (!mounted) return;
      
      if (loginSuccess) {
           print("Login OK -> Home");
           Navigator.of(context).pushReplacement(
             MaterialPageRoute(builder: (context) => const HomeScreen(title: 'Moodly')),
           );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
         setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login - Moodly')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                 const Icon(Icons.spa, size: 80, color: Colors.deepPurple), // Logo
                 const SizedBox(height: 20),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty || !value.contains('@')) {
                      return 'Email inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Senha',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Insira senha';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Entrar'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading ? null : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterScreen()),
                    );
                  },
                  child: const Text('Não tem conta? Registre-se'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 