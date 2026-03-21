import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class VolunteerTerminalScreen extends StatefulWidget {
  const VolunteerTerminalScreen({super.key});

  @override
  State<VolunteerTerminalScreen> createState() => _VolunteerTerminalScreenState();
}

class _VolunteerTerminalScreenState extends State<VolunteerTerminalScreen> {
  bool _missionAccepted = false;

  void _acceptMission() {
    setState(() {
      _missionAccepted = true;
    });

    // Show success and drop them back to dashboard
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context); // Return to Dashboard
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primary,
            content: const Text('MISSION STARTED! Navigate safely.', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    });
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
      body: _missionAccepted ? _buildSuccessState() : _buildActiveMissionState(),
    );
  }

  Widget _buildActiveMissionState() {
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
          const Text('Deliver 50 Blankets', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1)),
          const SizedBox(height: 8),
          Text('Downtown Shelter - 1.2km away', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
          
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology, color: AppTheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('You were selected because you are the only logistics volunteer with a truck within 2 miles.', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.surfaceLow),
            ),
            child: Stack(
              children: [
                 Center(child: Icon(Icons.map, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.2))),
                 Positioned(
                   left: 20, top: 20,
                   child: Icon(Icons.my_location, color: AppTheme.primary),
                 ),
                 Positioned(
                   right: 20, bottom: 20,
                   child: Icon(Icons.location_on, color: AppTheme.urgencyHigh, size: 32),
                 ),
                 Align(
                   alignment: Alignment.bottomCenter,
                   child: Container(
                     margin: const EdgeInsets.only(bottom: 12),
                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                     decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                     child: const Text('Show Route', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                   ),
                 )
              ],
            ),
          ),
          const Spacer(),
          _buildSwipeToAccept(),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, color: AppTheme.primary, size: 80),
          const SizedBox(height: 24),
          Text('MISSION ACCEPTED', style: TextStyle(
            color: AppTheme.primary, 
            fontSize: 24, 
            fontWeight: FontWeight.bold, 
            letterSpacing: 2,
            shadows: [Shadow(color: AppTheme.primary.withValues(alpha: 0.5), blurRadius: 10)]
          )),
          const SizedBox(height: 8),
          Text('Navigating to destination...', style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
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
