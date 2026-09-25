import 'package:flutter/material.dart';
import 'package:cropdect/theme.dart';
import 'dart:ui';
import 'weather_irrigation_screen.dart';
import 'crop_library_screen.dart';
import 'ai_scan_camera_screen.dart';
import 'package:cropdect/models/farm.dart';
import 'package:cropdect/services/farm_service.dart';
import 'package:cropdect/models/weather.dart';
import 'package:cropdect/screens/profile_screen.dart';
import 'package:cropdect/screens/detection_result_screen.dart';
import 'package:cropdect/screens/chat_screen.dart';
import 'package:cropdect/models/user.dart';
import 'package:cropdect/services/user_service.dart';
import 'hotspot_map_screen.dart';
import 'consult_expert_screen.dart';
import 'expert_home_screen.dart';
import 'admin_dashboard_screen.dart';

import 'package:cropdect/models/diagnosis.dart';
import 'package:cropdect/services/diagnostic_service.dart';
import 'package:cropdect/services/notification_service.dart';
import 'notifications_screen.dart';
import '../api_client.dart';
import '../widgets/translated_text.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0; // Home index
  late Future<List<Farm>> _farmsFuture;
  late Future<Weather?> _weatherFuture;
  late Future<List<Diagnosis>> _diagnosesFuture;
  late Future<User> _userFuture;
  User? _cachedUser;
  int _unreadNotifications = 0;

  Future<void> _fetchUnreadNotifications() async {
    try {
      final notifications = await notificationService.getNotifications(unreadOnly: true);
      if (mounted) {
        setState(() {
          _unreadNotifications = notifications.length;
        });
      }
    } catch (_) {}
  }

  String _resolveImageUrl(String path) {
    if (path.isEmpty) return 'https://via.placeholder.com/400';
    if (path.startsWith('http')) return path;
    if (!path.startsWith('/')) path = '/$path';
    return 'http://10.0.2.2:8000$path';
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _userFuture = userService.getCurrentUser().then((u) {
        if (mounted) setState(() => _cachedUser = u);
        return u;
      });
      _farmsFuture = farmService.getFarms();
      _diagnosesFuture = diagnosticService.getDiagnosticHistory();
      _weatherFuture = _farmsFuture.then((farms) {
        if (farms.isNotEmpty) {
          return farmService.getFarmWeather(farms.first.id);
        }
        return null;
      });
    });
    await Future.wait([
      _userFuture,
      _farmsFuture,
      _diagnosesFuture,
      _weatherFuture.catchError((_) => null),
      _fetchUnreadNotifications(),
    ]);
  }

  @override
  void initState() {
    super.initState();
    _fetchUnreadNotifications();
    _userFuture = userService.getCurrentUser().then((u) {
      if (mounted) {
        setState(() => _cachedUser = u);
        if (u.role == 'ADMIN') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
          );
        } else if (u.role == 'EXPERT' || u.role == 'EXTENSION_WORKER') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ExpertHomeScreen()),
          );
        }
      }
      return u;
    });
    _farmsFuture = farmService.getFarms();
    _diagnosesFuture = diagnosticService.getDiagnosticHistory();

    _weatherFuture = _farmsFuture.then((farms) {
      if (farms.isNotEmpty) {
        return farmService.getFarmWeather(farms.first.id);
      }
      return null;
    });
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    if (index == 1) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const CropLibraryScreen(),
          transitionDuration: Duration.zero,
        ),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const AIScanCameraScreen(),
          transitionDuration: Duration.zero,
        ),
      );
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const WeatherIrrigationScreen(),
          transitionDuration: Duration.zero,
        ),
      );
    } else if (index == 4) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const ProfileScreen(),
          transitionDuration: Duration.zero,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
              pinned: true,
              backgroundColor: AppTheme.surfaceContainerHigh.withValues(alpha: 0.8),
              elevation: 0,
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Container(color: Colors.transparent),
                ),
              ),
              title: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset('assets/app_logo.jpg', height: 28, width: 28, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  const TranslatedText(
                    'cropdect',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.travel_explore_rounded, color: AppTheme.primary),
                  tooltip: 'Disease Hotspot Map',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HotspotMapScreen()),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.smart_toy_outlined, color: AppTheme.primary),
                  tooltip: 'AI Agronomist',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatScreen()),
                    );
                  },
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none, color: AppTheme.onSurface),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                        );
                        // Refresh unread count when returning
                        _fetchUnreadNotifications();
                      },
                    ),
                    if (_unreadNotifications > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: TranslatedText(
                            '$_unreadNotifications',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TranslatedText(
                      'Welcome back,',
                      style: TextStyle(
                        color: AppTheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FutureBuilder<User>(
                      future: _userFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const TranslatedText('Loading...', style: TextStyle(color: AppTheme.primary, fontSize: 30, fontWeight: FontWeight.bold));
                        } else if (snapshot.hasError || !snapshot.hasData) {
                          return const TranslatedText('Farmer', style: TextStyle(color: AppTheme.primary, fontSize: 30, fontWeight: FontWeight.bold));
                        }
                        return TranslatedText(
                          snapshot.data!.name ?? 'Farmer',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Farmer Experience
                    _buildQuickActionHero(),
                    const SizedBox(height: 16),
                    _buildFarmerToolShortcuts(),
                    const SizedBox(height: 24),

                    // Expert Reviews & Advisories (Farmer Perspective)
                    FutureBuilder<List<Diagnosis>>(
                      future: _diagnosesFuture,
                      builder: (context, snapshot) {
                        final diagnoses = snapshot.data ?? [];
                        return _buildFarmerExpertReviewsSection(diagnoses, snapshot.connectionState == ConnectionState.waiting);
                      },
                    ),
                    const SizedBox(height: 24),

                    // Weather Snapshot
                    FutureBuilder<Weather?>(
                      future: _weatherFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                          return const SizedBox();
                        }
                        return _buildWeatherSnapshot(snapshot.data!);
                      },
                    ),
                    const SizedBox(height: 24),

                    // Field Status Cards
                    const TranslatedText(
                      'FIELD STATUS',
                      style: TextStyle(
                        color: AppTheme.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<Farm>>(
                      future: _farmsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return TranslatedText('Error loading fields', style: TextStyle(color: AppTheme.error));
                        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const TranslatedText('No fields configured.', style: TextStyle(color: AppTheme.onSurfaceVariant));
                        }
                        return _buildFieldStatusList(snapshot.data!);
                      },
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildQuickActionHero() {

    return GestureDetector(
      onTap: () {
        _onItemTapped(2); // Go to Scan
      },
      child: Container(
        decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 160,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              image: DecorationImage(
                image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuDWvzaKgY0kh-dCFtFC1riyNRQXYh8EH6nePxIlEe63a0BRDmTMojEd6IYzV7CcXpJMYtz_RIv1GpYodZ0qzWVnozdIsnYW06K-ciAHUUV66tkf7FxHANljsZXRUWC7Cra6x5Mnh3fyserxIORgSSDsT9cbLMb_cs-TG_TT6cSCk0nJAMYjDf4vSvb_QJePRSBeZIWSzRJzTtx2eL7LAJZyQzqxaaICvz61anP-8XXqWv5PIDd0rcoQ'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: const TranslatedText(
                'AI Diagnostics Ready',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _onItemTapped(2); // Go to Scan
                    },
                    icon: const Icon(Icons.document_scanner, color: AppTheme.onPrimaryContainer),
                    label: const TranslatedText('Scan Crop', style: TextStyle(color: AppTheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryFixed,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChatScreen()),
                      );
                    },
                    icon: const Icon(Icons.smart_toy_rounded, color: AppTheme.primary),
                    label: const TranslatedText('Ask AI', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primary, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildFarmerToolShortcuts() {
    return Row(
      children: [
        // Outbreak Map Shortcut
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HotspotMapScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.travel_explore_rounded, color: Color(0xFF276C00), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TranslatedText(
                          'Outbreak Map',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.onSurface),
                        ),
                        TranslatedText(
                          'Regional Alerts',
                          style: TextStyle(fontSize: 10, color: AppTheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Consult Agronomist
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ConsultExpertScreen()),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.support_agent_rounded, color: Color(0xFF1565C0), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TranslatedText(
                              'Expert Consult',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.onSurface),
                            ),
                            TranslatedText(
                              'Request Review',
                              style: TextStyle(fontSize: 10, color: AppTheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showRequestReviewSheet(BuildContext context, List<Diagnosis> allDiagnoses) {
    final unreviewed = allDiagnoses.where((d) =>
      d.status != 'EXPERT_REVIEW' &&
      d.status != 'CONFIRMED' &&
      d.status != 'CORRECTED' &&
      d.status != 'LAB_REFERRED'
    ).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const TranslatedText(
              'Submit Scan for Expert Review',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary),
            ),
            const SizedBox(height: 6),
            const TranslatedText(
              'Select a recent crop scan to submit to certified agronomists for diagnosis validation and prescription advice.',
              style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            if (unreviewed.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: TranslatedText(
                    allDiagnoses.isEmpty
                        ? 'No scans found yet. Scan crop leaves to get started!'
                        : 'All your scans are already submitted or reviewed by experts.',
                    style: const TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: unreviewed.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final d = unreviewed[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _resolveImageUrl(d.imageUrl),
                              width: 46,
                              height: 46,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 46,
                                height: 46,
                                color: AppTheme.surfaceContainerHigh,
                                child: const Icon(Icons.eco_rounded, color: AppTheme.primary, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TranslatedText(
                                  '${d.cropName ?? "Crop"} • ${d.label ?? "Scan"}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.onSurface),
                                ),
                                TranslatedText(
                                  'Confidence: ${(d.confidence * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              try {
                                await diagnosticService.requestExpertReview(d.id);
                                if (mounted) {
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    const SnackBar(
                                      content: TranslatedText('Scan submitted for agronomist review!'),
                                      backgroundColor: Color(0xFF276C00),
                                    ),
                                  );
                                  setState(() {
                                    _diagnosesFuture = diagnosticService.getDiagnosticHistory();
                                  });
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(
                                      content: TranslatedText('Submission failed: $e'),
                                      backgroundColor: AppTheme.error,
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const TranslatedText('Request', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmerExpertReviewsSection(List<Diagnosis> diagnoses, bool isLoading) {
    // Diagnoses with expert notes or review statuses
    final reviewedOrPending = diagnoses.where((d) =>
      d.expertNotes != null ||
      d.status == 'CONFIRMED' ||
      d.status == 'CORRECTED' ||
      d.status == 'EXPERT_REVIEW' ||
      d.status == 'LAB_REFERRED'
    ).toList();

    final unreviewed = diagnoses.where((d) =>
      d.status != 'EXPERT_REVIEW' &&
      d.status != 'CONFIRMED' &&
      d.status != 'CORRECTED' &&
      d.status != 'LAB_REFERRED'
    ).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: Color(0xFF1E88E5), size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: TranslatedText(
                      'EXPERT REVIEWS & ADVISORIES',
                      style: TextStyle(
                        color: AppTheme.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ConsultExpertScreen()),
                );
              },
              icon: const Icon(Icons.forum_outlined, size: 14, color: AppTheme.primary),
              label: const TranslatedText(
                'All Reviews',
                style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else if (reviewedOrPending.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.biotech_rounded, color: Color(0xFF276C00), size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TranslatedText(
                            'No Expert Reviews Yet',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.onSurface),
                          ),
                          SizedBox(height: 2),
                          TranslatedText(
                            'Scan crop leaves with your camera, then submit for official agronomist review and treatment prescriptions.',
                            style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (unreviewed.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showRequestReviewSheet(context, diagnoses),
                      icon: const Icon(Icons.send_rounded, size: 14),
                      label: const TranslatedText('Submit Recent Scan to Expert', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF276C00),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          )
        else ...[
          ...reviewedOrPending.take(3).map((d) {
            final isCorrected = d.status == 'CORRECTED';
            final isPending = d.status == 'EXPERT_REVIEW';
            final isLab = d.status == 'LAB_REFERRED';

            Color badgeBg = const Color(0xFFE8F5E9);
            Color badgeFg = const Color(0xFF2E7D32);
            String statusText = 'VERIFIED BY EXPERT';

            if (isCorrected) {
              badgeBg = const Color(0xFFFFF3E0);
              badgeFg = const Color(0xFFE65100);
              statusText = 'CORRECTED BY EXPERT';
            } else if (isPending) {
              badgeBg = const Color(0xFFEDE7F6);
              badgeFg = const Color(0xFF5E35B1);
              statusText = 'AWAITING EXPERT REVIEW';
            } else if (isLab) {
              badgeBg = const Color(0xFFE0F7FA);
              badgeFg = const Color(0xFF00695C);
              statusText = 'REFERRED TO LAB';
            }

            final expertLabel = d.label ?? d.modelVersion ?? 'Crop Scan';
            final cropTitle = d.cropName ?? 'Crop';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ConsultExpertScreen(highlightDiagnosisId: d.id),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              _resolveImageUrl(d.imageUrl),
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 50,
                                height: 50,
                                color: AppTheme.surfaceContainerHigh,
                                child: const Icon(Icons.eco_rounded, color: AppTheme.primary, size: 24),
                              ),
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
                                    Expanded(
                                      child: TranslatedText(
                                        '$cropTitle • $expertLabel',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.onSurface),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: badgeBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: TranslatedText(
                                        statusText,
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: badgeFg),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                TranslatedText(
                                  d.expertName != null
                                      ? 'Reviewed by: ${d.expertName}'
                                      : (isPending ? 'Awaiting agronomist review' : 'Certified Agronomist'),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1565C0)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (d.expertNotes != null && d.expertNotes!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F8E9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFC8E6C9)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.format_quote_rounded, size: 16, color: Color(0xFF2E7D32)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: TranslatedText(
                                  d.expertNotes!,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF1B5E20), fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      ],
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetectionResultScreen(
                          resultData: {
                            'id': d.id,
                            'diagnosis_type': d.diagnosisType.toString().split('.').last,
                            'label': d.label,
                            'confidence': d.confidence,
                            'severity': d.severity.toString().split('.').last,
                            'crop_name': d.cropName ?? 'Crop',
                            'image_url': d.imageUrl,
                          },
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TranslatedText(
                          'Tap to view IPM treatment plan',
                          style: TextStyle(fontSize: 10, color: AppTheme.primary.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.chevron_right_rounded, size: 14, color: AppTheme.primary.withValues(alpha: 0.8)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            ),
          );
          }),
          if (unreviewed.isNotEmpty) ...[
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () => _showRequestReviewSheet(context, diagnoses),
              icon: const Icon(Icons.add_task_rounded, size: 16, color: Color(0xFF1565C0)),
              label: TranslatedText(
                'Request Expert Review (${unreviewed.length} scan${unreviewed.length == 1 ? '' : 's'})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF90CAF9)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                minimumSize: const Size(double.infinity, 42),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildWeatherSnapshot(Weather weather) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TranslatedText('Primary Field', style: TextStyle(color: AppTheme.onPrimaryContainer, fontSize: 14)),
                const SizedBox(height: 4),
                TranslatedText('${weather.currentTempC.toStringAsFixed(1)}°C', style: const TextStyle(color: AppTheme.primaryFixed, fontSize: 36, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(Icons.wb_sunny, color: AppTheme.secondaryFixed, size: 36),
                const SizedBox(height: 8),
                TranslatedText('Risk: ${weather.riskLevel}', textAlign: TextAlign.right, style: const TextStyle(color: AppTheme.primaryFixed, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldStatusList(List<Farm> farms) {
    return Column(
      children: farms.map((farm) {
        return GestureDetector(
          onTap: () => _onItemTapped(1), // Go to Fields/Library
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _buildFieldStatusItem(
              farm.name, 
              '${farm.area} ha', 
              farm.soilType ?? 'Unknown Soil', 
              AppTheme.secondaryFixed
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFieldStatusItem(String title, String crop, String status, Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TranslatedText(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.onSurface)),
              const SizedBox(height: 4),
              TranslatedText(crop, style: const TextStyle(color: AppTheme.onSurfaceVariant)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TranslatedText(
              status,
              style: TextStyle(color: statusColor == Colors.orange ? const Color(0xFF422D00) : AppTheme.onSecondaryFixed, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home, 'Home'),
              _buildNavItem(1, Icons.grass, 'Fields'),
              _buildNavItem(2, Icons.center_focus_strong, 'Scan'),
              _buildNavItem(3, Icons.water_drop, 'Weather'),
              _buildNavItem(4, Icons.person, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.onSecondaryContainer : AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 4),
            TranslatedText(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: isSelected ? AppTheme.onSecondaryContainer : AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
