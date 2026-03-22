import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class AdminLocationPickerScreen extends StatefulWidget {
  final String reportType;
  
  const AdminLocationPickerScreen({super.key, required this.reportType});

  @override
  State<AdminLocationPickerScreen> createState() => _AdminLocationPickerScreenState();
}

class _AdminLocationPickerScreenState extends State<AdminLocationPickerScreen> {
  LatLng? _selectedLocation;
  bool _isSaving = false;

  void _onMapTapped(LatLng position) {
    setState(() {
      _selectedLocation = position;
    });
  }

  Future<void> _confirmAndSave() async {
    if (_selectedLocation == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'type': widget.reportType,
        'location': 'Admin Logged Location',
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'urgency': 'High',
        'status': 'Open',
        'source': 'Admin Dashboard',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); // Pop picker
        Navigator.pop(context); // Pop AI Scanner, return to Heatmap
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primary,
            content: const Text('OFFICE REPORT DIGITIZED & PINNED TO MAP', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isSaving = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('MARK INCIDENT LOCATION', style: TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.black87,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(28.6139, 77.2090), // Default to New Delhi or generic center
              zoom: 12,
            ),
            onTap: _onMapTapped,
            markers: _selectedLocation == null ? {} : {
              Marker(
                markerId: const MarkerId('selected'),
                position: _selectedLocation!,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              )
            },
            mapType: MapType.normal,
            myLocationEnabled: true,
          ),
          if (_selectedLocation == null)
            Positioned(
              top: 20, left: 20, right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary),
                ),
                child: const Text('TAP ANYWHERE ON THE MAP TO DROP A PIN', 
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, letterSpacing: 1.5)
                ),
              ),
            ),
          
          if (_selectedLocation != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _confirmAndSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: _isSaving ? const SizedBox() : const Icon(Icons.push_pin, size: 28),
                    label: _isSaving 
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('CONFIRM LOCATION & DISPATCH', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 14)),
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }
}
