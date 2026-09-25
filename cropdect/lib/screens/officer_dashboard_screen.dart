import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../api_client.dart';
import 'hotspot_map_screen.dart';
import 'expert_review_screen.dart';
import '../widgets/translated_text.dart';

class OfficerDashboardScreen extends StatefulWidget {
  const OfficerDashboardScreen({super.key});

  @override
  State<OfficerDashboardScreen> createState() => _OfficerDashboardScreenState();
}

class _OfficerDashboardScreenState extends State<OfficerDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  List<dynamic> _distribution = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final statsRes = await apiClient.get('/analytics/stats');
      final distRes = await apiClient.get('/analytics/distribution');

      if (mounted) {
        setState(() {
          _stats = statsRes.data is Map<String, dynamic> ? statsRes.data : null;
          _distribution = distRes.data?['distribution'] is List ? distRes.data['distribution'] : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load analytics data. Ensure you have Officer/Admin privileges.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchDashboardData,
          color: AppTheme.primary,
          child: CustomScrollView(
            slivers: [
              // Header App Bar
              SliverAppBar(
                pinned: true,
                backgroundColor: AppTheme.surfaceContainerHighest.withValues(alpha: 0.9),
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, color: AppTheme.primary, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: TranslatedText(
                  'Agricultural Officer Command',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.primary),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.map_rounded, color: AppTheme.primary),
                    tooltip: 'Hotspot Surveillance Map',
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const HotspotMapScreen()));
                    },
                  ),
                ],
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subtitle
                      TranslatedText(
                        'REGIONAL SURVEILLANCE & PLANNING',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TranslatedText(
                        'Pest & Crop Health Analytics',
                        style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.onSurface),
                      ),
                      const SizedBox(height: 18),

                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_errorMessage != null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 30),
                            child: Column(
                              children: [
                                const Icon(Icons.shield_outlined, size: 48, color: Colors.orange),
                                const SizedBox(height: 12),
                                TranslatedText(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurface),
                                ),
                                const SizedBox(height: 14),
                                ElevatedButton(onPressed: _fetchDashboardData, child: const TranslatedText('Retry')),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        // ── KPI CARDS GRID ──────────────────────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: _buildKpiCard(
                                title: 'Registered Farms',
                                value: '${_stats?['total_farms_registered'] ?? 0}',
                                icon: Icons.agriculture_rounded,
                                iconColor: const Color(0xFF276C00),
                                iconBg: const Color(0xFFE8F5E9),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildKpiCard(
                                title: 'Scans Processed',
                                value: '${_stats?['total_diagnoses_processed'] ?? 0}',
                                icon: Icons.document_scanner_rounded,
                                iconColor: Colors.blue.shade700,
                                iconBg: const Color(0xFFE0F2FE),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildKpiCard(
                                title: 'Active Outbreaks',
                                value: '${_stats?['active_unresolved_issues'] ?? 0}',
                                icon: Icons.warning_amber_rounded,
                                iconColor: AppTheme.error,
                                iconBg: const Color(0xFFFFEDE6),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _buildKpiCard(
                                title: 'Surveillance Alert',
                                value: (_stats?['active_unresolved_issues'] ?? 0) > 5 ? 'ELEVATED' : 'STABLE',
                                icon: Icons.health_and_safety_rounded,
                                iconColor: (_stats?['active_unresolved_issues'] ?? 0) > 5 ? Colors.orange.shade800 : const Color(0xFF276C00),
                                iconBg: const Color(0xFFF1F8E9),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // ── QUICK ACTION HERO BANNERS ──────────────────────────────
                        GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const HotspotMapScreen()));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF012D1D), Color(0xFF1B4332)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF012D1D).withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF81FF45).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.travel_explore_rounded, color: Color(0xFF81FF45), size: 28),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      TranslatedText(
                                        'Open Geospatial Hotspot Map',
                                        style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                                      ),
                                      const SizedBox(height: 2),
                                      TranslatedText(
                                        'View GIS heatmaps & disease clusters in real time',
                                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpertReviewScreen()));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.rate_review_rounded, color: Colors.deepPurple, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      TranslatedText(
                                        'Triage & Agronomist Queue',
                                        style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.onSurface),
                                      ),
                                      TranslatedText(
                                        'Validate farmer scans & refer samples to laboratory',
                                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.onSurfaceVariant, size: 14),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── TOP 10 DISEASE DISTRIBUTION ────────────────────────────
                        TranslatedText(
                          'TOP REGIONAL THREATS',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TranslatedText(
                          'Disease & Pest Frequency Distribution',
                          style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.onSurface),
                        ),
                        const SizedBox(height: 16),

                        if (_distribution.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
                            ),
                            child: Center(
                              child: TranslatedText(
                                'No disease reports recorded in this period yet.',
                                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant),
                              ),
                            ),
                          )
                        else
                          ..._buildDistributionBars(),

                        const SizedBox(height: 40),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          TranslatedText(
            value,
            style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.onSurface),
          ),
          const SizedBox(height: 2),
          TranslatedText(
            title,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDistributionBars() {
    int maxCount = 1;
    for (final item in _distribution) {
      final count = (item['count'] as num?)?.toInt() ?? 0;
      if (count > maxCount) maxCount = count;
    }

    return _distribution.map((item) {
      final name = item['disease_name'] ?? 'Unknown';
      final count = (item['count'] as num?)?.toInt() ?? 0;
      final ratio = (count / maxCount).clamp(0.05, 1.0);

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TranslatedText(
                    name,
                    style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.onSurface),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TranslatedText(
                  '$count reports',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  Container(height: 8, width: double.infinity, color: AppTheme.surfaceContainerHigh),
                  FractionallySizedBox(
                    widthFactor: ratio,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF276C00), Color(0xFF81FF45)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
