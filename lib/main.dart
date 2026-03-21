import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/demo_launcher.dart';

void main() {
  runApp(const AidwiseApp());
}

class AidwiseApp extends StatelessWidget {
  const AidwiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aidwise V2',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const DemoLauncher(),
    );
  }
}
