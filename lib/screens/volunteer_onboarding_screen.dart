import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class VolunteerOnboardingScreen extends StatefulWidget {
  const VolunteerOnboardingScreen({super.key});

  @override
  State<VolunteerOnboardingScreen> createState() => _VolunteerOnboardingScreenState();
}

class _VolunteerOnboardingScreenState extends State<VolunteerOnboardingScreen> {
  final List<String> _skills = ['Medical Provider', 'Blood Donor', 'Teacher / Tutor', 'Logistics & Transport', 'Food Distribution', 'Search & Rescue', 'IT Support', 'Counselling'];
  final Set<String> _selectedSkills = {};
  final TextEditingController _vehicleController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _customSkillController = TextEditingController();
  bool _isSaving = false;

  void _addCustomSkill() {
    final skill = _customSkillController.text.trim();
    if (skill.isNotEmpty && !_skills.contains(skill)) {
      setState(() {
        _skills.add(skill);
        _selectedSkills.add(skill);
        _customSkillController.clear();
      });
    }
  }

  Future<void> _completeOnboarding() async {
    if (_selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one skill.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'skills': _selectedSkills.toList(),
          'vehicleType': _vehicleController.text.trim(),
          'phone': _phoneController.text.trim(),
        });
      }
      if (mounted) Navigator.pop(context); // Return to root (AuthWrapper)
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving profile: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('CREATE PROFILE', style: TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Join the Network', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 8),
            Text('Register your skills so our AI can match you with critical needs.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
            const SizedBox(height: 32),
            
            _buildTextField('Phone Number', Icons.phone, _phoneController),
            const SizedBox(height: 16),
            _buildTextField('Vehicle Type (Optional, e.g. Truck, Bike)', Icons.directions_car, _vehicleController),
            
            const SizedBox(height: 32),
            const Text('YOUR SKILLS (AI MATCHING)', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _skills.map((skill) {
                final isSelected = _selectedSkills.contains(skill);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      isSelected ? _selectedSkills.remove(skill) : _selectedSkills.add(skill);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary.withValues(alpha: 0.2) : AppTheme.surface,
                      border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.surfaceLow),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected) const Icon(Icons.check, size: 16, color: AppTheme.primary),
                        if (isSelected) const SizedBox(width: 8),
                        Text(skill, style: TextStyle(color: isSelected ? AppTheme.primary : AppTheme.textSecondary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField('Add Custom Skill (e.g. Drone Pilot)', Icons.add_circle_outline, _customSkillController),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_box, color: AppTheme.primary, size: 40),
                  onPressed: _addCustomSkill,
                ),
              ],
            ),
            
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _completeOnboarding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black)) 
                    : const Text('INITIALIZE PROFILE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, TextEditingController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppTheme.surfaceLow),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          icon: Icon(icon, color: AppTheme.textSecondary),
          border: InputBorder.none,
          labelText: label,
          labelStyle: TextStyle(color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}
