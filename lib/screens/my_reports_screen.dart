import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {

  Future<void> _verifyReport(String reportId) async {
    try {
      // 1. Mark the report as Resolved (Field Worker verified)
      await FirebaseFirestore.instance.collection('reports').doc(reportId).update({
        'status': 'Resolved',
      });

      // 2. Also update any linked mission to 'Verified'
      final missionSnap = await FirebaseFirestore.instance
          .collection('missions')
          .where('reportId', isEqualTo: reportId)
          .get();
      for (var doc in missionSnap.docs) {
        await doc.reference.update({'status': 'Verified'});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Report verified and resolved! Thank you.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('MY SUBMITTED REPORTS', style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.bold,
        )),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .where('submittedBy', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined, color: AppTheme.textSecondary, size: 64),
                  const SizedBox(height: 16),
                  Text('No reports submitted yet.', style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Text('Use the Scanner tab to submit your first report!', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            );
          }

          // Sort locally (newest first) to avoid Firestore composite index
          var docs = snapshot.data!.docs.toList();
          docs.sort((a, b) {
            Timestamp? tsA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            Timestamp? tsB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            if (tsA == null && tsB == null) return 0;
            if (tsA == null) return 1;
            if (tsB == null) return -1;
            return tsB.compareTo(tsA);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              String status = data['status'] ?? 'Open';
              String type = data['type'] ?? 'General';
              String urgency = data['urgency'] ?? 'Medium';
              String location = data['location'] ?? 'Unknown';
              Timestamp? ts = data['timestamp'] as Timestamp?;
              String timeAgo = ts != null ? _timeAgo(ts.toDate()) : 'Just now';
              
              Color statusColor;
              IconData statusIcon;
              
              switch (status) {
                case 'Resolved':
                  statusColor = AppTheme.urgencyLow;
                  statusIcon = Icons.check_circle;
                  break;
                case 'Completed':
                  statusColor = Colors.orangeAccent;
                  statusIcon = Icons.hourglass_top;
                  break;
                case 'Assigned':
                  statusColor = AppTheme.secondary;
                  statusIcon = Icons.person_search;
                  break;
                default: // Open
                  statusColor = AppTheme.urgencyMedium;
                  statusIcon = Icons.schedule;
              }

              Color urgencyColor = urgency == 'Critical' || urgency == 'High' 
                  ? AppTheme.urgencyHigh 
                  : AppTheme.urgencyMedium;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border(left: BorderSide(color: statusColor, width: 4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Type + Status Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(type.toUpperCase(), style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5,
                          )),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, color: statusColor, size: 14),
                              const SizedBox(width: 4),
                              Text(status.toUpperCase(), style: TextStyle(
                                color: statusColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1,
                              )),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    
                    // Location + Urgency
                    Row(
                      children: [
                        Icon(Icons.location_on, color: AppTheme.primary, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(location, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13), overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: urgencyColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(urgency.toUpperCase(), style: TextStyle(color: urgencyColor, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Time ago
                    Text(timeAgo, style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6), fontSize: 11)),
                    
                    // Resolved celebration
                    if (status == 'Resolved')
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.urgencyLow.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.urgencyLow.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.verified, color: AppTheme.urgencyLow, size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '✅ Verified & Resolved! Mission complete.',
                                  style: TextStyle(color: AppTheme.urgencyLow, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // COMPLETED: Awaiting Field Worker Verification
                    if (status == 'Completed')
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.hourglass_top, color: Colors.orangeAccent, size: 16),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '⏳ Volunteer marked complete. Please verify!',
                                      style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _verifyReport(doc.id),
                                  icon: const Icon(Icons.verified, size: 16),
                                  label: const Text('VERIFY & RESOLVE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.success,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    if (status == 'Assigned')
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.person_search, color: AppTheme.secondary, size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '🚀 A volunteer has been dispatched!',
                                  style: TextStyle(color: AppTheme.secondary, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
