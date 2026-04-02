import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/ai_service.dart';
import '../services/offline_sync_service.dart';
import '../services/offline_matching_engine.dart';

class SmartMatcherScreen extends StatefulWidget {
  final String? reportId;
  final String location;
  final String need;

  const SmartMatcherScreen({
    super.key, 
    this.reportId,
    this.location = 'Downtown Shelter',
    this.need = 'General Need',
  });

  @override
  State<SmartMatcherScreen> createState() => _SmartMatcherScreenState();
}

class _SmartMatcherScreenState extends State<SmartMatcherScreen> {
  bool _isDispatching = false;
  bool _isAnalyzing = true;
  int _selectedVolunteerIndex = 0;

  // Ranked volunteer list
  List<Map<String, dynamic>> _rankedVolunteers = [];
  Map<String, dynamic> _reportData = {};

  @override
  void initState() {
    super.initState();
    _runAllocationEngine();
  }

  Future<void> _runAllocationEngine() async {
    try {
      bool isOnline = await OfflineSyncService.hasInternet();

      // 1. Fetch the incident report data
      if (widget.reportId != null && isOnline) {
        final reportDoc = await FirebaseFirestore.instance.collection('reports').doc(widget.reportId).get();
        _reportData = reportDoc.data() ?? {'type': widget.need, 'location': widget.location};
      } else {
        _reportData = {'type': widget.need, 'location': widget.location};
      }

      // 2. Fetch ALL available volunteers
      List<Map<String, dynamic>> volunteers = [];
      if (isOnline) {
        final volSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'Volunteer')
            .get();
        volunteers = volSnapshot.docs.map((d) {
          final data = d.data();
          data['id'] = d.id;
          return data;
        }).toList();
        // Update offline cache for later
        await OfflineSyncService().cacheVolunteersOffline(volunteers);
      } else {
        volunteers = await OfflineSyncService().getOfflineVolunteers();
        debugPrint('[MESH] Using ${volunteers.length} cached offline volunteers for matching');
      }

      if (volunteers.isEmpty) {
        if (mounted) setState(() => _isAnalyzing = false);
        return;
      }

      // 2.5 Batch-run Custom Hugging Face Sentence Transformer Model OR Local TF-IDF Matcher
      List<double> artificialScores = [];
      if (isOnline) {
        List<String> volunteerSentences = [];
        for (var vol in volunteers) {
          List<String> skills = List<String>.from(vol['skills'] ?? []);
          String sentence = skills.isEmpty ? 'Volunteer without specific skills.' : 'Volunteer skilled in: ${skills.join(', ')}';
          volunteerSentences.add(sentence);
        }
        artificialScores = await AIService.batchComputeHFSkillScores(widget.need, volunteerSentences);
      } else {
        double reportLat = (_reportData['latitude'] as num?)?.toDouble() ?? 0.0;
        double reportLng = (_reportData['longitude'] as num?)?.toDouble() ?? 0.0;
        artificialScores = OfflineMatchingEngine.computeOfflineScores(widget.need, reportLat, reportLng, volunteers);
      }

      // 3. Compute combined scores (HF Skills + Local Distance + Local Vehicle)
      List<Map<String, dynamic>> scoredVolunteers = [];
      for (int i = 0; i < volunteers.length; i++) {
        final volData = volunteers[i];
        
        final scores = AIService.computeLocalScore(
          volData, 
          _reportData,
          injectedSkillScore: artificialScores[i]
        );
        
        scoredVolunteers.add({
          'id': volData['id'] ?? 'unknown',
          'data': volData,
          'scores': scores,
          'reasoning': isOnline ? 'Computing AI reasoning...' : 'Offline Semantic Match Algorithm.',
        });
      }

      // 4. Sort by total_score descending (highest first)
      scoredVolunteers.sort((a, b) => 
        (b['scores']['total_score'] as int).compareTo(a['scores']['total_score'] as int)
      );

      // 5. Take Top 3
      final topCandidates = scoredVolunteers.take(3).toList();

      if (mounted) {
        setState(() {
          _rankedVolunteers = topCandidates;
          _isAnalyzing = false;
        });
      }

      // 6. Asynchronously get AI reasoning for each top candidate (non-blocking)
      for (int i = 0; i < topCandidates.length; i++) {
        final candidate = topCandidates[i];
        try {
          final reasonResult = await AIService.generateMatchReasoning(
            candidate['data'], _reportData, candidate['scores']
          );
          if (mounted) {
            setState(() {
              _rankedVolunteers[i]['reasoning'] = reasonResult['reasoning'] ?? 'Good match based on data analysis.';
            });
          }
        } catch (e) {
          debugPrint("Reasoning error for candidate $i: $e");
        }
      }

    } catch(e) {
      debugPrint("Allocation Engine Error: $e");
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _dispatch() async {
    if (_rankedVolunteers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No volunteer found!')));
      return;
    }

    final selectedVol = _rankedVolunteers[_selectedVolunteerIndex];

    setState(() {
      _isDispatching = true;
    });

    try {
      String location = widget.location;
      String need = widget.need;
      double latitude = 0.0;
      double longitude = 0.0;
      String description = '';

      bool isOnline = await OfflineSyncService.hasInternet();

      if (widget.reportId != null && isOnline) {
        final reportDoc = await FirebaseFirestore.instance.collection('reports').doc(widget.reportId).get();
        if (reportDoc.exists) {
          location = reportDoc.data()?['location'] ?? location;
          need = reportDoc.data()?['type'] ?? need;
          latitude = (reportDoc.data()?['latitude'] as num?)?.toDouble() ?? 0.0;
          longitude = (reportDoc.data()?['longitude'] as num?)?.toDouble() ?? 0.0;
          description = reportDoc.data()?['description'] ?? '';
        }
      } else if (widget.reportId != null) {
        // Offline: use _reportData already fetched during allocation engine
        location = _reportData['location'] ?? location;
        need = _reportData['type'] ?? need;
        latitude = (_reportData['latitude'] as num?)?.toDouble() ?? 0.0;
        longitude = (_reportData['longitude'] as num?)?.toDouble() ?? 0.0;
        description = _reportData['description'] ?? '';
      }

      if (isOnline) {
        // Online: write to Firestore
        await FirebaseFirestore.instance.collection('missions').add({
          'title': 'AI Dispatched: $need',
          'location': location,
          'latitude': latitude,
          'longitude': longitude,
          'description': description,
          'assignedVolunteerId': selectedVol['id'],
          'status': 'Pending',
          'reportId': widget.reportId,
          'matchScore': selectedVol['scores']['total_score'],
          'timestamp': FieldValue.serverTimestamp(),
        });

        if (widget.reportId != null) {
          await FirebaseFirestore.instance.collection('reports').doc(widget.reportId).update({
            'status': 'Assigned'
          });
        }
      } else {
        // Offline: dispatch via P2P mesh
        final reportForMesh = {
          'type': need,
          'location': location,
          'latitude': latitude,
          'longitude': longitude,
          'description': description,
          'urgency': _reportData['urgency'] ?? 'High',
        };
        String volName = selectedVol['data']['displayName'] ?? selectedVol['data']['fullName'] ?? 'Volunteer';
        await OfflineSyncService().dispatchMissionOffline(reportForMesh, selectedVol['id'], volName);
      }

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: isOnline ? AppTheme.urgencyLow : Colors.blueAccent,
            content: Text(
              isOnline
                ? 'DISPATCHED ${selectedVol['data']['displayName'] ?? 'VOLUNTEER'} (${selectedVol['scores']['total_score']}% MATCH)'
                : '📡 OFFLINE DISPATCH via Mesh → ${selectedVol['data']['displayName'] ?? 'VOLUNTEER'}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1, color: Colors.white)),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDispatching = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dispatch Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('INTELLIGENT ALLOCATION', style: TextStyle(
          color: AppTheme.textPrimary, 
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 2
        )),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Incident Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                children: [
                  Text('Resolving Critical Hotspot', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(widget.need.toUpperCase(), style: TextStyle(
                    color: AppTheme.urgencyHigh, 
                    fontSize: 24, 
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    shadows: [Shadow(color: AppTheme.urgencyHigh.withValues(alpha: 0.5), blurRadius: 10)],
                  ), textAlign: TextAlign.center,),
                  const SizedBox(height: 4),
                  Text('at ${widget.location}', style: const TextStyle(color: AppTheme.primary, fontSize: 16)),
                ],
              ),
            ),

            // Scoring Factors Legend
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SCORING FACTORS', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.5)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildFactorChip('Skills', '50%', Colors.cyanAccent),
                        const SizedBox(width: 8),
                        _buildFactorChip('Proximity', '30%', Colors.orangeAccent),
                        const SizedBox(width: 8),
                        _buildFactorChip('Availability', '20%', Colors.purpleAccent),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Ranked Volunteers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOP RANKED CANDIDATES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, height: 1.3)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${_rankedVolunteers.length} FOUND', style: const TextStyle(color: AppTheme.primary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isAnalyzing)
                    const Center(child: Column(
                      children: [
                        CircularProgressIndicator(color: AppTheme.primary),
                        SizedBox(height: 16),
                        Text('Running multi-factor analysis...', style: TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ))
                  else if (_rankedVolunteers.isEmpty)
                    const Text('No volunteers registered in the system.', style: TextStyle(color: Colors.red))
                  else
                    ...List.generate(_rankedVolunteers.length, (index) {
                      final vol = _rankedVolunteers[index];
                      final scores = vol['scores'] as Map<String, dynamic>;
                      final data = vol['data'] as Map<String, dynamic>;
                      final isSelected = index == _selectedVolunteerIndex;
                      
                      return GestureDetector(
                        onTap: () => setState(() => _selectedVolunteerIndex = index),
                        child: _buildRankedVolunteerCard(
                          rank: index + 1,
                          name: data['displayName'] ?? 'Agent ${index + 1}',
                          skills: List<String>.from(data['skills'] ?? []),
                          vehicle: data['vehicleType'] ?? '',
                          totalScore: scores['total_score'] as int,
                          skillScore: scores['skill_score'] as int,
                          distanceScore: scores['distance_score'] as int,
                          availabilityScore: scores['availability_score'] as int,
                          reasoning: vol['reasoning'] ?? '',
                          isSelected: isSelected,
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 100), // Space for bottom button
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SizedBox(
          height: 56,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.cyanMagentaGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton.icon(
              onPressed: _isDispatching || _rankedVolunteers.isEmpty ? null : _dispatch,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isDispatching 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3))
                  : const Icon(Icons.rocket_launch, size: 24),
              label: _isDispatching 
                  ? const Text('DISPATCHING...')
                  : Text(
                      _rankedVolunteers.isNotEmpty 
                        ? 'DISPATCH #${_selectedVolunteerIndex + 1} RANKED VOLUNTEER'
                        : 'NO VOLUNTEERS AVAILABLE',
                      style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFactorChip(String label, String weight, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            Text(weight, style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildRankedVolunteerCard({
    required int rank,
    required String name,
    required List<String> skills,
    required String vehicle,
    required int totalScore,
    required int skillScore,
    required int distanceScore,
    required int availabilityScore,
    required String reasoning,
    required bool isSelected,
  }) {
    Color rankColor = rank == 1 ? Colors.amber : (rank == 2 ? Colors.grey.shade300 : Colors.brown.shade300);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected 
          ? AppTheme.primary.withValues(alpha: 0.08)
          : AppTheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppTheme.primary : AppTheme.surfaceLow,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              // Rank Badge
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: rankColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: rankColor, width: 2),
                ),
                child: Center(child: Text('#$rank', style: TextStyle(color: rankColor, fontWeight: FontWeight.w900, fontSize: 14))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    if (vehicle.isNotEmpty) 
                      Text('🚗 $vehicle', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              // Total Score
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: totalScore >= 70 
                      ? [Colors.green.shade800, Colors.green.shade600]
                      : totalScore >= 40
                        ? [Colors.orange.shade800, Colors.orange.shade600]
                        : [Colors.red.shade800, Colors.red.shade600],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$totalScore%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Skills Tags
          if (skills.isNotEmpty)
            Wrap(
              spacing: 6, runSpacing: 6,
              children: skills.map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Text(s, style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold)),
              )).toList(),
            ),

          const SizedBox(height: 12),

          // Score Breakdown Bars
          _buildScoreBar('SKILL MATCH', skillScore, Colors.cyanAccent),
          const SizedBox(height: 6),
          _buildScoreBar('PROXIMITY', distanceScore, Colors.orangeAccent),
          const SizedBox(height: 6),
          _buildScoreBar('AVAILABILITY', availabilityScore, Colors.purpleAccent),

          const SizedBox(height: 12),

          // AI Reasoning
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, color: AppTheme.secondary, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(reasoning, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontStyle: FontStyle.italic)),
                ),
              ],
            ),
          ),

          if (isSelected)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.primary, size: 16),
                  const SizedBox(width: 6),
                  const Text('SELECTED FOR DISPATCH', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScoreBar(String label, int score, Color color) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100.0,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$score%', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class NodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.5)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(90, size.height / 2), Offset(size.width - 90, size.height / 2), paint); 
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
