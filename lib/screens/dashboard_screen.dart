import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'ai_matching_screen.dart';
import 'volunteer_form_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildStatsRow(),
              const SizedBox(height: 48),
              _buildTaskListHeader(context),
              const SizedBox(height: 24),
              _buildTaskCard(
                title: 'Emergency Medical Supply Distribution',
                location: 'Nairobi, KE',
                urgency: 'HIGH URGENCY',
                urgencyColor: AppTheme.urgencyHigh,
                status: 'Pending',
              ),
              const SizedBox(height: 16),
              _buildTaskCard(
                title: 'Water Purification Setup',
                location: 'Kisumu, KE',
                urgency: 'MEDIUM URGENCY',
                urgencyColor: AppTheme.urgencyMedium,
                status: 'Assigned',
                assignedVolunteer: 'John Doe',
                aiExplanation: 'AI: Match based on fluid dynamics certification and proximity (2.5km).',
              ),
              const SizedBox(height: 16),
              _buildTaskCard(
                title: 'Community Food Drive',
                location: 'Mombasa, KE',
                urgency: 'LOW URGENCY',
                urgencyColor: AppTheme.urgencyLow,
                status: 'Pending',
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildAIActionButton(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Digital Steward', style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                )),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, color: AppTheme.accent, size: 14),
                      const SizedBox(width: 4),
                      Text('AI Active', style: TextStyle(
                        color: AppTheme.accent, 
                        fontSize: 12, 
                        fontWeight: FontWeight.bold
                      )),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Intelligent Resource Allocation', style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            )),
          ],
        ),
        CircleAvatar(
          backgroundColor: AppTheme.primary.withOpacity(0.1),
          child: const Icon(Icons.person_outline, color: AppTheme.primary),
        )
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Total Volunteers', '142')),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Pending Tasks', '24')),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Assigned Tasks', '89')),
      ],
    );
  }

  Widget _buildStatCard(String title, String count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.ambientShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(
            color: AppTheme.textSecondary, 
            fontSize: 12, 
            fontWeight: FontWeight.w500
          )),
          const SizedBox(height: 8),
          Text(count, style: TextStyle(
            color: AppTheme.textPrimary, 
            fontSize: 28, 
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          )),
        ],
      ),
    );
  }

  Widget _buildTaskListHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Active Tasks', style: TextStyle(
          fontSize: 20, 
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        )),
        TextButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const VolunteerFormScreen()));
          },
          child: Text('+ New Task', style: TextStyle(
            color: AppTheme.primary, 
            fontWeight: FontWeight.w600
          )),
        )
      ],
    );
  }

  Widget _buildTaskCard({
    required String title,
    required String location,
    required String urgency,
    required Color urgencyColor,
    required String status,
    String? assignedVolunteer,
    String? aiExplanation,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.ambientShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: urgencyColor, width: 4)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: urgencyColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(urgency, style: TextStyle(
                      color: urgencyColor, 
                      fontSize: 10, 
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    )),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: status == 'Assigned' ? AppTheme.surfaceLow : AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.surfaceLow),
                    ),
                    child: Text(status, style: TextStyle(
                      color: status == 'Assigned' ? AppTheme.textSecondary : AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    )),
                  )
                ],
              ),
              const SizedBox(height: 16),
              Text(title, style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              )),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(location, style: TextStyle(
                    fontSize: 14, 
                    color: AppTheme.textSecondary,
                  )),
                ],
              ),
              if (assignedVolunteer != null) ...[
                const SizedBox(height: 16),
                const Divider(color: AppTheme.surfaceLow, height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppTheme.secondary.withOpacity(0.2),
                      child: Text(assignedVolunteer[0], style: TextStyle(
                        color: AppTheme.secondary, fontSize: 12, fontWeight: FontWeight.bold
                      )),
                    ),
                    const SizedBox(width: 8),
                    Text('Assigned to $assignedVolunteer', style: TextStyle(
                      fontSize: 14, 
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    )),
                  ],
                ),
              ],
              if (aiExplanation != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.1)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.auto_awesome, size: 16, color: AppTheme.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(aiExplanation, style: TextStyle(
                          color: AppTheme.accent, 
                          fontSize: 13,
                          height: 1.4,
                        )),
                      ),
                    ],
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAIActionButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AIMatchingScreen()));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            colors: [AppTheme.primary, AppTheme.accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
    );
  }
}
