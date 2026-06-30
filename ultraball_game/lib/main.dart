import 'package:flutter/material.dart';
import 'ui/settings_screen.dart';

void main() {
  runApp(const UltraballApp());
}

class UltraballApp extends StatelessWidget {
  const UltraballApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ultraball',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFCC00),
          secondary: Color(0xFFFF6600),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      home: const SettingsScreen(),
    );
  }
}
