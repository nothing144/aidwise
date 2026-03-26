import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class VolunteerTerminalScreen extends StatefulWidget {
  final String missionId;
  final String title;
  final String location;
  final double latitude;
  final double longitude;
  final String? reportId;

  const VolunteerTerminalScreen({
    super.key,
    required this.missionId,
    required this.title,
    required this.location,
    required this.latitude,
    required this.longitude,
    this.reportId,
  });

  @override
  State<VolunteerTerminalScreen> createState() => _VolunteerTerminalScreenState();
}

class _VolunteerTerminalScreenState extends State<VolunteerTerminalScreen> {
  bool _missionAccepted = false;
  bool _isCompleting = false;
  String _reportUrgency = 'HIGH';
  String _reportType = 'GENERAL';
  int _impactXP = 300;

  @override
  void initState() {
    super.initState();
    _loadReportDetails();
  }

  Future<void> _loadReportDetails() async {
    if (widget.reportId != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('reports').doc(widget.reportId).get();
        if (doc.exists && mounted) {
          final data = doc.data()!;
          String urg = (data['urgency'] ?? 'High').toString().toUpperCase();
          String type = (data['type'] ?? 'General').toString().toUpperCase();
          int xp = urg == 'CRITICAL' ? 500 : (urg == 'HIGH' ? 300 : (urg == 'MEDIUM' ? 150 : 50));
          setState(() {
            _reportUrgency = urg;
            _reportType = type;
            _impactXP = xp;
          });
        }
      } catch (e) {
        debugPrint('Error loading report details: $e');
      }
    }
  }

  void _declineMission() async {
    try {
      // 1. Delete this specific failed mission document to clean up DB
      await FirebaseFirestore.instance.collection('missions').doc(widget.missionId).delete();

      // 2. Mark the parent Report back to Open so the Admin sees it on the Heatmap again
      if (widget.reportId != null) {
        await FirebaseFirestore.instance.collection('reports').doc(widget.reportId).update({
          'status': 'Open'
        });
      }

      if (mounted) {
        Navigator.pop(context); // Return to Dashboard
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mission Declined.'), backgroundColor: Colors.white24));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _openInGoogleMaps() async {
    final Uri url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${widget.latitude},${widget.longitude}');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Maps APP')));
    }
  }

  void _completeMission() async {
    setState(() { _isCompleting = true; });

    try {
      // 1. Mark Mission as Completed
      await FirebaseFirestore.instance.collection('missions').doc(widget.missionId).update({
        'status': 'Completed'
      });

      // 2. Mark Report as 'Completed' (awaiting Field Worker verification to become 'Resolved')
      if (widget.reportId != null) {
        await FirebaseFirestore.instance.collection('reports').doc(widget.reportId).update({
          'status': 'Completed'
        });
      }

      if (mounted) {
        Navigator.pop(context); // Drop back to dashboard
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primary,
            content: const Text('MISSION ACCOMPLISHED! Awaiting field verification.', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isCompleting = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, color: AppTheme.secondary, size: 18),
            const SizedBox(width: 8),
            const Text('MISSION TERMINAL', style: TextStyle(fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.w800, color: AppTheme.secondary)),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 12),
                const SizedBox(width: 4),
                Text('AI MATCH', style: TextStyle(color: AppTheme.primary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ],
            ),
          )
        ],
      ),
      body: _missionAccepted ? _buildActiveMissionState() : _buildBriefingState(),
    );
  }

  Widget _buildBriefingState() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ACTIVE DIRECTIVE', style: TextStyle(color: AppTheme.primary, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(widget.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
          const SizedBox(height: 4),
          Text(widget.location, style: const TextStyle(fontSize: 16, color: AppTheme.primary)),
          
          const SizedBox(height: 20),

          // Mission Detail Card (Stitch-style)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.stitchCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(border: Border.all(color: _reportUrgency == 'CRITICAL' ? AppTheme.urgencyHigh : AppTheme.textSecondary.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(4)),
                      child: Text('PRIORITY $_reportUrgency', style: TextStyle(color: _reportUrgency == 'CRITICAL' || _reportUrgency == 'HIGH' ? AppTheme.urgencyHigh : Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(4)),
                      child: Text(_reportType, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Dispatch to ${widget.location}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('AI-matched task requiring $_reportType response at this location.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(widget.latitude, widget.longitude),
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('target'),
                    position: LatLng(widget.latitude, widget.longitude),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
                  )
                },
                mapType: MapType.normal,
                zoomControlsEnabled: false,
                myLocationEnabled: true,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.stitchCard,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PRIORITY', style: TextStyle(color: AppTheme.textSecondary, fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(_reportUrgency, style: TextStyle(color: _reportUrgency == 'CRITICAL' ? AppTheme.urgencyHigh : AppTheme.primary, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.stitchCard,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('IMPACT XP', style: TextStyle(color: AppTheme.textSecondary, fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('+$_impactXP UNIT', style: const TextStyle(color: AppTheme.secondary, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            children: [
              Container(
                height: 64,
                decoration: BoxDecoration(
                  gradient: AppTheme.cyanMagentaGradientSubtle,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppTheme.cyanGlow,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, color: Colors.black),
                        onPressed: () {
                          setState(() { _missionAccepted = true; });
                        },
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text('SLIDE TO ACCEPT MISSION', style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          fontSize: 12,
                        )),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _declineMission,
                    child: const Text('REJECT DIRECTIVE', style: TextStyle(color: AppTheme.textSecondary, letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('REQUEST SUPPORT', style: TextStyle(color: AppTheme.textSecondary, letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildActiveMissionState() {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(widget.latitude, widget.longitude),
            zoom: 18,
          ),
          markers: {
            Marker(
              markerId: const MarkerId('target'),
              position: LatLng(widget.latitude, widget.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              infoWindow: InfoWindow(title: widget.title, snippet: 'Destination'),
            )
          },
          mapType: MapType.normal,
          myLocationEnabled: true,
        ),
        Positioned(
          top: 20, left: 20, right: 20,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('NAVIGATING TO', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                Text(widget.location, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _openInGoogleMaps,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: Colors.black54,
                    ),
                    icon: const Icon(Icons.navigation),
                    label: const Text('OPEN IN NATIVE MAPS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _isCompleting ? null : _completeMission,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 10,
                    ),
                    icon: _isCompleting ? const SizedBox() : const Icon(Icons.check_circle, size: 28),
                    label: _isCompleting 
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('MISSION ACCOMPLISHED', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        )
      ],
    );
  }
}
