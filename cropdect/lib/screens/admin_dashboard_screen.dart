import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../api_client.dart';
import '../main.dart';
import 'login_screen.dart';
import 'hotspot_map_screen.dart';
import '../widgets/translated_text.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentTabIndex = 0; // 0: Overview, 1: Farmers, 2: Experts, 3: Map, 4: Profile
  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _overview;
  List<dynamic> _farmers = [];
  List<dynamic> _experts = [];
  List<dynamic> _activityLog = [];

  String _auditFilter = 'All'; // 'Today', 'Yesterday', 'Custom', 'All'
  DateTime? _auditStartDate;
  DateTime? _auditEndDate;
  bool _showAllAudit = false;

  String _farmerSearchQuery = '';
  String _expertSearchQuery = '';

  Future<void> _selectCustomAuditDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              onSurface: AppTheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _auditFilter = 'Custom';
        _auditStartDate = picked.start;
        _auditEndDate = picked.end;
      });
    }
  }

  List<dynamic> get _filteredActivityLog {
    if (_activityLog.isEmpty) return [];
    if (_auditFilter == 'All') return _activityLog;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    return _activityLog.where((act) {
      if (act['timestamp'] == null) return false;
      final actDate = DateTime.parse(act['timestamp']).toLocal();
      final actDay = DateTime(actDate.year, actDate.month, actDate.day);

      if (_auditFilter == 'Today') {
        return actDay.isAtSameMomentAs(today);
      } else if (_auditFilter == 'Yesterday') {
        return actDay.isAtSameMomentAs(yesterday);
      } else if (_auditFilter == 'Custom' && _auditStartDate != null && _auditEndDate != null) {
        return (actDay.isAfter(_auditStartDate!.subtract(const Duration(days: 1))) &&
                actDay.isBefore(_auditEndDate!.add(const Duration(days: 1))));
      }
      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchAdminData();
  }

  Future<void> _fetchAdminData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ovRes = await apiClient.get('/admin/overview');
      final farmersRes = await apiClient.get('/admin/farmers');
      final expertsRes = await apiClient.get('/admin/experts');
      final logRes = await apiClient.get('/admin/activity-log');

      if (mounted) {
        setState(() {
          _overview = ovRes.data is Map<String, dynamic> ? ovRes.data : null;
          _farmers = farmersRes.data is List ? farmersRes.data : [];
          _experts = expertsRes.data is List ? expertsRes.data : [];
          _activityLog = logRes.data is List ? logRes.data : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load admin oversight data. Make sure you are logged in as Admin.';
          _isLoading = false;
        });
      }
    }
  }

  // ── FARMER DETAILS MODAL ──────────────────────────────────────────────────
  Future<void> _showFarmerDetailsModal(int farmerId) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: FutureBuilder<dynamic>(
            future: apiClient.get('/admin/farmers/$farmerId'),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
              }
              if (snapshot.hasError || snapshot.data == null) {
                return Center(
                  child: TranslatedText('Error loading farmer details', style: GoogleFonts.inter(color: AppTheme.error)),
                );
              }

              final data = snapshot.data.data;
              final farmer = data['farmer'] ?? {};
              final farms = data['farms'] as List? ?? [];
              final scans = data['scans'] as List? ?? [];

              return Column(
                children: [
                  // Modal Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppTheme.outlineVariant,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.agriculture_rounded, color: AppTheme.primary, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TranslatedText(
                                farmer['name'] ?? 'Farmer #${farmer['id']}',
                                style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary),
                              ),
                              TranslatedText(
                                'Phone: ${farmer['phone']} ${farmer['email'] != null ? "• ${farmer['email']}" : ""}',
                                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Farms summary
                        TranslatedText('REGISTERED FARMS (${farms.length})',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppTheme.onSurfaceVariant)),
                        const SizedBox(height: 10),
                        if (farms.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TranslatedText('No farms registered yet.', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.outline)),
                          )
                        else
                          ...farms.map((f) {
                            final crops = f['crops'] as List? ?? [];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      TranslatedText(f['name'] ?? 'Farm',
                                          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primary)),
                                      TranslatedText('${f['area']} Acres',
                                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.onSurfaceVariant)),
                                    ],
                                  ),
                                  if (f['soil_type'] != null) ...[
                                    const SizedBox(height: 4),
                                    TranslatedText('Soil: ${f['soil_type']}', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.outline)),
                                  ],
                                  if (crops.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: crops.map<Widget>((c) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryContainer.withValues(alpha: 0.5),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: TranslatedText('${c['crop_type']} ${c['variety'] != null ? "(${c['variety']})" : ""}',
                                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),

                        const SizedBox(height: 20),

                        // Scans history
                        TranslatedText('AI SCAN & DIAGNOSIS WORK HISTORY (${scans.length})',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppTheme.onSurfaceVariant)),
                        const SizedBox(height: 10),
                        if (scans.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TranslatedText('No scans submitted yet.', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.outline)),
                          )
                        else
                          ...scans.map((s) {
                            final conf = ((s['confidence'] ?? 0.0) * 100).toInt();
                            final dateStr = s['created_at'] != null
                                ? DateFormat('dd MMM, yyyy • hh:mm a').format(DateTime.parse(s['created_at']).toLocal())
                                : '';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.6)),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      s['image_url'] ?? '',
                                      width: 54,
                                      height: 54,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 54,
                                        height: 54,
                                        color: AppTheme.surfaceContainerHigh,
                                        child: const Icon(Icons.broken_image_rounded, size: 24, color: AppTheme.outline),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        TranslatedText(
                                          s['label'] ?? 'Scan',
                                          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
                                        ),
                                        TranslatedText(
                                          'Crop: ${s['crop_name']} • Conf: $conf%',
                                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.onSurfaceVariant),
                                        ),
                                        TranslatedText(
                                          dateStr,
                                          style: GoogleFonts.inter(fontSize: 10, color: AppTheme.outline),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildStatusBadge(s['status']),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  
                  // Delete Farmer Action
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLowest,
                      border: Border(top: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5))),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _confirmDeleteUser(farmer['id'], 'Farmer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.errorContainer,
                          foregroundColor: AppTheme.onErrorContainer,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: TranslatedText('Delete Farmer Account', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ── EXPERT DETAILS MODAL ──────────────────────────────────────────────────
  Future<void> _showExpertDetailsModal(int expertId) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: FutureBuilder<dynamic>(
            future: apiClient.get('/admin/experts/$expertId'),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
              }
              if (snapshot.hasError || snapshot.data == null) {
                return Center(
                  child: TranslatedText('Error loading expert details', style: GoogleFonts.inter(color: AppTheme.error)),
                );
              }

              final data = snapshot.data.data;
              final expert = data['expert'] ?? {};
              final validations = data['validations'] as List? ?? [];

              return Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppTheme.outlineVariant,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E88E5).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.biotech_rounded, color: Color(0xFF1E88E5), size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TranslatedText(
                                expert['name'] ?? 'Agronomist #${expert['id']}',
                                style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary),
                              ),
                              TranslatedText(
                                'Phone: ${expert['phone']} • Completed: ${expert['reviews_completed']} reviews',
                                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        TranslatedText('EXPERT VALIDATION & TRIAGE WORK LOG (${validations.length})',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppTheme.onSurfaceVariant)),
                        const SizedBox(height: 10),
                        if (validations.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TranslatedText('No validation reviews submitted yet.', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.outline)),
                          )
                        else
                          ...validations.map((v) {
                            final isCorrect = v['is_correct'] == true;
                            final dateStr = v['created_at'] != null
                                ? DateFormat('dd MMM, yyyy • hh:mm a').format(DateTime.parse(v['created_at']).toLocal())
                                : '';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.6)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      TranslatedText(
                                        'Case #${v['diagnosis_id']} • ${v['crop_name']}',
                                        style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primary),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isCorrect ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: TranslatedText(
                                          isCorrect ? 'CONFIRMED' : 'CORRECTED',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isCorrect ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  TranslatedText(
                                    'Assessment: ${v['disease_name'] ?? "Reviewed"}',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.onSurface),
                                  ),
                                  if (v['expert_notes'] != null && (v['expert_notes'] as String).isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    TranslatedText('Notes: "${v['expert_notes']}"',
                                        style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.onSurfaceVariant)),
                                  ],
                                  const SizedBox(height: 4),
                                  TranslatedText(dateStr, style: GoogleFonts.inter(fontSize: 10, color: AppTheme.outline)),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),

                  // Delete Expert Action
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLowest,
                      border: Border(top: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5))),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _confirmDeleteUser(expert['id'], 'Agronomist'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.errorContainer,
                          foregroundColor: AppTheme.onErrorContainer,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: TranslatedText('Delete Expert Account', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteUser(int userId, String role) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerLowest,
        title: TranslatedText('Delete $role?', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: AppTheme.error)),
        content: TranslatedText(
          'Are you sure you want to permanently delete this user? All their farms, crops, and diagnostic history will be erased. This action cannot be undone.',
          style: GoogleFonts.inter(color: AppTheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: TranslatedText('Cancel', style: GoogleFonts.inter(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: AppTheme.onError,
            ),
            child: TranslatedText('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await apiClient.delete('/admin/users/$userId');
        if (mounted) {
          Navigator.pop(context); // Close the details modal
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: TranslatedText('$role deleted successfully.')));
          _fetchAdminData(); // Refresh lists
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: TranslatedText('Failed to delete $role: $e')));
        }
      }
    }
  }

  Widget _buildStatusBadge(String? status) {
    Color bg = AppTheme.surfaceContainerHigh;
    Color fg = AppTheme.outline;
    String text = status ?? 'UNKNOWN';

    switch (status?.toUpperCase()) {
      case 'CONFIRMED':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        break;
      case 'CORRECTED':
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        break;
      case 'EXPERT_REVIEW':
        bg = const Color(0xFFEDE7F6);
        fg = const Color(0xFF5E35B1);
        text = 'IN REVIEW';
        break;
      case 'AI_PREDICTED':
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1565C0);
        text = 'AI SCAN';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: TranslatedText(text, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  // ── OVERVIEW TAB ──────────────────────────────────────────────────────────
  Widget _buildOverviewTab() {
    if (_overview == null) return const SizedBox();

    return RefreshIndicator(
      onRefresh: _fetchAdminData,
      color: AppTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B381A), Color(0xFF2E5E2A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1B381A).withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.security_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          TranslatedText('CENTRAL OVERSIGHT',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.1)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF81FF45).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TranslatedText('LIVE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF81FF45))),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TranslatedText('cropdect Operations Hub',
                    style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                TranslatedText('Monitoring all agricultural producers, agronomist reviews, and field diagnoses.',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Macro Stats Grid
          LayoutBuilder(
            builder: (context, constraints) {
              // Calculate ideal card width based on screen size
              double cardWidth;
              if (constraints.maxWidth >= 1200) {
                cardWidth = (constraints.maxWidth - 48) / 4;
                if (cardWidth > 240) cardWidth = 240; // Max width to prevent looking huge
              } else if (constraints.maxWidth >= 800) {
                cardWidth = (constraints.maxWidth - 32) / 3;
              } else {
                cardWidth = (constraints.maxWidth - 16) / 2;
              }
              
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
              _buildStatCard(
                width: cardWidth,
                title: 'Total Farmers',
                count: '${_overview!['total_farmers'] ?? 0}',
                icon: Icons.agriculture_rounded,
                color: const Color(0xFF2E7D32),
                subtitle: 'Registered growers',
              ),
              _buildStatCard(
                width: cardWidth,
                title: 'Agronomists',
                count: '${_overview!['total_experts'] ?? 0}',
                icon: Icons.biotech_rounded,
                color: const Color(0xFF1976D2),
                subtitle: 'Active experts',
              ),
              _buildStatCard(
                width: cardWidth,
                title: 'Total Scans',
                count: '${_overview!['total_scans'] ?? 0}',
                icon: Icons.document_scanner_rounded,
                color: const Color(0xFF7B1FA2),
                subtitle: 'AI field analyses',
              ),
              _buildStatCard(
                width: cardWidth,
                title: 'Total Farms',
                count: '${_overview!['total_farms'] ?? 0}',
                icon: Icons.landscape_rounded,
                color: const Color(0xFF00796B),
                subtitle: 'Monitored plots',
              ),
              _buildStatCard(
                width: cardWidth,
                title: 'Pending Triage',
                count: '${_overview!['pending_reviews'] ?? 0}',
                icon: Icons.hourglass_top_rounded,
                color: const Color(0xFFF57C00),
                subtitle: 'Awaiting expert',
              ),
              _buildStatCard(
                width: cardWidth,
                title: 'Verified Cases',
                count: '${_overview!['completed_reviews'] ?? 0}',
                icon: Icons.verified_rounded,
                color: const Color(0xFF388E3C),
                subtitle: 'Expert validations',
              ),
              _buildStatCard(
                width: cardWidth,
                title: 'Lab Referrals',
                count: '${_overview!['lab_referrals'] ?? 0}',
                icon: Icons.science_rounded,
                color: const Color(0xFF5D4037),
                subtitle: 'Physical lab tests',
              ),
              _buildStatCard(
                width: cardWidth,
                title: 'Outbreak Alerts',
                count: '${_overview!['active_outbreaks'] ?? 0}',
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFD32F2F),
                subtitle: 'High severity flags',
              ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),
          _buildScansChart(),
          const SizedBox(height: 24),

          // Live Activity Stream
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              TranslatedText('LIVE AUDIT STREAM (WHO DID WHAT)',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppTheme.onSurfaceVariant)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _auditFilter,
                      dropdownColor: AppTheme.surfaceContainerLowest,
                      focusColor: Colors.transparent,
                      icon: const Padding(
                        padding: EdgeInsets.only(left: 6.0),
                        child: Icon(Icons.filter_list_rounded, size: 14, color: AppTheme.primary),
                      ),
                      underline: const SizedBox(),
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold),
                      items: ['All', 'Today', 'Yesterday', 'Custom'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: TranslatedText(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        if (newValue == 'Custom') {
                          _selectCustomAuditDateRange();
                        } else if (newValue != null) {
                          setState(() {
                            _auditFilter = newValue;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  TranslatedText('${_filteredActivityLog.length} events', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.outline)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          Builder(
            builder: (context) {
              final filtered = _filteredActivityLog;
              if (filtered.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.outlineVariant),
                  ),
                  child: TranslatedText('No system activity recorded for this period.', style: GoogleFonts.inter(color: AppTheme.outline, fontSize: 13)),
                );
              }

              return Column(
                children: [
                  ...filtered.map((act) {
                    final isScan = act['type'] == 'SCAN';
                    final isLab = act['type'] == 'LAB';
                    final isSystem = act['type'] == 'SYSTEM';
                    final timeStr = act['timestamp'] != null
                        ? DateFormat('dd MMM, hh:mm a').format(DateTime.parse(act['timestamp']).toLocal())
                        : '';
                    
                    Color iconBgColor = const Color(0xFFE3F2FD); // Default for REVIEW
                    Color iconColor = const Color(0xFF1976D2);
                    IconData iconData = Icons.verified_user_rounded;
                    
                    if (isScan) {
                      iconBgColor = const Color(0xFFE8F5E9);
                      iconColor = const Color(0xFF2E7D32);
                      iconData = Icons.document_scanner_rounded;
                    } else if (isLab) {
                      iconBgColor = const Color(0xFFFFF3E0);
                      iconColor = const Color(0xFFE65100);
                      iconData = Icons.science_rounded;
                    } else if (isSystem) {
                      iconBgColor = const Color(0xFFF3E5F5);
                      iconColor = const Color(0xFF7B1FA2);
                      iconData = Icons.add_circle_outline_rounded;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: iconBgColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              iconData,
                              color: iconColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    TranslatedText(
                                      act['user_name'] ?? 'User',
                                      style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: act['user_role'] == 'EXPERT'
                                            ? const Color(0xFFE3F2FD)
                                            : act['user_role'] == 'LAB'
                                                ? const Color(0xFFFFF3E0)
                                                : const Color(0xFFE8F5E9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: TranslatedText(
                                        act['user_role'] ?? 'USER',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: act['user_role'] == 'EXPERT'
                                              ? const Color(0xFF1565C0)
                                              : act['user_role'] == 'LAB'
                                                  ? const Color(0xFFE65100)
                                                  : const Color(0xFF2E7D32),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                TranslatedText(act['title'] ?? '', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
                                const SizedBox(height: 2),
                                TranslatedText(act['description'] ?? '', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.onSurfaceVariant)),
                                const SizedBox(height: 4),
                                TranslatedText(timeStr, style: GoogleFonts.inter(fontSize: 10, color: AppTheme.outline)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required double width,
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TranslatedText(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.onSurfaceVariant)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          TranslatedText(count, style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primary)),
          TranslatedText(subtitle, style: GoogleFonts.inter(fontSize: 10, color: AppTheme.outline)),
        ],
      ),
    );
  }

  // ── FARMERS TAB ───────────────────────────────────────────────────────────
  Widget _buildFarmersTab() {
    final filtered = _farmers.where((f) {
      final name = (f['name'] ?? '').toString().toLowerCase();
      final phone = (f['phone'] ?? '').toString().toLowerCase();
      final q = _farmerSearchQuery.toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search farmers by name or phone...',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.outline),
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.outline),
              filled: true,
              fillColor: AppTheme.surfaceContainerLowest,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.outlineVariant)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.outlineVariant)),
            ),
            onChanged: (val) => setState(() => _farmerSearchQuery = val),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TranslatedText('PRODUCERS DIRECTORY (${filtered.length})',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppTheme.onSurfaceVariant)),
              TranslatedText('Tap to view farms & scans', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.outline)),
            ],
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchAdminData,
            color: AppTheme.primary,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              itemCount: filtered.length,
              itemBuilder: (context, idx) {
                final f = filtered[idx];
                final lastScanStr = f['last_scan_date'] != null
                    ? DateFormat('dd MMM yyyy').format(DateTime.parse(f['last_scan_date']).toLocal())
                    : 'None yet';

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.outlineVariant),
                  ),
                  color: AppTheme.surfaceContainerLowest,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _showFarmerDetailsModal(f['id']),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.agriculture_rounded, color: AppTheme.primary, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TranslatedText(
                                      f['name'] ?? 'Farmer #${f['id']}',
                                      style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primary),
                                    ),
                                    TranslatedText(
                                      'Phone: ${f['phone']}',
                                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: AppTheme.outline),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.landscape_rounded, size: 15, color: AppTheme.outline),
                                  const SizedBox(width: 4),
                                  TranslatedText('${f['farm_count']} Farms',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.document_scanner_rounded, size: 15, color: AppTheme.outline),
                                  const SizedBox(width: 4),
                                  TranslatedText('${f['scan_count']} AI Scans',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
                                ],
                              ),
                              TranslatedText('Last: $lastScanStr', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.outline)),
                            ],
                          ),
                          if (f['last_disease'] != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: TranslatedText('Latest detected: ${f['last_disease']}',
                                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── EXPERTS TAB ───────────────────────────────────────────────────────────
  Widget _buildExpertsTab() {
    final filtered = _experts.where((e) {
      final name = (e['name'] ?? '').toString().toLowerCase();
      final phone = (e['phone'] ?? '').toString().toLowerCase();
      final q = _expertSearchQuery.toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search agronomists by name or phone...',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.outline),
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.outline),
              filled: true,
              fillColor: AppTheme.surfaceContainerLowest,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.outlineVariant)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.outlineVariant)),
            ),
            onChanged: (val) => setState(() => _expertSearchQuery = val),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TranslatedText('AGRONOMISTS & EXPERTS (${filtered.length})',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppTheme.onSurfaceVariant)),
              TranslatedText('Tap to view review work log', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.outline)),
            ],
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchAdminData,
            color: AppTheme.primary,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              itemCount: filtered.length,
              itemBuilder: (context, idx) {
                final exp = filtered[idx];
                final lastReviewStr = exp['last_review_date'] != null
                    ? DateFormat('dd MMM yyyy').format(DateTime.parse(exp['last_review_date']).toLocal())
                    : 'None yet';

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.outlineVariant),
                  ),
                  color: AppTheme.surfaceContainerLowest,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _showExpertDetailsModal(exp['id']),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E88E5).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.biotech_rounded, color: Color(0xFF1E88E5), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TranslatedText(
                                      exp['name'] ?? 'Agronomist #${exp['id']}',
                                      style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primary),
                                    ),
                                    TranslatedText(
                                      'Phone: ${exp['phone']}',
                                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: AppTheme.outline),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.verified_rounded, size: 15, color: Color(0xFF2E7D32)),
                                  const SizedBox(width: 4),
                                  TranslatedText('${exp['reviews_completed']} Reviews Done',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
                                ],
                              ),
                              TranslatedText('Last review: $lastReviewStr', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.outline)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── PROFILE TAB ───────────────────────────────────────────────────────────
  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primary, width: 2),
                ),
                child: const Icon(Icons.security_rounded, size: 40, color: AppTheme.primary),
              ),
              const SizedBox(height: 14),
              TranslatedText('System Administrator', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary)),
              TranslatedText('Full Oversight & Auditing Access', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF1B381A), borderRadius: BorderRadius.circular(12)),
                child: TranslatedText('ROLE: SYSTEM ADMIN',
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.1)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // System Health Card
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
              TranslatedText('SYSTEM ARCHITECTURE & STATUS',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AppTheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              _buildStatusRow('PostgreSQL Core DB', 'CONNECTED (Localhost)', Icons.check_circle_rounded, const Color(0xFF2E7D32)),
              const SizedBox(height: 8),
              _buildStatusRow('AI Diagnosis Engine', 'ONLINE (YOLOv8 + ResNet)', Icons.check_circle_rounded, const Color(0xFF2E7D32)),
              const SizedBox(height: 8),
              _buildStatusRow('GIS Hotspot Service', 'ACTIVE (Spatial SRS 4326)', Icons.check_circle_rounded, const Color(0xFF2E7D32)),
              const SizedBox(height: 8),
              _buildStatusRow('Role-Based Access Control', 'STRICT (3 Fixed Roles)', Icons.shield_rounded, AppTheme.primary),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Sign out button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.error,
            side: const BorderSide(color: AppTheme.error),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.logout_rounded),
          label: TranslatedText('Sign Out of Admin Console', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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
    );
  }

  Widget _buildStatusRow(String title, String status, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(child: TranslatedText(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500))),
        TranslatedText(status, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Overview Command', 'Farmers Directory', 'Experts Directory', 'Surveillance Map', 'Admin Profile'];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: TranslatedText(
          titles[_currentTabIndex],
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.primary),
        ),
        elevation: 0,
        backgroundColor: AppTheme.surfaceContainerLowest,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
            tooltip: 'Refresh Data',
            onPressed: _fetchAdminData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.error),
                        const SizedBox(height: 12),
                        TranslatedText(_errorMessage!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppTheme.error)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchAdminData,
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                          child: const TranslatedText('Retry', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : IndexedStack(
                  index: _currentTabIndex,
                  children: [
                    _buildOverviewTab(),
                    _buildFarmersTab(),
                    _buildExpertsTab(),
                    const HotspotMapScreen(showBackButton: false),
                    _buildProfileTab(),
                  ],
                ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        backgroundColor: AppTheme.surfaceContainerLowest,
        indicatorColor: AppTheme.primary.withValues(alpha: 0.12),
        onDestinationSelected: (idx) => setState(() => _currentTabIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: AppTheme.primary),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.agriculture_outlined),
            selectedIcon: Icon(Icons.agriculture_rounded, color: AppTheme.primary),
            label: 'Farmers',
          ),
          NavigationDestination(
            icon: Icon(Icons.biotech_outlined),
            selectedIcon: Icon(Icons.biotech_rounded, color: AppTheme.primary),
            label: 'Experts',
          ),
          NavigationDestination(
            icon: Icon(Icons.travel_explore_outlined),
            selectedIcon: Icon(Icons.travel_explore_rounded, color: AppTheme.primary),
            label: 'Outbreaks',
          ),
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings_rounded, color: AppTheme.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }


  Widget _buildScansChart() {
    // Generate mock data for the last 7 days for the chart
    return Container(
      width: double.infinity,
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranslatedText('Scan Diagnostics (Last 7 Days)', 
            style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary)),
          const SizedBox(height: 20),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 50,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(days[value.toInt() % 7], style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant)),
                        );
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        return Text(value.toInt().toString(), style: GoogleFonts.inter(fontSize: 12, color: AppTheme.outline));
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: AppTheme.outlineVariant.withOpacity(0.2), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 15, color: const Color(0xFF2E7D32), width: 16, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 25, color: const Color(0xFF2E7D32), width: 16, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 10, color: const Color(0xFF2E7D32), width: 16, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 30, color: const Color(0xFF2E7D32), width: 16, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 20, color: const Color(0xFF2E7D32), width: 16, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 5, barRods: [BarChartRodData(toY: 45, color: const Color(0xFF2E7D32), width: 16, borderRadius: BorderRadius.circular(4))]),
                  BarChartGroupData(x: 6, barRods: [BarChartRodData(toY: 35, color: const Color(0xFF2E7D32), width: 16, borderRadius: BorderRadius.circular(4))]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}