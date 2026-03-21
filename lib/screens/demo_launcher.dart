import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'heatmap_dashboard.dart';
import 'ai_scanner_screen.dart';
import 'volunteer_onboarding_screen.dart';

class DemoLauncher extends StatelessWidget {
  const DemoLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.hub, color: AppTheme.primary, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'AIDWISE DEMO',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        color: AppTheme.textPrimary,
                        shadows: [Shadow(color: AppTheme.primary.withValues(alpha: 0.5), blurRadius: 10)],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Select your operating role', style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 64),
              
              // Field Worker Role
              _buildRoleButton(
                context: context,
                title: 'Field Worker',
                subtitle: 'Scan & Digitize Reports',
                icon: Icons.document_scanner,
                color: AppTheme.primary,
                targetScreen: const AIScannerScreen(),
              ),
              const SizedBox(height: 20),
              
              // Admin Role
              _buildRoleButton(
                context: context,
                title: 'Command Center',
                subtitle: 'Triage & Dispatch AI',
                icon: Icons.map,
                color: AppTheme.secondary,
                targetScreen: const HeatmapDashboard(),
              ),
              const SizedBox(height: 20),
              
              // Volunteer Role
              _buildRoleButton(
                context: context,
                title: 'Field Volunteer',
                subtitle: 'Execute AI Missions',
                icon: Icons.person_pin,
                color: AppTheme.urgencyLow,
                targetScreen: const VolunteerOnboardingScreen(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget targetScreen,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => targetScreen));
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: AppTheme.glassmorphismShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
