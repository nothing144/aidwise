import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AIMatchingScreen extends StatefulWidget {
  const AIMatchingScreen({super.key});

  @override
  State<AIMatchingScreen> createState() => _AIMatchingScreenState();
}

class _AIMatchingScreenState extends State<AIMatchingScreen> {
  bool _isMatching = false;
  bool _hasMatched = false;

  void _runMatching() {
    setState(() {
      _isMatching = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isMatching = false;
        _hasMatched = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Intelligent\nResource Allocation', style: TextStyle(
              fontSize: 32, 
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              height: 1.2,
              letterSpacing: -0.5,
            )),
            const SizedBox(height: 16),
            Text('Find the perfect volunteers for your tasks using AI-powered matching.', style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            )),
            const SizedBox(height: 48),
            if (!_hasMatched && !_isMatching) 
              Center(
                child: Column(
                  children: [
                    Icon(Icons.hub, size: 64, color: AppTheme.accent.withOpacity(0.2)),
                    const SizedBox(height: 16),
                    const Text('Ready to analyze 142 volunteers', style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            if (_isMatching)
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    const CircularProgressIndicator(color: AppTheme.accent),
                    const SizedBox(height: 16),
                    Text('Analyzing skills, location, and availability...', style: TextStyle(
                      color: AppTheme.accent, fontWeight: FontWeight.w600
                    ))
                  ],
                ),
              ),
            if (_hasMatched) ...[
              Text('Top Matches', style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              )),
              const SizedBox(height: 24),
              _buildMatchCard(
                name: 'Sarah Chen',
                matchScore: '98%',
                distance: '1.2 km away',
                explanation: 'Perfect skill match for Medical Supply Distribution. Sarah has prior experience in logistics and is currently available for immediate dispatch.',
              ),
              const SizedBox(height: 16),
              _buildMatchCard(
                name: 'David Okafor',
                matchScore: '92%',
                distance: '3.5 km away',
                explanation: 'Strong logistical background. Needs 1 hr lead time, but has access to a transport vehicle which fits task requirements.',
              ),
            ]
          ],
        ),
      ),
      bottomNavigationBar: !_isMatching && !_hasMatched ? Padding(
        padding: const EdgeInsets.all(24.0),
        child: _buildRunMatchingButton(),
      ) : null,
    );
  }

  Widget _buildRunMatchingButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.accent],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _runMatching,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text('Run AI Matching', style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMatchCard({
    required String name,
    required String matchScore,
    required String distance,
    required String explanation,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.ambientShadow,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.secondary.withOpacity(0.1),
                    child: Text(name[0], style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      )),
                      Text(distance, style: TextStyle(
                        fontSize: 12, 
                        color: AppTheme.textSecondary,
                      )),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$matchScore Match', style: const TextStyle(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.bold,
                )),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accent.withOpacity(0.1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, size: 18, color: AppTheme.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    explanation,
                    style: TextStyle(
                      color: AppTheme.accent.withOpacity(0.9),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.surfaceLow,
                foregroundColor: AppTheme.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Assign Task', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}
