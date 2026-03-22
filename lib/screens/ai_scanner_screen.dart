import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';

class AIScannerScreen extends StatefulWidget {
  const AIScannerScreen({super.key});

  @override
  State<AIScannerScreen> createState() => _AIScannerScreenState();
}

class _AIScannerScreenState extends State<AIScannerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isScanning = false;
  bool _isExtracting = false;
  bool _showSuccess = false;

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

  void _startScan() {
    setState(() {
      _isScanning = true;
    });
    _controller.repeat(reverse: true);
    
    // Simulate AI extraction taking 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _controller.stop();
        setState(() {
          _isScanning = false;
          _isExtracting = true;
        });
      }
    });
  }

  void _confirmAndDispatch([String? manualText]) async {
    setState(() {
      _isExtracting = false;
      _showSuccess = true;
    });

    try {
      // 1. Request Location Permissions and Grab GPS
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

      // 2. Push to Firestore with GPS Coordinates!
      String reportType = manualText != null && manualText.isNotEmpty 
          ? manualText 
          : 'Emergency Response (Photo Analyzed)';

      await FirebaseFirestore.instance.collection('reports').add({
        'type': reportType,
        'location': 'Location Logged (GPS)',
        'latitude': position.latitude,
        'longitude': position.longitude,
        'urgency': 'High',
        'status': 'Open',
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
        color: AppTheme.surface.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        border: const Border(top: BorderSide(color: AppTheme.primary, width: 2)),
        boxShadow: [
          BoxShadow(color: AppTheme.primary.withValues(alpha: 0.2), blurRadius: 30, offset: const Offset(0, -5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text('DATA EXTRACTED SUCCESSFULLY', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 20),
          _buildExtractedField('Location', 'Sector 4 Shelter (Coordinates logged)'),
          const SizedBox(height: 12),
          _buildExtractedField('Need', '50 Blankets & 2 Medics'),
          const SizedBox(height: 12),
          _buildExtractedField('Urgency', 'URGENT (AI Triage)', color: AppTheme.urgencyHigh),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => _confirmAndDispatch(_manualController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('PUSH TO COMMAND MAP', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildExtractedField(String label, String value, {Color? color}) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey))),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
            ),
            child: Text(value, style: TextStyle(
              color: color ?? Colors.white,
              fontWeight: FontWeight.bold,
              shadows: [if (color != null) Shadow(color: color.withValues(alpha: 0.5), blurRadius: 10)]
            )),
          ),
        ),
      ],
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
