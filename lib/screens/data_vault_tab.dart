import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class DataVaultTab extends StatefulWidget {
  const DataVaultTab({super.key});

  @override
  State<DataVaultTab> createState() => _DataVaultTabState();
}

class _DataVaultTabState extends State<DataVaultTab> {
  String _searchQuery = '';
  String _filterType = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Icon(Icons.storage, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('EXTRACTED DATA VAULT',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      fontSize: 14,
                      shadows: [Shadow(color: AppTheme.primary.withValues(alpha: 0.5), blurRadius: 10)],
                    )),
                const Spacer(),
                // Live count badge
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('reports').snapshots(),
                  builder: (context, snap) {
                    int count = snap.data?.docs.length ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
                      ),
                      child: Text('$count RECORDS', style: TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    );
                  },
                ),
              ],
            ),
          ),
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search extracted data...',
                    hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary, size: 20),
                    filled: true,
                    fillColor: AppTheme.surface.withValues(alpha: 0.6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.primary.withValues(alpha: 0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.primary.withValues(alpha: 0.6)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                ),
              ),
            ),
          ),
          // Filter Chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: ['All', 'Medical', 'Fire', 'Flood', 'Animal', 'Sanitation', 'Food', 'Clothing'].map((type) {
                bool isActive = _filterType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(type, style: TextStyle(
                      color: isActive ? Colors.black : AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    )),
                    selected: isActive,
                    onSelected: (_) => setState(() => _filterType = type),
                    backgroundColor: AppTheme.surface,
                    selectedColor: AppTheme.primary,
                    side: BorderSide(color: isActive ? AppTheme.primary : AppTheme.surfaceLow),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // Data List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
                }

                var docs = snapshot.data?.docs ?? [];
                
                // Apply filters
                if (_filterType != 'All') {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    String type = (data['type'] ?? '').toString().toLowerCase();
                    return type.contains(_filterType.toLowerCase());
                  }).toList();
                }

                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    String all = '${data['type'] ?? ''} ${data['description'] ?? ''} ${data['location'] ?? ''} ${data['submittedBy'] ?? ''}'.toLowerCase();
                    return all.contains(_searchQuery);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_open, color: AppTheme.textSecondary, size: 48),
                        const SizedBox(height: 12),
                        Text('No data records found.', style: TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return _buildDataCard(data, index + 1);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCard(Map<String, dynamic> data, int serial) {
    String type = data['type'] ?? 'Unknown';
    String urgency = data['urgency'] ?? 'Medium';
    String location = data['location'] ?? 'N/A';
    String description = data['description'] ?? 'No description available';
    String submitter = data['submittedBy'] ?? 'Anonymous';
    String source = data['source'] ?? 'Field Worker';
    Timestamp? ts = data['timestamp'];
    String dateStr = ts != null 
        ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year} ${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}'
        : 'N/A';

    Color urgencyColor = urgency == 'Critical' || urgency == 'High'
        ? AppTheme.urgencyHigh
        : urgency == 'Medium'
            ? AppTheme.urgencyMedium
            : AppTheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(color: urgencyColor, width: 3),
                top: BorderSide(color: AppTheme.primary.withValues(alpha: 0.1)),
                right: BorderSide(color: AppTheme.primary.withValues(alpha: 0.1)),
                bottom: BorderSide(color: AppTheme.primary.withValues(alpha: 0.1)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Serial + Type + Urgency Badge
                Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text('#$serial', style: TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(type.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: urgencyColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: urgencyColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(urgency.toUpperCase(), style: TextStyle(color: urgencyColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Description (The Raw Extracted Data)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.surfaceLow),
                  ),
                  child: Text(description,
                      style: TextStyle(color: AppTheme.textPrimary.withValues(alpha: 0.9), fontSize: 13, height: 1.5),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(height: 12),
                // Metadata Row
                Row(
                  children: [
                    Icon(Icons.location_on, color: AppTheme.textSecondary, size: 13),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(location,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.person_outline, color: AppTheme.textSecondary, size: 13),
                    const SizedBox(width: 4),
                    Text(submitter, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    const Spacer(),
                    Icon(Icons.access_time, color: AppTheme.textSecondary, size: 13),
                    const SizedBox(width: 4),
                    Text(dateStr, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      source == 'Admin Dashboard' ? Icons.desktop_windows : Icons.phone_android,
                      color: AppTheme.textSecondary, size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text('Source: $source', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    const Spacer(),
                    Text('STATUS: ${(data['status'] ?? 'Open').toString().toUpperCase()}',
                        style: TextStyle(
                          color: data['status'] == 'Open' ? AppTheme.primary : Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        )),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
