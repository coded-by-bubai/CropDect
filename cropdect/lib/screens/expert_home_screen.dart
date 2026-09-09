import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../api_client.dart';
import '../main.dart';
import 'login_screen.dart';
import 'expert_review_screen.dart';
import 'hotspot_map_screen.dart';

class ExpertHomeScreen extends StatefulWidget {
  const ExpertHomeScreen({super.key});

  @override
  State<ExpertHomeScreen> createState() => _ExpertHomeScreenState();
}

class _ExpertHomeScreenState extends State<ExpertHomeScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _userProfile;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final res = await apiClient.get('/users/me');
      if (mounted) {
        setState(() {
          _userProfile = res.data is Map<String, dynamic> ? res.data : null;
          _isLoadingProfile = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Widget _buildExpertProfileTab() {
    final name = _userProfile?['name'] ?? 'Dr. Agronomist';
    final phone = _userProfile?['phone'] ?? '';
    final email = _userProfile?['email'] ?? 'Not set';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Agronomist Profile',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primary),
        ),
        backgroundColor: AppTheme.surfaceContainerLowest,
        elevation: 0,
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E88E5).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF1E88E5), width: 2),
                        ),
                        child: const Icon(Icons.biotech_rounded, size: 44, color: Color(0xFF1E88E5)),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        name,
                        style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Authorized Plant Pathologist / Agronomist',
                        style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'ROLE: EXPERT',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1565C0),
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // Credentials card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EXPERT CREDENTIALS & WORKSPACE',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildInfoRow('Registered Phone', phone, Icons.phone_rounded),
                      const SizedBox(height: 10),
                      _buildInfoRow('Official Email', email, Icons.email_rounded),
                      const SizedBox(height: 10),
                      _buildInfoRow('Triage Level', 'Level 2 Specialized Verification', Icons.verified_user_rounded),
                      const SizedBox(height: 10),
                      _buildInfoRow('Lab Dispatch', 'Authorized for Lab Referrals', Icons.science_rounded),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Instructions Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF81C784).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF2E7D32), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your expert role gives you direct access to review uncertain farmer diagnoses, correct diseases against the national crop repository, and dispatch samples to diagnostic laboratories.',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1B5E20), height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Sign Out
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: Text('Sign Out', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    await Provider.of<AuthState>(context, listen: false).logout();
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.outline)),
              Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const ExpertReviewScreen(showBackButton: false),
          const HotspotMapScreen(showBackButton: false),
          _buildExpertProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        backgroundColor: AppTheme.surfaceContainerLowest,
        indicatorColor: const Color(0xFF1E88E5).withValues(alpha: 0.15),
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.rate_review_outlined),
            selectedIcon: Icon(Icons.rate_review_rounded, color: Color(0xFF1E88E5)),
            label: 'Triage Desk',
          ),
          NavigationDestination(
            icon: Icon(Icons.travel_explore_outlined),
            selectedIcon: Icon(Icons.travel_explore_rounded, color: Color(0xFF1E88E5)),
            label: 'Surveillance',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: Color(0xFF1E88E5)),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
