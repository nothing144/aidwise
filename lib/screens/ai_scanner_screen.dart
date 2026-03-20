import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AIScannerScreen extends StatefulWidget {
  const AIScannerScreen({super.key});

  @override
  State<AIScannerScreen> createState() => _AIScannerScreenState();
}

class _AIScannerScreenState extends State<AIScannerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isExtracting = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    
    // Simulate extraction after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isExtracting = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // true black for camera background
      body: Stack(
        children: [
          // Simulated Camera Viewfinder
          Positioned.fill(
            child: Opacity(
              opacity: 0.5,
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
                _buildScannerOverlay(),
                const Spacer(),
                if (_isExtracting) _buildExtractionPanel(),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 16),
                const SizedBox(width: 8),
                Text('AI DIGITIZER', style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  shadows: [Shadow(color: AppTheme.primary.withValues(alpha: 0.5), blurRadius: 10)]
                )),
              ],
            ),
          ),
          const SizedBox(width: 48), // balance
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return Center(
      child: Container(
        width: 300,
        height: 400,
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5), width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              children: [
                Positioned(
                  top: _controller.value * 380,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      boxShadow: [
                        BoxShadow(color: AppTheme.primary.withValues(alpha: 0.8), blurRadius: 10, spreadRadius: 2)
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
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
          Text('DATA EXTRACTED', style: TextStyle(color: AppTheme.textSecondary, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          _buildExtractedField('Location', 'Downtown Shelter (Zone 4)'),
          const SizedBox(height: 12),
          _buildExtractedField('Need', '50 Blankets & 2 Medics'),
          const SizedBox(height: 12),
          _buildExtractedField('Urgency', 'HIGH (Red)', color: AppTheme.urgencyHigh),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                // Confirm action
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('CONFIRM & DISPATCH AI', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
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
              color: color ?? AppTheme.primary,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: (color ?? AppTheme.primary).withValues(alpha: 0.5), blurRadius: 10)]
            )),
          ),
        ),
      ],
    );
  }
}
