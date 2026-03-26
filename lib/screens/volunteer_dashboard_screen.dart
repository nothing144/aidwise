import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
                      builder: (ctx, snap) {
                        if (snap.hasError) return const Text('Hello, Volunteer', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white));
                        if (snap.connectionState == ConnectionState.waiting) return const Text('Loading...', style: TextStyle(color: Colors.white70));
                        
                        String name = 'Volunteer';
                        if (snap.hasData && snap.data!.exists && snap.data!.data() != null) {
                          final data = snap.data!.data() as Map<String, dynamic>;
                          name = data.containsKey('displayName') ? data['displayName'] : 'Volunteer';
                        }
                        return Text('Hello, $name', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white));
                      },
                    ),
                    const SizedBox(height: 4),
                    Text('Status: ON DUTY', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, shadows: [Shadow(color: AppTheme.primary.withValues(alpha: 0.5), blurRadius: 10)])),
                  ],
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('missions')
                      .where('assignedVolunteerId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                      .where('status', isEqualTo: 'Completed')
                      .snapshots(),
                  builder: (ctx, snap) {
                    int completedCount = snap.data?.docs.length ?? 0;
                    int impactXP = completedCount * 100;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.2), shape: BoxShape.circle, border: Border.all(color: AppTheme.primary)),
                      child: Text('$impactXP', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            const Text('AI PRIORITIZED FOR YOU', style: TextStyle(color: AppTheme.urgencyHigh, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('missions')
                  .where('assignedVolunteerId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                  .where('status', isEqualTo: 'Pending')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator(color: AppTheme.primary);
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Text('Standby... awaiting AI dispatch.', style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic)),
                  );
                }

                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: _buildMissionCard(
                        context: context,
                        title: data['title'] ?? 'Priority Mission',
                        location: data['location'] ?? 'Unknown Location',
                        distance: 'AI Assigned',
                        urgencyInfo: 'Critical Priority',
                        color: AppTheme.urgencyHigh,
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => VolunteerTerminalScreen(
                            missionId: doc.id,
                            title: data['title'] ?? 'Priority Mission',
                            location: data['location'] ?? 'Unknown Location',
                            latitude: data['latitude']?.toDouble() ?? 28.6139,
                            longitude: data['longitude']?.toDouble() ?? 77.2090,
                            reportId: data['reportId'],
                          )));
                        }
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            
            const SizedBox(height: 32),
            const Text('OPEN MISSIONS NEARBY (POOL)', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('missions')
                  .where('status', isEqualTo: 'Open')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox();
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Text('No open missions at this time.', style: TextStyle(color: AppTheme.textSecondary));
                }

                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: _buildMissionCard(
                        context: context,
                        title: data['title'] ?? 'Open Task',
                        location: data['location'] ?? 'Unknown Location',
                        distance: 'Nearby',
                        urgencyInfo: 'Medium Priority',
                        color: AppTheme.urgencyMedium,
                        onTap: () {}
                      ),
                    );
                  }).toList(),
                );
              },
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
