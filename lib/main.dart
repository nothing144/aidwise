import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/heatmap_dashboard.dart';
import 'screens/ai_scanner_screen.dart';
import 'screens/volunteer_dashboard_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still initializing Firebase Auth
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: AppTheme.background, body: Center(child: CircularProgressIndicator()));
        }
        
        // Output User Logged In State
        if (snapshot.hasData) {
          return FutureBuilder<String?>(
            future: AuthService().getUserRole(),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(backgroundColor: AppTheme.background, body: Center(child: CircularProgressIndicator()));
              }
              final role = roleSnapshot.data;
              if (role == 'Admin / NGO') return const HeatmapDashboard();
              if (role == 'Field Worker') return const AIScannerScreen();
              if (role == 'Volunteer') return const VolunteerDashboardScreen();
              
              // Fallback if role is null or unrecognized
              return const Scaffold(backgroundColor: AppTheme.background, body: Center(child: Text('Unknown Role', style: TextStyle(color: Colors.white))));
            },
          );
        }
        
        // Not logged in
        return const LoginScreen();
      },
    );
  }
}
