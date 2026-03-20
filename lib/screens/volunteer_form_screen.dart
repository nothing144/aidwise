import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class VolunteerFormScreen extends StatefulWidget {
  const VolunteerFormScreen({super.key});

  @override
  State<VolunteerFormScreen> createState() => _VolunteerFormScreenState();
}

class _VolunteerFormScreenState extends State<VolunteerFormScreen> {
  final List<String> _selectedSkills = [];
  bool _immediateStart = true;

  final List<Map<String, dynamic>> _allSkills = [
    {'name': 'Medical', 'icon': Icons.medical_services_outlined},
    {'name': 'Logistics', 'icon': Icons.local_shipping_outlined},
    {'name': 'Translation', 'icon': Icons.translate},
    {'name': 'Childcare', 'icon': Icons.child_care},
    {'name': 'Construction', 'icon': Icons.handyman_outlined},
    {'name': 'IT Support', 'icon': Icons.computer_outlined},
  ];

  void _toggleSkill(String skill) {
    setState(() {
      if (_selectedSkills.contains(skill)) {
        _selectedSkills.remove(skill);
      } else {
        _selectedSkills.add(skill);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('New Task', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputField('Task Title', 'e.g., Emergency Supply Run'),
            const SizedBox(height: 20),
            _buildInputField('Location', 'e.g., Nairobi Central'),
            const SizedBox(height: 20),
            _buildInputField('Description', 'Detailed requirements...', maxLines: 4),
            const SizedBox(height: 32),
            Text('Required Skills', style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            )),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 12,
              children: _allSkills.map((skill) => _buildSkillChip(skill['name'] as String, skill['icon'] as IconData)).toList(),
            ),
            const SizedBox(height: 32),
            Text('Availability Options', style: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            )),
            const SizedBox(height: 16),
            _buildToggleOption(
              title: 'Immediate Start Required',
              subtitle: 'Task must be started within 2 hours',
              value: _immediateStart,
              onChanged: (val) {
                setState(() {
                  _immediateStart = val;
                });
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text('Create Task', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(
          fontSize: 14, 
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        )),
        const SizedBox(height: 8),
        TextField(
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5)),
            filled: true,
            fillColor: AppTheme.surfaceLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildSkillChip(String label, IconData icon) {
    final isSelected = _selectedSkills.contains(label);
    return GestureDetector(
      onTap: () => _toggleSkill(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.secondary : AppTheme.surfaceLow,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppTheme.secondary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.textSecondary),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleOption({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLow),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                )),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                )),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}
