import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cropdect/theme.dart';
import 'package:cropdect/main.dart';
import 'package:cropdect/services/user_service.dart';
import 'package:cropdect/services/farm_service.dart';
import 'package:cropdect/services/diagnostic_service.dart';
import 'package:cropdect/models/user.dart';
import 'package:cropdect/models/farm.dart';
import 'package:cropdect/models/diagnosis.dart';
import 'package:cropdect/screens/login_screen.dart';
import 'package:cropdect/screens/detection_result_screen.dart';
import 'dashboard_screen.dart';
import 'crop_library_screen.dart';
import 'weather_irrigation_screen.dart';
import 'ai_scan_camera_screen.dart';
import 'consult_expert_screen.dart';
import 'hotspot_map_screen.dart';
import 'expert_home_screen.dart';
import 'admin_dashboard_screen.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/translated_text.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final int _selectedIndex = 4;
  bool _isLoading = true;

  User? _user;
  String _selectedLanguage = 'English';
  List<Farm> _farms = [];
  List<Diagnosis> _diagnostics = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        userService.getCurrentUser(),
        farmService.getFarms(),
        diagnosticService.getDiagnosticHistory(),
      ]);
      if (mounted) {
        final u = results[0] as User;
        if (u.role == 'ADMIN') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
          );
          return;
        } else if (u.role == 'EXPERT' || u.role == 'EXTENSION_WORKER') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ExpertHomeScreen()),
          );
          return;
        }

        setState(() {
          _user = u;
          _farms = results[1] as List<Farm>;
          _diagnostics = results[2] as List<Diagnosis>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    Widget next;
    switch (index) {
      case 0: next = const DashboardScreen(); break;
      case 1: next = const CropLibraryScreen(); break;
      case 2: next = const AIScanCameraScreen(); break;
      case 3: next = const WeatherIrrigationScreen(); break;
      default: return;
    }
    Navigator.pushReplacement(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) => next,
      transitionDuration: Duration.zero,
    ));
  }

  Future<void> _editProfile() async {
    final nameCtrl = TextEditingController(text: _user?.name ?? '');
    final emailCtrl = TextEditingController(text: _user?.email ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(nameCtrl: nameCtrl, emailCtrl: emailCtrl),
    );
    if (saved == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await userService.updateUser({'name': nameCtrl.text, 'email': emailCtrl.text});
        await _loadData();
      } catch (e) {
        if (mounted) _showSnack('Failed to update profile');
        setState(() => _isLoading = false);
      }
    }
  }

  void _showLanguagePicker() {
    final Map<String, String> languages = {
      'en': 'English',
      'hi': 'हिंदी (Hindi)',
      'bn': 'বাংলা (Bengali)',
      'mr': 'मराठी (Marathi)',
      'te': 'తెలుగు (Telugu)'
    };
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppTheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            TranslatedText('Select App Language', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.onSurface)),
            const SizedBox(height: 16),
            ...languages.entries.map((entry) {
              final langCode = entry.key;
              final langName = entry.value;
              final isSelected = context.watch<LanguageState>().currentLanguage == langCode;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isSelected ? AppTheme.primary : AppTheme.outline,
                ),
                title: TranslatedText(
                  langName,
                  style: GoogleFonts.inter(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: AppTheme.onSurface,
                  ),
                ),
                onTap: () {
                  context.read<LanguageState>().changeLanguage(langCode);
                  Navigator.pop(ctx);
                  _showSnack('Language updated! Navigation and core screens will now translate dynamically.');
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _editFarm(Farm farm) async {
    final nameCtrl = TextEditingController(text: farm.name);
    final areaCtrl = TextEditingController(text: farm.area.toString());
    final latCtrl = TextEditingController(text: farm.latitude.toString());
    final lngCtrl = TextEditingController(text: farm.longitude.toString());
    String selectedSoil = farm.soilType ?? 'Loamy';

    Future<void> fetchLocation(StateSetter setSheetState) async {
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) throw Exception('Location services are disabled.');
        
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) throw Exception('Location permissions are denied');
        }
        if (permission == LocationPermission.deniedForever) throw Exception('Location permissions are permanently denied');

        Position position = await Geolocator.getCurrentPosition();
        setSheetState(() {
          latCtrl.text = position.latitude.toStringAsFixed(6);
          lngCtrl.text = position.longitude.toStringAsFixed(6);
        });
      } catch (e) {
        if (context.mounted) _showSnack(e.toString());
      }
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
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
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: TranslatedText(
                      'Manage Field / Farm',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
                    tooltip: 'Delete Field',
                    onPressed: () => Navigator.pop(ctx, 'delete'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Field Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: areaCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Area (ha)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: ['Loamy', 'Clay', 'Sandy', 'Silty', 'Peaty', 'Saline'].contains(selectedSoil) ? selectedSoil : 'Loamy',
                decoration: InputDecoration(
                  labelText: 'Soil Type',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: ['Loamy', 'Clay', 'Sandy', 'Silty', 'Peaty', 'Saline']
                    .map((s) => DropdownMenuItem(value: s, child: TranslatedText(s)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setSheetState(() => selectedSoil = val);
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: latCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Latitude',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: lngCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Longitude',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => fetchLocation(setSheetState),
                icon: const Icon(Icons.my_location_rounded, size: 18),
                label: const TranslatedText('Use Current GPS Location'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, 'save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const TranslatedText('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (action == 'save') {
      try {
        final area = double.tryParse(areaCtrl.text.trim()) ?? farm.area;
        final lat = double.tryParse(latCtrl.text.trim()) ?? farm.latitude;
        final lng = double.tryParse(lngCtrl.text.trim()) ?? farm.longitude;
        await farmService.updateFarm(farm.id, {
          'name': nameCtrl.text.trim(),
          'area': area,
          'soil_type': selectedSoil,
          'latitude': lat,
          'longitude': lng,
        });
        _loadData();
      } catch (e) {
        if (mounted) _showSnack('Failed to update farm');
      }
    } else if (action == 'delete') {
      try {
        await farmService.deleteFarm(farm.id);
        _loadData();
      } catch (e) {
        if (mounted) _showSnack('Failed to delete farm');
      }
    }
  }

  Future<void> _deleteScan(int diagnosisId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Delete Scan',
        message: 'Are you sure you want to permanently delete this scan?',
        confirmLabel: 'Delete',
        isDestructive: true,
      ),
    );
    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await diagnosticService.deleteDiagnosis(diagnosisId);
        _loadData();
      } catch (e) {
        if (mounted) _showSnack('Failed to delete scan');
        setState(() => _isLoading = false);
      }
    }
  }
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Logout',
        message: 'Are you sure you want to logout?',
        confirmLabel: 'Logout',
        isDestructive: false,
      ),
    );
    if (confirm == true && mounted) {
      Provider.of<AuthState>(context, listen: false).logout();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Delete Account',
        message: 'This will permanently erase your account, all farms, and all scan history. This action cannot be undone.',
        confirmLabel: 'Delete Permanently',
        isDestructive: true,
      ),
    );
    if (confirm == true && mounted) {
      try {
        await userService.deleteAccount();
        if (!mounted) return;
        Provider.of<AuthState>(context, listen: false).logout();
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      } catch (_) {
        if (mounted) _showSnack('Failed to delete account');
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: TranslatedText(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : CustomScrollView(
              slivers: [
                _buildSliverHeader(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        _buildStatsRow(),
                        const SizedBox(height: 28),
                        _buildSectionLabel('MY FARMS'),
                        const SizedBox(height: 12),
                        _buildFarmsSection(),
                        const SizedBox(height: 28),
                        _buildSectionLabel('RECENT SCANS'),
                        const SizedBox(height: 12),
                        _buildHistorySection(),
                        const SizedBox(height: 28),
                        _buildSectionLabel('ACCOUNT & WORKSPACE'),
                        const SizedBox(height: 12),
                        _buildAccountActions(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildSliverHeader() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppTheme.primary,
      elevation: 0,
      leading: const SizedBox(),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF012D1D), Color(0xFF1B4332), Color(0xFF276C00)],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                // Avatar
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF81FF45), Color(0xFF276C00)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF81FF45).withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: TranslatedText(
                          (_user?.name?.isNotEmpty == true) ? _user!.name![0].toUpperCase() : 'U',
                          style: GoogleFonts.manrope(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _editProfile,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryContainer,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.primary, width: 2),
                        ),
                        child: const Icon(Icons.edit, size: 14, color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Name
                TranslatedText(
                  _user?.name ?? 'Farmer',
                  style: GoogleFonts.manrope(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                // Phone / email
                TranslatedText(
                  _user?.phone ?? _user?.email ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 16),
                // Role pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryContainer.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.secondaryContainer.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, size: 14, color: AppTheme.secondaryContainer),
                      const SizedBox(width: 6),
                      TranslatedText(
                        _user?.role == 'EXPERT'
                            ? 'Agricultural Expert'
                            : (_user?.role == 'ADMIN'
                                ? 'System Administrator'
                                : (_user?.role == 'EXTENSION_WORKER'
                                    ? 'Extension Field Officer'
                                    : 'Registered Farmer')),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.secondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      title: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            children: [
              const SizedBox(width: 4),
              TranslatedText(
                _user?.name ?? 'Profile',
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStatCard(
          icon: Icons.landscape_rounded,
          value: '${_farms.length}',
          label: 'Farms',
          color: const Color(0xFF276C00),
          bg: const Color(0xFFE8F5E9),
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(
          icon: Icons.biotech_rounded,
          value: '${_diagnostics.length}',
          label: 'Scans',
          color: const Color(0xFF012D1D),
          bg: const Color(0xFFC1ECD4),
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(
          icon: Icons.check_circle_rounded,
          value: _diagnostics.isEmpty
              ? '0%'
              : '${(_diagnostics.where((d) => d.diagnosisType == 'HEALTHY').length / _diagnostics.length * 100).toStringAsFixed(0)}%',
          label: 'Healthy',
          color: const Color(0xFF1B4332),
          bg: const Color(0xFFD4EFDF),
        )),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          TranslatedText(value,
            style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          TranslatedText(label,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return TranslatedText(
      text,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: AppTheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildFarmsSection() {
    if (_farms.isEmpty) {
      return _buildEmptyState(
        icon: Icons.landscape_rounded,
        message: 'No farms registered yet.',
      );
    }
    return Column(
      children: _farms.map((f) => _buildFarmCard(f)).toList(),
    );
  }

  Widget _buildFarmCard(Farm farm) {
    return GestureDetector(
      onTap: () => _editFarm(farm),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.landscape_rounded, color: Color(0xFF276C00), size: 22),
          ),
          title: TranslatedText(
            farm.name,
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.onSurface),
          ),
          subtitle: TranslatedText(
            '${farm.area.toStringAsFixed(1)} ha · ${farm.soilType ?? 'Unknown soil'}',
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
          ),
          trailing: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.edit_rounded, color: AppTheme.onSurfaceVariant, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    if (_diagnostics.isEmpty) {
      return _buildEmptyState(
        icon: Icons.biotech_rounded,
        message: 'No scan history yet. Scan a crop to get started.',
      );
    }
    return Column(
      children: _diagnostics.take(5).map((d) => _buildHistoryCard(d)).toList(),
    );
  }

  Widget _buildHistoryCard(Diagnosis d) {
    final isHealthy = d.diagnosisType.toUpperCase() == 'HEALTHY';
    final severityColor = _severityColor(d.severity);
    
    // Use the parsed label (e.g. "Early Blight"), fall back to a clean
    // version of diagnosisType if label is missing.
    final displayLabel = (d.label != null && d.label!.isNotEmpty)
        ? d.label!
        : d.diagnosisType
            .split('_')
            .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1).toLowerCase())
            .join(' ');

    // Show crop name if available, otherwise fall back to "Unknown Crop"
    final displayCropName = (d.cropName != null && d.cropName!.isNotEmpty)
        ? d.cropName!
        : 'Unknown Crop';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetectionResultScreen(
              resultData: {
                'id': d.id,
                'diagnosis_type': d.diagnosisType,
                'label': displayLabel,
                'confidence': d.confidence,
                'severity': d.severity,
                'crop_name': displayCropName,
                'image_url': d.imageUrl,
              },
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isHealthy ? const Color(0xFFE8F5E9) : const Color(0xFFFFEDE6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                d.imageUrl.startsWith('http') ? d.imageUrl : 'http://10.0.2.2:8000${d.imageUrl}',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  isHealthy ? Icons.check_circle_rounded : Icons.biotech_rounded,
                  color: isHealthy ? const Color(0xFF276C00) : AppTheme.error,
                  size: 22,
                ),
              ),
            ),
          ),
          title: TranslatedText(
            displayLabel,
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: TranslatedText(
            '$displayCropName · ${(d.confidence * 100).toInt()}% conf\n${d.createdAt.toString().substring(0, 10)}',
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TranslatedText(
                  d.severity.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: severityColor),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 20),
                onPressed: () => _deleteScan(d.id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'LOW': return const Color(0xFF276C00);
      case 'HIGH': return Colors.orange.shade800;
      case 'CRITICAL': return AppTheme.error;
      default: return Colors.amber.shade800;
    }
  }

  Widget _buildAccountActions() {
    return Column(
      children: [
        _buildActionTile(
          icon: Icons.support_agent_rounded,
          label: 'Consult Expert Reviews',
          subtitle: 'Track your scans submitted for expert validation',
          iconBg: const Color(0xFFE0F2FE),
          iconColor: Colors.blue.shade700,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConsultExpertScreen()),
            );
          },
        ),
        const SizedBox(height: 10),
        _buildActionTile(
          icon: Icons.travel_explore_rounded,
          label: 'Disease Hotspot Map',
          subtitle: 'Geospatial surveillance & regional outbreak mapping',
          iconBg: const Color(0xFFE8F5E9),
          iconColor: const Color(0xFF276C00),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HotspotMapScreen()),
            );
          },
        ),
        const SizedBox(height: 10),
        _buildActionTile(
          icon: Icons.edit_rounded,
          label: 'Edit Profile',
          subtitle: 'Update your name and contact info',
          iconBg: const Color(0xFFE8F5E9),
          iconColor: const Color(0xFF276C00),
          onTap: _editProfile,
        ),
        const SizedBox(height: 10),
        Consumer<LanguageState>(
          builder: (context, languageState, child) {
            final Map<String, String> languages = {
              'en': 'English', 'hi': 'हिंदी (Hindi)', 'bn': 'বাংলা (Bengali)', 'mr': 'मराठी (Marathi)', 'te': 'తెలుగు (Telugu)'
            };
            return _buildActionTile(
              icon: Icons.language_rounded,
              label: 'App Language',
              subtitle: 'Current: ${languages[languageState.currentLanguage] ?? 'English'}',
              iconBg: const Color(0xFFFFF3E0),
              iconColor: Colors.orange.shade800,
              onTap: _showLanguagePicker,
            );
          },
        ),
        const SizedBox(height: 10),
        _buildActionTile(
          icon: Icons.logout_rounded,
          label: 'Logout',
          subtitle: 'Sign out of your account',
          iconBg: const Color(0xFFF0F4FF),
          iconColor: Colors.indigo,
          onTap: _logout,
        ),
        const SizedBox(height: 10),
        _buildActionTile(
          icon: Icons.delete_forever_rounded,
          label: 'Delete Account',
          subtitle: 'Permanently erase all your data',
          iconBg: const Color(0xFFFFEDE6),
          iconColor: AppTheme.error,
          onTap: _deleteAccount,
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color iconBg,
    required Color iconColor,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDestructive
                ? AppTheme.error.withValues(alpha: 0.2)
                : AppTheme.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TranslatedText(
                    label,
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDestructive ? AppTheme.error : AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  TranslatedText(
                    subtitle,
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 10),
          TranslatedText(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant),
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'Home'),
              _buildNavItem(1, Icons.grass_rounded, 'Fields'),
              _buildNavItem(2, Icons.center_focus_strong, 'Scan'),
              _buildNavItem(3, Icons.water_drop_rounded, 'Weather'),
              _buildNavItem(4, Icons.person_rounded, 'Profile'),
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
            Icon(icon, color: isSelected ? AppTheme.onSecondaryContainer : AppTheme.onSurfaceVariant.withValues(alpha: 0.7)),
            const SizedBox(height: 4),
            TranslatedText(label, style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: isSelected ? AppTheme.onSecondaryContainer : AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
            )),
          ],
        ),
      ),
    );
  }
}

