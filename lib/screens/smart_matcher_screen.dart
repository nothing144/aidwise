import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SmartMatcherScreen extends StatelessWidget {
  const SmartMatcherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('AI MATCHING SEQUENCE', style: TextStyle(
          color: AppTheme.textPrimary, 
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 2
        )),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                children: [
                  Text('Resolving Critical Hotspot', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text('DOWNTOWN SHELTER', style: TextStyle(
                    color: AppTheme.urgencyHigh, 
                    fontSize: 28, 
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    shadows: [Shadow(color: AppTheme.urgencyHigh.withValues(alpha: 0.5), blurRadius: 10)],
                  )),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildNodeGraph(),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOP SYNERGY MATCHES', style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  )),
                  const SizedBox(height: 16),
                  _buildVolunteerCard('Alex Johnson', '98.5%', '1.2km away', 'Perfect logistical match with vehicle.'),
                  const SizedBox(height: 12),
                  _buildVolunteerCard('Sam Rivera', '94.2%', '3.0km away', 'High medical experience level.'),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              shadowColor: AppTheme.primary.withValues(alpha: 0.5),
              elevation: 10,
            ),
            child: const Text('DISPATCH SELECTED', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
          ),
        ),
      ),
    );
  }

  Widget _buildNodeGraph() {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Simulated lines
          CustomPaint(
            size: const Size(double.infinity, 200),
            painter: NodePainter(),
          ),
          // Central Node
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.urgencyHigh, width: 3),
              boxShadow: [BoxShadow(color: AppTheme.urgencyHigh.withValues(alpha: 0.4), blurRadius: 20)],
            ),
            child: const Center(child: Icon(Icons.warning, color: AppTheme.urgencyHigh, size: 32)),
          ),
          // Volunteer Nodes
          Positioned(
            left: 50, top: 20,
            child: _buildSmallNode(AppTheme.primary),
          ),
          Positioned(
            right: 60, top: 40,
            child: _buildSmallNode(AppTheme.primary),
          ),
          Positioned(
            left: 100, bottom: 20,
            child: _buildSmallNode(AppTheme.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallNode(Color color) {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color: AppTheme.surfaceLow,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10)],
      ),
      child: Center(child: Icon(Icons.person, color: color, size: 24)),
    );
  }

  Widget _buildVolunteerCard(String name, String match, String distance, String aiReason) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(match, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 4),
          Text(distance, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology, color: AppTheme.secondary, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(aiReason, style: const TextStyle(color: AppTheme.secondary, fontSize: 12))),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class NodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    
    // Draw lines to nodes
    canvas.drawLine(center, const Offset(74, 44), paint); // To left top
    canvas.drawLine(center, Offset(size.width - 84, 64), paint); // To right top
    canvas.drawLine(center, const Offset(124, 180), paint); // To left bottom
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
