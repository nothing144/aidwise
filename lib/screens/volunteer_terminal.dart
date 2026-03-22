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

  void _acceptMission() {
    setState(() {
      _missionAccepted = true;
    });
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

      // 2. Mark Report as Resolved (Removes it from the global heatmap if it wasn't already)
      if (widget.reportId != null) {
        await FirebaseFirestore.instance.collection('reports').doc(widget.reportId).update({
          'status': 'Resolved'
        });
      }

      if (mounted) {
        Navigator.pop(context); // Drop back to dashboard
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primary,
            content: const Text('MISSION ACCOMPLISHED! Excellent work.', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
        title: const Text('PRIORITY MISSION', style: TextStyle(fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.w800, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.urgencyHigh.withValues(alpha: 0.1),
              border: Border.all(color: AppTheme.urgencyHigh.withValues(alpha: 0.8), width: 2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: AppTheme.urgencyHigh.withValues(alpha: 0.3), blurRadius: 20)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.priority_high, color: AppTheme.urgencyHigh, size: 20),
                const SizedBox(width: 8),
                Text('CRITICAL NEED', style: TextStyle(
                  color: AppTheme.urgencyHigh, fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  shadows: [Shadow(color: AppTheme.urgencyHigh.withValues(alpha: 0.8), blurRadius: 10)],
                )),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(widget.title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1)),
          const SizedBox(height: 8),
          Text(widget.location, style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
          
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
          const Spacer(),
          Column(
            children: [
              _buildSwipeToAccept(),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _declineMission,
                child: const Text('DECLINE MISSION', style: TextStyle(color: AppTheme.textSecondary, letterSpacing: 2, fontWeight: FontWeight.bold)),
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

  Widget _buildSwipeToAccept() {
    return GestureDetector(
      onPanUpdate: (details) {
        if (details.delta.dx > 10) {
          _acceptMission();
        }
      },
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppTheme.primary),
          boxShadow: AppTheme.cyanGlow,
        ),
        child: Stack(
          children: [
             Center(
              child: Text('>> SWIPE RIGHT TO ACCEPT >>', style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                shadows: [Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 5)],
              )),
            ),
            Positioned(
              left: 4, top: 4, bottom: 4,
              child: Container(
                width: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(Icons.double_arrow, color: Colors.black),
              ),
            )
          ],
        ),
      ),
    );
  }
}
