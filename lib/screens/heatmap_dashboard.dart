import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ai_scanner_screen.dart';
import 'smart_matcher_screen.dart';
import '../services/auth_service.dart';

class HeatmapDashboard extends StatelessWidget {
  const HeatmapDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Background "Heatmap" representation
          Positioned.fill(
            child: _buildSimulatedMap(),
          ),
          
          // Foreground UI
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                const SizedBox(height: 16),
                _buildMetricsRow(),
                const Spacer(),
                _buildAIPriorityDrawer(context),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AIScannerScreen()));
        },
        backgroundColor: AppTheme.secondary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.document_scanner),
        label: const Text('DIGITIZE FIELD REPORT', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _buildSimulatedMap() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
      ),
      child: Stack(
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: GridPainter(),
          ),
          // Fake Heat zones
          Positioned(
            top: 200,
            left: 100,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppTheme.urgencyHigh.withValues(alpha: 0.6), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            top: 350,
            right: 50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppTheme.urgencyMedium.withValues(alpha: 0.4), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.hub, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text('AIDWISE CORE', style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                fontSize: 18,
                shadows: [Shadow(color: AppTheme.primary.withValues(alpha: 0.5), blurRadius: 10)],
              )),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.urgencyLow.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.urgencyLow.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: AppTheme.urgencyLow, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                const Text('SYSTEM ONLINE', style: TextStyle(color: AppTheme.urgencyLow, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.textSecondary, size: 20),
            onPressed: () => AuthService().signOut(),
          )
        ],
      ),
    );
  }

  Widget _buildMetricsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: [
          Expanded(child: _buildMetricCard('Unprocessed\nReports', '12', AppTheme.secondary)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricCard('Critical\nHotspots', '3', AppTheme.urgencyHigh)),
          const SizedBox(width: 12),
          Expanded(child: _buildMetricCard('Active\nVolunteers', '84', AppTheme.primary)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String count, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: AppTheme.glassmorphismShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(count, style: TextStyle(
            color: color, 
            fontSize: 24, 
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: color.withValues(alpha: 0.5), blurRadius: 10)]
          )),
        ],
      ),
    );
  }

  Widget _buildAIPriorityDrawer(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        border: const Border(top: BorderSide(color: AppTheme.surfaceLow)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, -5))
        ],
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 20),
              const SizedBox(width: 10),
              const Text('AI PRIORITY RANKINGS', style: TextStyle(
                color: AppTheme.primary, 
                fontWeight: FontWeight.bold, 
                letterSpacing: 1.5,
              )),
            ],
          ),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('reports').where('status', isEqualTo: 'Open').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Text('No active hotspots detected.', style: TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic)),
                );
              }
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  String urgencyStr = data['urgency'] ?? 'Medium';
                  Color uColor = urgencyStr == 'High' ? AppTheme.urgencyHigh : AppTheme.urgencyMedium;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: _buildHotspotRow(
                      context, 
                      data['location'] ?? 'Unknown Location', 
                      data['type'] ?? 'General Need', 
                      '98%', // Mock AI confidence
                      uColor,
                      doc.id
                    ),
                  );
                }).toList(),
              );
            }
          ),
          const SizedBox(height: 24), // Padding for FAB
        ],
      ),
    );
  }

  Widget _buildHotspotRow(BuildContext context, String location, String need, String confidence, Color urgencyColor, String reportId) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => SmartMatcherScreen(reportId: reportId)));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.surfaceLow),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: urgencyColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: urgencyColor, blurRadius: 5)]),
                    ),
                    const SizedBox(width: 8),
                    Text(location, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Need: $need', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: Text(confidence, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = const Color(0xFF1E1E1E)
      ..strokeWidth = 1.0;

    double step = 30.0;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