// ── Edit Profile Bottom Sheet ─────────────────────────────────────────────────
class _EditProfileSheet extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;

  const _EditProfileSheet({required this.nameCtrl, required this.emailCtrl});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TranslatedText(
                  'Edit Profile',
                  style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.onSurface),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                controller: controller,
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                children: [
                  _buildField(label: 'Full Name', controller: nameCtrl, icon: Icons.person_outline_rounded),
                  const SizedBox(height: 16),
                  _buildField(label: 'Email', controller: emailCtrl, icon: Icons.email_outlined),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: TranslatedText(
                        'Save Changes',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
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

  Widget _buildField({required String label, required TextEditingController controller, required IconData icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TranslatedText(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: AppTheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: GoogleFonts.inter(color: AppTheme.onSurface),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppTheme.onSurfaceVariant, size: 20),
            hintText: label,
            hintStyle: GoogleFonts.inter(color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5)),
          ),
        ),
      ],
    );
  }
}

// ── Confirm Dialog ────────────────────────────────────────────────────────────
class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool isDestructive;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.isDestructive,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: TranslatedText(title,
        style: GoogleFonts.manrope(
          fontWeight: FontWeight.w700,
          color: isDestructive ? AppTheme.error : AppTheme.onSurface,
        ),
      ),
      content: TranslatedText(message,
        style: GoogleFonts.inter(color: AppTheme.onSurfaceVariant),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: TranslatedText('Cancel', style: GoogleFonts.inter(color: AppTheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDestructive ? AppTheme.error : AppTheme.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: TranslatedText(confirmLabel,
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
