import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'heatmap_dashboard.dart';
import 'volunteer_terminal.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String? _selectedRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        boxShadow: AppTheme.cyanGlow,
                      ),
                      child: const Icon(Icons.hub, color: AppTheme.primary, size: 48),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'AIDWISE',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 8,
                        color: AppTheme.textPrimary,
                        shadows: [
                          Shadow(
                            color: AppTheme.primary.withValues(alpha: 0.5),
                            blurRadius: 10,
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cyber-Humanitarian Command',
                      style: TextStyle(
                        fontSize: 14,
                        letterSpacing: 2,
                        color: AppTheme.primary.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 64),
              const Text(
                'Select Operating Mode',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              _buildRoleCard(
                id: 'dispatcher',
                title: 'NGO Dispatcher',
                subtitle: 'Coordinate ground resources and live heatmaps.',
                icon: Icons.radar,
                color: AppTheme.primary,
              ),
              const SizedBox(height: 16),
              _buildRoleCard(
                id: 'volunteer',
                title: 'Field Volunteer',
                subtitle: 'Receive AI-matched missions and save lives.',
                icon: Icons.person_pin_circle,
                color: AppTheme.secondary,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selectedRole != null
                      ? () {
                          if (_selectedRole == 'dispatcher') {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const HeatmapDashboard()),
                            );
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const VolunteerTerminalScreen()),
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedRole != null
                        ? (_selectedRole == 'dispatcher' ? AppTheme.primary : AppTheme.secondary)
                        : AppTheme.surfaceLow,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: _selectedRole != null ? 8 : 0,
                    shadowColor: _selectedRole != null
                        ? (_selectedRole == 'dispatcher' ? AppTheme.primary : AppTheme.secondary)
                        : Colors.transparent,
                  ),
                  child: const Text('INITIATE SEQUENCE', style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  )),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedRole == id;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : AppTheme.surfaceLow,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 16,
                    spreadRadius: 2,
                  )
                ]
              : AppTheme.glassmorphismShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.1) : AppTheme.surfaceLow,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? color : AppTheme.textSecondary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                  )),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  )),
                ],
              ),
            ),
            if (isSelected) 
              Icon(Icons.check_circle, color: color)
          ],
        ),
      ),
    );
  }
}
