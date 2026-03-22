import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class SmartMatcherScreen extends StatefulWidget {
  final String? reportId;
  final String location;
  final String need;

  const SmartMatcherScreen({
    super.key, 
    this.reportId,
    this.location = 'Downtown Shelter',
    this.need = 'General Need',
  });

  @override
  State<SmartMatcherScreen> createState() => _SmartMatcherScreenState();
}

class _SmartMatcherScreenState extends State<SmartMatcherScreen> {
  bool _isDispatching = false;

  void _dispatch() async {
    setState(() {
      _isDispatching = true;
    });

    try {
      // 1. Find a Volunteer
      final volunteers = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'Volunteer').limit(1).get();
      if (volunteers.docs.isEmpty) {
        throw Exception('No registered volunteers found! Please create a Volunteer account first.');
      }
      final volunteerId = volunteers.docs.first.id;

      // 2. Fetch the actual report data
      String location = 'Downtown Shelter';
      String need = 'General Need';
      double latitude = 28.6139;
      double longitude = 77.2090;

      if (widget.reportId != null) {
        final reportDoc = await FirebaseFirestore.instance.collection('reports').doc(widget.reportId).get();
        if (reportDoc.exists) {
          location = reportDoc.data()?['location'] ?? location;
          need = reportDoc.data()?['type'] ?? need;
          latitude = reportDoc.data()?['latitude'] ?? latitude;
          longitude = reportDoc.data()?['longitude'] ?? longitude;
        }
      }

      // 3. Create the Mission
      await FirebaseFirestore.instance.collection('missions').add({
        'title': 'AI Dispatched: $need',
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'assignedVolunteerId': volunteerId,
        'status': 'Pending',
        'reportId': widget.reportId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. Update Report status so it clears from Heatmap
      if (widget.reportId != null) {
        await FirebaseFirestore.instance.collection('reports').doc(widget.reportId).update({
          'status': 'Assigned'
        });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.urgencyLow,
            content: const Text('VOLUNTEER DISPATCHED SUCCESSFULLY', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.black)),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDispatching = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dispatch Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

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
                  Text(widget.need.toUpperCase(), style: TextStyle(
                    color: AppTheme.urgencyHigh, 
                    fontSize: 24, 
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    shadows: [Shadow(color: AppTheme.urgencyHigh.withValues(alpha: 0.5), blurRadius: 10)],
                  ), textAlign: TextAlign.center,),
                  const SizedBox(height: 4),
                  Text('at ${widget.location}', style: TextStyle(color: AppTheme.primary, fontSize: 16)),
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
                  Row(
                    children: [
                      const Icon(Icons.star, color: AppTheme.urgencyMedium, size: 20),
                      const SizedBox(width: 8),
                      const Text('#1 OPTIMAL SYNERGY MATCH', style: TextStyle(
                        color: AppTheme.urgencyMedium,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      )),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildVolunteerCard('Sarah Chen', '98.5%', '1.2km away', 'Perfect logistical match with requested vehicle. Available now.'),
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
            onPressed: _isDispatching ? null : _dispatch,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              shadowColor: AppTheme.primary.withValues(alpha: 0.5),
              elevation: 10,
            ),
            child: _isDispatching 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3))
                : const Text('DISPATCH VOLUNTEER', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
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
          // Simulated connection
          CustomPaint(
            size: const Size(double.infinity, 200),
            painter: NodePainter(),
          ),
          // Central Node (Crisis)
          Positioned(
            left: 50,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.urgencyHigh, width: 3),
                boxShadow: [BoxShadow(color: AppTheme.urgencyHigh.withValues(alpha: 0.4), blurRadius: 20)],
              ),
              child: const Center(child: Icon(Icons.warning, color: AppTheme.urgencyHigh, size: 32)),
            ),
          ),
          // Volunteer Node (Match)
          Positioned(
            right: 50,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary, width: 3),
                boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.4), blurRadius: 20)],
              ),
              child: const Center(child: Icon(Icons.person, color: AppTheme.primary, size: 32)),
            ),
          ),
          // Connection Line Anim (Static for now)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.urgencyMedium.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.urgencyMedium.withValues(alpha: 0.5)),
            ),
            child: Text('98.5% MATCH', style: TextStyle(color: AppTheme.urgencyMedium, fontWeight: FontWeight.bold, fontSize: 10)),
          )
        ],
      ),
    );
  }

  Widget _buildVolunteerCard(String name, String match, String distance, String aiReason) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.8), width: 2),
        boxShadow: AppTheme.cyanGlow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(match, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w900, fontSize: 22)),
            ],
          ),
          const SizedBox(height: 4),
          Text(distance, style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology, color: AppTheme.secondary, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(aiReason, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.4))),
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
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // Draw straight line between the two nodes
    canvas.drawLine(Offset(90, size.height / 2), Offset(size.width - 90, size.height / 2), paint); 
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
