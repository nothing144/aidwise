import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class VolunteerTerminalScreen extends StatefulWidget {
  const VolunteerTerminalScreen({super.key});

  @override
  State<VolunteerTerminalScreen> createState() => _VolunteerTerminalScreenState();
}

class _VolunteerTerminalScreenState extends State<VolunteerTerminalScreen> with SingleTickerProviderStateMixin {
  bool _missionReceived = false;
  bool _missionAccepted = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    
    // Simulate receiving a mission after 3 seconds of being "On Duty"
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _missionReceived = true;
        });
        _pulseController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _acceptMission() {
    setState(() {
      _missionAccepted = true;
    });
    _pulseController.stop();

    // Show success and auto close demo
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context); // Return to role selector
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('FIELD TERMINAL', style: TextStyle(fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.w800, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: !_missionReceived 
          ? _buildIdleState()
          : (_missionAccepted ? _buildSuccessState() : _buildActiveMissionState()),
    );
  }

  Widget _buildIdleState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withValues(alpha: 0.1),
              boxShadow: AppTheme.cyanGlow,
            ),
            child: const Icon(Icons.radar, color: AppTheme.primary, size: 64),
          ),
          const SizedBox(height: 32),
          Text('ON DUTY', style: TextStyle(
            color: AppTheme.textPrimary, 
            fontSize: 24, 
            fontWeight: FontWeight.bold, 
            letterSpacing: 4,
            shadows: [Shadow(color: AppTheme.primary.withValues(alpha: 0.5), blurRadius: 10)]
          )),
          const SizedBox(height: 8),
          Text('Awaiting AI Dispatch...', style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildActiveMissionState() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.urgencyHigh.withValues(alpha: 0.1),
                  border: Border.all(
                    color: AppTheme.urgencyHigh.withValues(alpha: 0.5 + (_pulseController.value * 0.5)),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.urgencyHigh.withValues(alpha: _pulseController.value * 0.3),
                      blurRadius: 20,
                    )
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.priority_high, color: AppTheme.urgencyHigh, size: 20),
                    const SizedBox(width: 8),
                    Text('URGENT MISSION DISPATCHED', style: TextStyle(
                      color: AppTheme.urgencyHigh, fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      shadows: [Shadow(color: AppTheme.urgencyHigh.withValues(alpha: 0.8), blurRadius: 10)],
                    )),
                  ],
                ),
              );
            }
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
    // A gamified accepting button
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
