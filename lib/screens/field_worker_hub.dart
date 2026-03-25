import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'ai_scanner_screen.dart';
import 'my_reports_screen.dart';

class FieldWorkerHub extends StatefulWidget {
  const FieldWorkerHub({super.key});

  @override
  State<FieldWorkerHub> createState() => _FieldWorkerHubState();
}

class _FieldWorkerHubState extends State<FieldWorkerHub> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const AIScannerScreen(),
    const MyReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppTheme.background,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textSecondary,
        elevation: 20,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.document_scanner), label: 'Scanner'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'My Reports'),
        ],
      ),
    );
  }
}
