import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/admin_hub_screen.dart';
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
                return const Scaffold(backgroundColor: AppTheme.background, body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
              }
              
              // Handle Firestore errors (timeout, rules, etc.)
              if (roleSnapshot.hasError) {
                return Scaffold(
                  backgroundColor: AppTheme.background,
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off, color: Colors.orangeAccent, size: 64),
                          const SizedBox(height: 16),
                          const Text('Connection Error', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Could not reach database. Check your internet or Firestore rules.', style: TextStyle(color: AppTheme.textSecondary), textAlign: TextAlign.center),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => AuthService().signOut(),
                            icon: const Icon(Icons.logout),
                            label: const Text('SIGN OUT & RETRY'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final role = roleSnapshot.data;
              if (role == 'Admin / NGO') return const AdminHubScreen();
              if (role == 'Field Worker') return const AIScannerScreen();
              if (role == 'Volunteer') return const VolunteerDashboardScreen();
              
              // Fallback if role is null or unrecognized (migrated user without role)
              return Scaffold(
                backgroundColor: AppTheme.background,
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_off, color: Colors.orangeAccent, size: 64),
                        const SizedBox(height: 16),
                        const Text('Role Not Found', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Your account does not have a role assigned. Please sign out and register again with a role.', style: TextStyle(color: AppTheme.textSecondary), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => AuthService().signOut(),
                          icon: const Icon(Icons.logout),
                          label: const Text('SIGN OUT & RE-REGISTER'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }
        
        // Not logged in
        return const LoginScreen();
      },
    );
  }
}
