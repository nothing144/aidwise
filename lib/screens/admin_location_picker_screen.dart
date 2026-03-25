import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import '../theme/app_theme.dart';

class AdminLocationPickerScreen extends StatefulWidget {
  final String reportType;
  final bool isReturnMode;
  
  const AdminLocationPickerScreen({super.key, required this.reportType, this.isReturnMode = false});

  @override
  State<AdminLocationPickerScreen> createState() => _AdminLocationPickerScreenState();
}

class _AdminLocationPickerScreenState extends State<AdminLocationPickerScreen> {
  LatLng? _selectedLocation;
  bool _isSaving = false;
  bool _isSearching = false;
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapTapped(LatLng position) {
    setState(() {
      _selectedLocation = position;
    });
  }

  Future<void> _searchLocation() async {
    if (_searchController.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    
    setState(() => _isSearching = true);
    try {
      List<Location> locations = await locationFromAddress(_searchController.text.trim());
      if (locations.isNotEmpty) {
        Location loc = locations.first;
        LatLng newPos = LatLng(loc.latitude, loc.longitude);
        setState(() {
          _selectedLocation = newPos;
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newPos, 15));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location not found')));
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _confirmAndSave() async {
    if (_selectedLocation == null) return;

    if (widget.isReturnMode) {
      Navigator.pop(context, _selectedLocation);
      return;
    }

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
            onMapCreated: (controller) => _mapController = controller,
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
            zoomControlsEnabled: false,
          ),
          
          // Custom Search Bar Top Overlay
          Positioned(
            top: 16, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10)],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppTheme.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchLocation(),
                      decoration: InputDecoration(
                        hintText: 'Search city, street, or landmark...',
                        hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5), fontSize: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  _isSearching 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2))
                    : IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, color: AppTheme.primary, size: 16),
                        onPressed: _searchLocation,
                      )
                ],
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
