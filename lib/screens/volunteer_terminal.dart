import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class VolunteerTerminalScreen extends StatelessWidget {
  const VolunteerTerminalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('FIELD TERMINAL', style: TextStyle(fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.w800, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.urgencyHigh.withValues(alpha: 0.1),
                border: Border.all(color: AppTheme.urgencyHigh.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.priority_high, color: AppTheme.urgencyHigh, size: 20),
                  const SizedBox(width: 8),
                  Text('EMERGENCY MISSION', style: TextStyle(
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
            const SizedBox(height: 32),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: Stack(
                children: [
                   Center(child: Icon(Icons.map, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.2))),
                   // Pseudo Map path
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
      ),
    );
  }

  Widget _buildSwipeToAccept() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: AppTheme.surfaceLow,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Stack(
        children: [
          const Center(
            child: Text('>> SLIDE TO ACCEPT >>', style: TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            )),
          ),
          Positioned(
            left: 4, top: 4, bottom: 4,
            child: Container(
              width: 56,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(28),
                boxShadow: AppTheme.cyanGlow,
              ),
              child: const Icon(Icons.arrow_forward, color: Colors.black),
            ),
          )
        ],
      ),
    );
  }
}
