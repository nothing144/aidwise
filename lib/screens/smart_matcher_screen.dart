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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOP 3 PERFECTLY MATCHED\nVOLUNTEERS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, height: 1.3)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('AUTO-\nSCAN', style: TextStyle(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1), textAlign: TextAlign.center),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildVolunteerCard('Agent K', '0.8 MILES AWAY', 'MEDICAL EXPERTISE 98%', AppTheme.primary, Icons.person_search),
                  const SizedBox(height: 12),
                  _buildVolunteerCard('Unit 704', '1.2 MILES AWAY', 'RAPID RESPONSE CERTIFIED', AppTheme.secondary, Icons.person),
                  const SizedBox(height: 12),
                  _buildVolunteerCard('Sarah J', '1.5 MILES AWAY', 'MATCHES REQUIRED LOGISTICS SKILL', AppTheme.urgencyMedium, Icons.groups),
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
          child: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.cyanMagentaGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton.icon(
              onPressed: _isDispatching ? null : _dispatch,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isDispatching 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3))
                  : const Icon(Icons.groups, size: 24),
              label: _isDispatching 
                  ? const Text('DISPATCHING...')
                  : const Text('DISPATCH SELECTED VOLUNTEERS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ),
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

  Widget _buildVolunteerCard(String name, String distance, String skill, Color skillColor, IconData avatarIcon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.stitchCardWithLeftBorder(skillColor),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: skillColor.withValues(alpha: 0.2),
            radius: 24,
            child: Icon(avatarIcon, color: skillColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(distance, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: skillColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: skillColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: skillColor, size: 12),
                      const SizedBox(width: 4),
                      Text(skill, style: TextStyle(color: skillColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ],
                  ),
                )
              ],
            ),
          ),
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
