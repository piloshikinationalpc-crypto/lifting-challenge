import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sports_soccer, size: 80, color: Colors.green),
            const SizedBox(height: 24),
            const Text('リフティングチャレンジ',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () => AuthService().signInWithGoogle(context),
              icon: const Icon(Icons.login),
              label: const Text('Googleでログイン'),
            ),
          ],
        ),
      ),
    );
  }
}
