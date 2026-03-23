import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_theme.dart';
import 'smart_matcher_screen.dart';

class ReportDetailMapScreen extends StatelessWidget {
  final String reportId;
  final String reportType;
  final String location;
  final double latitude;
  final double longitude;
  final String urgency;

  const ReportDetailMapScreen({
    super.key,
    required this.reportId,
    required this.reportType,
    required this.location,
    required this.latitude,
    required this.longitude,
    this.urgency = 'High',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('INCIDENT DETAIL', style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2,
        )),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Info Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: urgency == 'High' ? AppTheme.urgencyHigh : AppTheme.urgencyMedium,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: urgency == 'High' ? AppTheme.urgencyHigh : AppTheme.urgencyMedium, blurRadius: 6)],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(reportType.toUpperCase(), style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1,
                      )),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(location, style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Text('Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Map showing ONLY this problem's pin
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(latitude, longitude),
                    zoom: 15,
                  ),
                  markers: {
                    Marker(
                      markerId: MarkerId(reportId),
                      position: LatLng(latitude, longitude),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        urgency == 'High' ? BitmapDescriptor.hueRed : BitmapDescriptor.hueOrange,
                      ),
                      infoWindow: InfoWindow(title: reportType, snippet: location),
                    )
                  },
                  mapType: MapType.normal,
                  myLocationEnabled: true,
                  zoomControlsEnabled: false,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Dispatch Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => SmartMatcherScreen(
                    reportId: reportId,
                    location: location,
                    need: reportType,
                  )));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 10,
                ),
                icon: const Icon(Icons.send, size: 24),
                label: const Text('DISPATCH VOLUNTEER', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
