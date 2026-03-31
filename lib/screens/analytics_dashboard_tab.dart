import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';

class AnalyticsDashboardTab extends StatelessWidget {
  const AnalyticsDashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reports').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));

          var reports = snapshot.data!.docs;
          if (reports.isEmpty) {
            return const Center(child: Text('Insufficient data for insights.', style: TextStyle(color: AppTheme.textSecondary)));
          }

          // Aggregate Data locally (Mimicking ML/Data Pipeline)
          Map<String, int> typeCounts = {};
          Map<String, int> urgencyCounts = {'Low': 0, 'Medium': 0, 'High': 0, 'Critical': 0};
          int solvedCount = 0;
          int openCount = 0;

          for (var doc in reports) {
            var data = doc.data() as Map<String, dynamic>;
            
            // Types
            String rawType = (data['type'] ?? 'Other').toString();
            // Simplify types for chart
            String type = rawType.split(' ').first; 
            if (type.length > 10) type = type.substring(0, 10);
            typeCounts[type] = (typeCounts[type] ?? 0) + 1;

            // Urgency
            String urgency = (data['urgency'] ?? 'Medium').toString();
            if (urgencyCounts.containsKey(urgency)) {
              urgencyCounts[urgency] = (urgencyCounts[urgency]! + 1);
            } else {
              urgencyCounts['Medium'] = (urgencyCounts['Medium']! + 1);
            }

            // Status
            String status = data['status'] ?? 'Open';
            if (status == 'Resolved' || status == 'Completed') {
              solvedCount++;
            } else {
              openCount++;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SYSTEM INSIGHTS', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 8),
                Text('Real-time data aggregation from ${reports.length} total field reports.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                
                const SizedBox(height: 32),
                
                // 1. Resolution Rate (Progress/Info)
                _buildSectionHeader('Resolution Rate', Icons.check_circle_outline),
                const SizedBox(height: 16),
                _buildResolutionCard(solvedCount, openCount),

                const SizedBox(height: 32),

                // 2. Incident Categories (Pie Chart)
                _buildSectionHeader('Incident Distribution', Icons.pie_chart_outline),
                const SizedBox(height: 16),
                _buildPieChart(typeCounts),

                const SizedBox(height: 32),

                // 3. Urgency Breakdown (Bar Chart)
                _buildSectionHeader('Urgency Levels', Icons.bar_chart),
                const SizedBox(height: 16),
                _buildBarChart(urgencyCounts),
                
                const SizedBox(height: 48),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 20),
        const SizedBox(width: 8),
        Text(title.toUpperCase(), style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
      ],
    );
  }

  Widget _buildResolutionCard(int solved, int open) {
    int total = solved + open;
    double solveRate = total == 0 ? 0 : (solved / total) * 100;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLow),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${solveRate.toStringAsFixed(1)}%', style: const TextStyle(color: AppTheme.success, fontSize: 32, fontWeight: FontWeight.w900)),
              const Text('Resolution Rate', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$solved Solved', style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('$open Active', style: const TextStyle(color: AppTheme.urgencyHigh, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPieChart(Map<String, int> typeCounts) {
    List<Color> colors = [AppTheme.primary, AppTheme.secondary, AppTheme.urgencyHigh, AppTheme.urgencyMedium, Colors.purpleAccent, Colors.greenAccent];
    
    List<PieChartSectionData> sections = [];
    int i = 0;
    typeCounts.forEach((key, value) {
      sections.add(
        PieChartSectionData(
          color: colors[i % colors.length],
          value: value.toDouble(),
          title: '$key\n$value',
          radius: 60,
          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
        )
      );
      i++;
    });

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLow),
      ),
      child: PieChart(
        PieChartData(
          sections: sections,
          centerSpaceRadius: 40,
          sectionsSpace: 4,
        ),
      ),
    );
  }

  Widget _buildBarChart(Map<String, int> urgencyCounts) {
    List<BarChartGroupData> barGroups = [
      _makeBarData(0, urgencyCounts['Low']!.toDouble(), Colors.green),
      _makeBarData(1, urgencyCounts['Medium']!.toDouble(), AppTheme.urgencyMedium),
      _makeBarData(2, urgencyCounts['High']!.toDouble(), Colors.orange),
      _makeBarData(3, urgencyCounts['Critical']!.toDouble(), AppTheme.urgencyHigh),
    ];

    return Container(
      height: 250,
      padding: const EdgeInsets.only(top: 32, bottom: 16, left: 16, right: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLow),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (urgencyCounts.values.reduce((a, b) => a > b ? a : b) + 2).toDouble(),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const titles = ['Low', 'Med', 'High', 'Crit'];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(titles[value.toInt()], style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
        ),
      ),
    );
  }

  BarChartGroupData _makeBarData(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 22,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 0,
            color: AppTheme.surfaceLow,
          ),
        ),
      ],
    );
  }
}
