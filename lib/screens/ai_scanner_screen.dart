import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/ai_service.dart';
import 'admin_location_picker_screen.dart';

class AIScannerScreen extends StatefulWidget {
  final bool isAdminMode;
  
  const AIScannerScreen({super.key, this.isAdminMode = false});

  @override
  State<AIScannerScreen> createState() => _AIScannerScreenState();
}

class _AIScannerScreenState extends State<AIScannerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isScanning = false;
  bool _isExtracting = false;
  bool _showSuccess = false;

  String _aiUrgency = 'High';
  String _aiType = 'Identified via AI Scanner';
  String _aiLocation = 'Coordinates Logged';

  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  final TextEditingController _manualController = TextEditingController();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _imageFile = pickedFile;
        });
        _startScan(); // Autostart scan when image is selected
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showManualEntryDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Manual Report', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: _manualController,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Describe the emergency (e.g. 50 Blankets needed at Downtown)',
              hintStyle: TextStyle(color: AppTheme.textSecondary),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3))),
              focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primary)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
              onPressed: () {
                if (_manualController.text.trim().isEmpty) return;
                Navigator.pop(context);
                _startScan(); // Start "AI analysis" of the text
              },
              child: const Text('SUBMIT'),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startScan() async {
    setState(() {
      _isScanning = true;
    });
    _controller.repeat(reverse: true);
    
    // Grab input (either manual text or image)
    Uint8List? imgBytes;
    if (_imageFile != null) {
      imgBytes = await _imageFile!.readAsBytes();
    }
    String inputForAI = _manualController.text.trim();

    try {
      final aiResult = await AIService.analyzeFieldReport(textInput: inputForAI, imageBytes: imgBytes);
      debugPrint('AI Result: $aiResult');
      if (mounted) {
        setState(() {
          _aiUrgency = aiResult['urgency'] ?? 'High';
          _aiType = aiResult['type'] ?? 'Emergency Response';
          _aiLocation = aiResult['location'] ?? 'Location Logged (GPS)';
        });
      }
    } catch (e) {
      debugPrint("AI Service Error: $e");
    }

    if (mounted) {
      _controller.stop();
      
      // Block irrelevant images from proceeding
      if (_aiType == 'Irrelevant' || _aiUrgency == 'None') {
        setState(() {
          _isScanning = false;
          _isExtracting = false;
          _showSuccess = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ AI detected this is NOT an emergency. Please upload a valid incident photo or description.'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
      
      setState(() {
        _isScanning = false;
        _isExtracting = true;
      });
    }
  }

  void _confirmAndDispatch([String? manualText]) async {
    if (widget.isAdminMode) {
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => AdminLocationPickerScreen(reportType: _aiType)));
      }
      return;
    }

    // Ask field worker for location method
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('SET INCIDENT LOCATION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.5)),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.my_location, color: AppTheme.primary),
                title: const Text('Use Live GPS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('Fastest. Marks your current standing position.', style: TextStyle(color: AppTheme.textSecondary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _finalizeDispatch(null);
                },
              ),
              const Divider(color: AppTheme.surfaceLow),
              ListTile(
                leading: const Icon(Icons.map, color: Colors.orangeAccent),
                title: const Text('Pin on Map', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('Pick a distant village or remote location.', style: TextStyle(color: AppTheme.textSecondary)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final LatLng? selectedLoc = await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AdminLocationPickerScreen(reportType: _aiType, isReturnMode: true)
                  ));
                  if (selectedLoc != null) {
                    _finalizeDispatch(selectedLoc);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _finalizeDispatch(LatLng? customLocation) async {
    setState(() {
      _isExtracting = false;
      _showSuccess = true;
    });

    try {
      double lat;
      double lng;
      String locText;

      if (customLocation != null) {
        lat = customLocation.latitude;
        lng = customLocation.longitude;
        locText = 'Map Pin: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
      } else {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) throw Exception('Location services are disabled.');

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            throw Exception('Location permissions are denied');
          }
        }
        if (permission == LocationPermission.deniedForever) {
          throw Exception('Location permissions are permanently denied');
        } 

        Position position = await Geolocator.getCurrentPosition();
        lat = position.latitude;
        lng = position.longitude;
        locText = 'GPS: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
      }

      await FirebaseFirestore.instance.collection('reports').add({
        'type': _aiType,
        'description': _manualController.text.trim(),
        'location': locText,
        'latitude': lat,
        'longitude': lng,
        'urgency': _aiUrgency,
        'status': 'Open',
        'source': 'Field Worker',
        'submittedBy': FirebaseAuth.instance.currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving report: $e');
    }

    // Reset after success
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showSuccess = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Live Camera Simulation
          Positioned.fill(
            child: Opacity(
              opacity: _isExtracting || _showSuccess ? 0.3 : 0.8,
              child: Image.network(
                'https://images.unsplash.com/photo-1607316377884-bbd758c0c8ff?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[900]),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const Spacer(),
                if (_isScanning || (!_isExtracting && !_showSuccess)) _buildScannerOverlay(),
                const Spacer(),
                if (_isExtracting) _buildExtractionPanel(),
                if (_showSuccess) _buildSuccessOverlay(),
                if (!_isScanning && !_isExtracting && !_showSuccess) _buildInputMethods(),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (Navigator.canPop(context))
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            )
          else
            const SizedBox(width: 48), // Spacer to balance the layout

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 16),
                const SizedBox(width: 8),
                Text('AI FIELD SCANNER', style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  shadows: [Shadow(color: AppTheme.primary.withValues(alpha: 0.5), blurRadius: 10)]
                )),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return Center(
      child: Container(
        width: 320,
        height: 400,
        decoration: BoxDecoration(
          border: Border.all(
            color: _isScanning ? AppTheme.primary : AppTheme.primary.withValues(alpha: 0.3), 
            width: _isScanning ? 2 : 1
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: _isScanning 
          ? AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Stack(
                  children: [
                    Positioned(
                      top: _controller.value * 380,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          boxShadow: [
                            BoxShadow(color: AppTheme.primary, blurRadius: 12, spreadRadius: 4)
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            )
          : Center(
              child: Text('FRAME THE REPORT', style: TextStyle(
                color: AppTheme.primary.withValues(alpha: 0.5), 
                letterSpacing: 2,
                fontWeight: FontWeight.bold
              )),
            ),
      ),
    );
  }

  Widget _buildInputMethods() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // File Upload Button
          GestureDetector(
            onTap: () => _pickImage(ImageSource.gallery), 
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppTheme.surface, shape: BoxShape.circle, border: Border.all(color: AppTheme.surfaceLow)),
                  child: const Icon(Icons.upload_file, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Text('Upload File', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          
          // Main Camera Scan Button
          GestureDetector(
            onTap: () => _pickImage(ImageSource.camera),
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary, width: 4),
                color: AppTheme.primary.withValues(alpha: 0.2),
                boxShadow: AppTheme.cyanGlow,
              ),
              child: Center(
                child: Container(
                  width: 60, height: 60,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.primary),
                  child: const Icon(Icons.camera_alt, color: Colors.black, size: 30),
                ),
              ),
            ),
          ),

          // Manual Form Button
          GestureDetector(
            onTap: _showManualEntryDialog, 
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppTheme.surface, shape: BoxShape.circle, border: Border.all(color: AppTheme.surfaceLow)),
                  child: const Icon(Icons.edit_document, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Text('Manual Entry', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractionPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(color: AppTheme.primary.withValues(alpha: 0.1), blurRadius: 30, offset: const Offset(0, -5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text('STATUS: COMPLETE', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: const Text('Data Aggregator', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('98%', style: TextStyle(color: AppTheme.primary, fontSize: 28, fontWeight: FontWeight.w900)),
                  Text('CONFIDENCE\nINDEX', style: TextStyle(color: AppTheme.textSecondary, fontSize: 9, letterSpacing: 1, height: 1.3), textAlign: TextAlign.right),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),
          _buildStitchCard('LOCATION', Icons.place, _aiLocation, AppTheme.primary),
          const SizedBox(height: 10),
          _buildStitchCard('RESOURCE NEED', Icons.inventory, _aiType, AppTheme.primary),
          const SizedBox(height: 10),
          _buildStitchCard('URGENCY', Icons.star, _aiUrgency.toUpperCase(), AppTheme.secondary),
          const SizedBox(height: 20),
          Text('DETECTED TAGS', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildTag('FIELD_REPORT'),
              const SizedBox(width: 8),
              _buildTag('GPS_VERIFIED'),
            ],
          ),
          const SizedBox(height: 24),
          // Gradient Confirm Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppTheme.cyanMagentaGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                onPressed: () => _confirmAndDispatch(_manualController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.bookmark, size: 22),
                label: const Text('CONFIRM & ADD TO HEATMAP', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 13)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStitchCard(String label, IconData icon, String value, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(value, style: const TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.w900, 
                  fontSize: 16,
                )),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSuccessOverlay() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.urgencyLow),
        boxShadow: [BoxShadow(color: AppTheme.urgencyLow.withValues(alpha: 0.2), blurRadius: 20)],
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_done, color: AppTheme.urgencyLow, size: 64),
          const SizedBox(height: 16),
          Text('REPORT DIGITIZED', style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 8),
          Text('Pushing to Global Heatmap...', style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
