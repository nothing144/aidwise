import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'volunteer_terminal.dart';
import '../services/auth_service.dart';

class VolunteerDashboardScreen extends StatelessWidget {
  const VolunteerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('MISSION BOARD', style: TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => AuthService().signOut()),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Hello, Volunteer', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('Status: ON DUTY', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, shadows: [Shadow(color: AppTheme.primary.withValues(alpha: 0.5), blurRadius: 10)])),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.2), shape: BoxShape.circle, border: Border.all(color: AppTheme.primary)),
                  child: const Text('98', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 20)),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            const Text('AI PRIORITIZED FOR YOU', style: TextStyle(color: AppTheme.urgencyHigh, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            
            _buildMissionCard(
              context: context,
              title: 'Deliver 50 Blankets',
              location: 'Downtown Shelter',
              distance: '1.2km away',
              urgencyInfo: 'Critical Priority (AI Assigned)',
              color: AppTheme.urgencyHigh,
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const VolunteerTerminalScreen()));
              }
            ),
            
            const SizedBox(height: 32),
            const Text('OPEN MISSIONS NEARBY', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            
            _buildMissionCard(
              context: context,
              title: 'Medical Supply Transport',
              location: 'Eastside Clinic',
              distance: '3.4km away',
              urgencyInfo: 'Medium Priority',
              color: AppTheme.urgencyMedium,
              onTap: () {
                // In a real app, this would pass completely different data to the terminal
              }
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionCard({
    required BuildContext context,
    required String title,
    required String location,
    required String distance,
    required String urgencyInfo,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.5)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, color: color, size: 16),
                const SizedBox(width: 4),
                Text('$location • $distance', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(urgencyInfo, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}
