import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import '../services/offline_nav_service.dart';
import '../services/offline_sync_service.dart';

class VolunteerOfflineMissionScreen extends StatefulWidget {
  final Map<String, dynamic> missionData;

  const VolunteerOfflineMissionScreen({super.key, required this.missionData});

  @override
  State<VolunteerOfflineMissionScreen> createState() => _VolunteerOfflineMissionScreenState();
}

class _VolunteerOfflineMissionScreenState extends State<VolunteerOfflineMissionScreen> {
  Position? _currentPosition;
  String _routingString = "Calculating...";
  double _distanceInMeters = 0;
  double _bearing = 0;
  bool _isCompleting = false;

  double get _targetLat => (widget.missionData['latitude'] as num?)?.toDouble() ?? 0.0;
  double get _targetLng => (widget.missionData['longitude'] as num?)?.toDouble() ?? 0.0;
  bool get _hasValidCoords => _targetLat != 0.0 && _targetLng != 0.0;

  @override
  void initState() {
    super.initState();
    if (_hasValidCoords) {
      _startLocationTracking();
    }
  }

  Future<void> _startLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 5),
    ).listen((Position position) {
      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        _routingString = OfflineNavService.getRoutingString(position.latitude, position.longitude, _targetLat, _targetLng);
        _distanceInMeters = Geolocator.distanceBetween(position.latitude, position.longitude, _targetLat, _targetLng);
        _bearing = Geolocator.bearingBetween(position.latitude, position.longitude, _targetLat, _targetLng);
      });
    });
  }

  void _confirmCompletion() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('CONFIRM MISSION COMPLETE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
        content: const Text(
          'This will broadcast a status update through the P2P mesh network so the Admin knows this mission has been completed.\n\nAre you sure?',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _markCompleted();
            },
            child: const Text('CONFIRM', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _markCompleted() async {
    setState(() => _isCompleting = true);

    try {
      String meshId = widget.missionData['_meshId'] ?? '';
      await OfflineSyncService().sendStatusUpdateViaMesh(meshId, 'Completed');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Mission Completed! Status update broadcasting via mesh.', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCompleting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String urgency = widget.missionData['urgency'] ?? 'Critical';
    String description = widget.missionData['description'] ?? 'No Description provided';
    String locationText = widget.missionData['location'] ?? 'Unknown Location';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('OFFLINE DISPATCH', style: TextStyle(color: AppTheme.urgencyHigh, fontWeight: FontWeight.bold, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Compass/Radar OR text-only fallback
              Expanded(
                child: _hasValidCoords ? _buildCompassUI() : _buildNoCoordsFallback(locationText),
              ),

              // Distance / Bearing Text (only if valid coords)
              if (_hasValidCoords)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3))),
                  child: Column(
                    children: [
                      Text(_routingString, style: const TextStyle(color: AppTheme.primary, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1, shadows: [Shadow(color: AppTheme.primary, blurRadius: 10)])),
                      const SizedBox(height: 8),
                      Text('${(_distanceInMeters / 1000).toStringAsFixed(2)} KILOMETERS AWAY', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, letterSpacing: 2)),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Mission Details
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppTheme.urgencyHigh.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.urgencyHigh)),
                          child: Text(urgency.toUpperCase(), style: const TextStyle(color: AppTheme.urgencyHigh, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blueAccent)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bluetooth, color: Colors.blueAccent, size: 10),
                              SizedBox(width: 4),
                              Text('P2P DISPATCH', style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_hasValidCoords)
                      Text('TARGET: ${_targetLat.toStringAsFixed(4)}, ${_targetLng.toStringAsFixed(4)}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5))
                    else
                      Text('LOCATION: $locationText', style: const TextStyle(color: AppTheme.primary, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(description, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5)),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              // Mark Completed Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isCompleting ? null : _confirmCompletion,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  icon: _isCompleting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle, color: Colors.white),
                  label: Text(
                    _isCompleting ? 'BROADCASTING...' : 'MARK COMPLETED',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompassUI() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Concentric radar circles
          Container(
            width: 280, height: 280,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2), width: 2)),
          ),
          Container(
            width: 200, height: 200,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 2)),
          ),
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5), width: 2)),
          ),
          // Arrow pointing to destination
          if (_currentPosition != null)
            Transform.rotate(
              angle: _bearing * (math.pi / 180),
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Icon(Icons.navigation, color: AppTheme.urgencyHigh, size: 48),
                ),
              ),
            ),
          // Center dot (User position)
          Container(
            width: 16, height: 16,
            decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppTheme.primary, blurRadius: 10, spreadRadius: 2)]),
          )
        ],
      ),
    );
  }

  /// Shown when GPS coordinates are missing — volunteer uses text description to navigate
  Widget _buildNoCoordsFallback(String locationText) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.orange.withValues(alpha: 0.4), width: 2),
            ),
            child: const Icon(Icons.location_off, color: Colors.orange, size: 64),
          ),
          const SizedBox(height: 24),
          const Text('NO GPS COORDINATES', style: TextStyle(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Text('USE DESCRIPTION TO NAVIGATE', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(locationText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
