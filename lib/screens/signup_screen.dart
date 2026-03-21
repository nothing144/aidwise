import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'volunteer_onboarding_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _authService = AuthService();
  
  String _selectedRole = 'Volunteer';
  final List<String> _roles = ['Admin / NGO', 'Field Worker', 'Volunteer'];
  bool _isLoading = false;

  void _signUp() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    final error = await _authService.signUp(
      email: _emailController.text.trim(), 
      password: _passwordController.text.trim(),
      role: _selectedRole,
      fullName: _nameController.text.trim()
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
    } else {
      // If Volunteer, go to Onboarding, else go back to root (where AuthWrapper will display the dashboard)
      if (_selectedRole == 'Volunteer') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const VolunteerOnboardingScreen()));
      } else {
        Navigator.pop(context); // Go back to root AuthWrapper and view Dashboard
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ENLISTMENT', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
            const SizedBox(height: 8),
            Text('Register an account on the Aidwise Network.', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 48),
            
            _buildTextField('Full Name', Icons.person, _nameController),
            const SizedBox(height: 16),
            _buildTextField('Email', Icons.email, _emailController),
            const SizedBox(height: 16),
            _buildTextField('Password', Icons.lock, _passwordController, isPassword: true),
            const SizedBox(height: 24),
            
            const Text('SELECT ROLE', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: AppTheme.surface, border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(12)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedRole,
                  isExpanded: true,
                  dropdownColor: AppTheme.surface,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primary),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRole = val);
                  },
                  items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                ),
              ),
            ),
            
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _signUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black))
                    : const Text('CREATE PROFILE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, IconData icon, TextEditingController controller, {bool isPassword = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: AppTheme.surface.withValues(alpha: 0.5), border: Border.all(color: AppTheme.surfaceLow), borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
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
