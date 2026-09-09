import 'package:flutter/material.dart';
import 'package:cropdect/theme.dart';
import 'dart:ui';
import 'dashboard_screen.dart';
import 'weather_irrigation_screen.dart';
import 'ai_scan_camera_screen.dart';
import 'package:cropdect/screens/profile_screen.dart';
import 'package:cropdect/models/farm.dart';
import 'package:cropdect/services/farm_service.dart';
import 'package:geolocator/geolocator.dart';

class CropLibraryScreen extends StatefulWidget {
  const CropLibraryScreen({Key? key}) : super(key: key);

  @override
  State<CropLibraryScreen> createState() => _CropLibraryScreenState();
}

class _CropLibraryScreenState extends State<CropLibraryScreen> {
  final int _selectedIndex = 1; // Fields index
  List<Farm> _allFarms = [];
  List<Farm> _filteredFarms = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';

  final List<String> _filters = ['All', 'Loam', 'Clay', 'Sandy', 'Silt'];

  @override
  void initState() {
    super.initState();
    _loadFarms();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFarms() async {
    setState(() => _isLoading = true);
    try {
      final farms = await farmService.getFarms();
      if (mounted) {
        setState(() {
          _allFarms = farms;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredFarms = _allFarms.where((f) {
        final matchesQuery = query.isEmpty ||
            f.name.toLowerCase().contains(query) ||
            (f.soilType?.toLowerCase().contains(query) ?? false);
        final matchesChip = _selectedFilter == 'All' ||
            (f.soilType?.toLowerCase().contains(_selectedFilter.toLowerCase()) ?? false);
        return matchesQuery && matchesChip;
      }).toList();
    });
  }

  Future<void> _showAddFieldDialog() async {
    final nameCtrl = TextEditingController();
    final areaCtrl = TextEditingController();
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    String selectedSoil = 'Loamy';

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
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }

    final created = await showModalBottomSheet<bool>(
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
              const Text(
                'Add New Field / Farm',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Field / Farm Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: areaCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Area (in Hectares)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedSoil,
                decoration: InputDecoration(
                  labelText: 'Soil Type',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: ['Loamy', 'Clay', 'Sandy', 'Silty', 'Peaty', 'Saline']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
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
                label: const Text('Use Current GPS Location'),
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
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final area = double.tryParse(areaCtrl.text.trim()) ?? 1.0;
                    final lat = double.tryParse(latCtrl.text.trim()) ?? 0.0;
                    final lng = double.tryParse(lngCtrl.text.trim()) ?? 0.0;
                    try {
                      await farmService.createFarm({
                        'name': nameCtrl.text.trim(),
                        'area': area,
                        'soil_type': selectedSoil,
                        'latitude': lat,
                        'longitude': lng,
                      });
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Failed to add field: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Add Field', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (created == true) {
      _loadFarms();
    }
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const DashboardScreen(),
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
        child: CustomScrollView(
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
                  const Text(
                    'cropdect',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary, size: 28),
                  tooltip: 'Add Field',
                  onPressed: _showAddFieldDialog,
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search and Filter Controls
                    _buildSearchAndFilter(),
                    const SizedBox(height: 24),

                    // Cards
                    if (_isLoading)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ))
                    else if (_filteredFarms.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: AppTheme.outline),
                            const SizedBox(height: 12),
                            Text(
                              _allFarms.isEmpty ? 'No fields configured yet.' : 'No fields match your search.',
                              style: const TextStyle(color: AppTheme.onSurfaceVariant),
                            ),
                            if (_allFarms.isEmpty) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _showAddFieldDialog,
                                icon: const Icon(Icons.add, color: Colors.white),
                                label: const Text('Add Your First Field', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                              ),
                            ]
                          ],
                        ),
                      )
                    else
                      Column(
                        children: _filteredFarms.map((farm) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: _buildFieldCard(
                              sector: farm.name,
                              cropName: 'Area: ${farm.area} ha',
                              healthIndex: 'Active',
                              healthColor: AppTheme.primary,
                              detailLabel: 'Soil Type',
                              detailValue: farm.soilType ?? 'Unknown',
                              detailColor: AppTheme.onSurface,
                              status: 'Monitoring',
                              statusBgColor: AppTheme.secondaryFixed,
                              statusTextColor: AppTheme.onSecondaryFixed,
                              statusIconColor: AppTheme.onSecondaryFixed,
                              imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDWvzaKgY0kh-dCFtFC1riyNRQXYh8EH6nePxIlEe63a0BRDmTMojEd6IYzV7CcXpJMYtz_RIv1GpYodZ0qzWVnozdIsnYW06K-ciAHUUV66tkf7FxHANljsZXRUWC7Cra6x5Mnh3fyserxIORgSSDsT9cbLMb_cs-TG_TT6cSCk0nJAMYjDf4vSvb_QJePRSBeZIWSzRJzTtx2eL7LAJZyQzqxaaICvz61anP-8XXqWv5PIDd0rcoQ',
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildSearchAndFilter() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => _applyFilter(),
          decoration: InputDecoration(
            hintText: 'Search fields by name or soil...',
            prefixIcon: const Icon(Icons.search, color: AppTheme.outline),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: AppTheme.outline),
                    onPressed: () {
                      _searchController.clear();
                      _applyFilter();
                    },
                  )
                : null,
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: _filters.map((f) {
              final isSelected = _selectedFilter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedFilter = f);
                    _applyFilter();
                  },
                  child: _buildFilterChip(f, isSelected: isSelected),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primary.withValues(alpha: 0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppTheme.primary : AppTheme.outlineVariant.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppTheme.primary : AppTheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildFieldCard({
    required String sector,
    required String cropName,
    required String healthIndex,
    required Color healthColor,
    required String detailLabel,
    required String detailValue,
    required Color detailColor,
    Color? detailBgColor,
    Color? detailBorderColor,
    required String status,
    required Color statusBgColor,
    required Color statusTextColor,
    required Color statusIconColor,
    required String imageUrl,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Image Header
          SizedBox(
            height: 128,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(imageUrl, fit: BoxFit.cover),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        AppTheme.surface,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusIconColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          status,
                          style: TextStyle(
                            color: statusTextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Card Content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sector.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.outline,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  cropName,
                  style: const TextStyle(
                    color: AppTheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Avg Health Index',
                              style: TextStyle(color: AppTheme.outline, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              healthIndex,
                              style: TextStyle(fontFamily: 'JetBrains Mono', color: healthColor, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: detailBgColor ?? AppTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: detailBorderColor ?? AppTheme.outlineVariant.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              detailLabel,
                              style: TextStyle(
                                color: detailBgColor != null ? detailColor : AppTheme.outline,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              detailValue,
                              style: TextStyle(fontFamily: 'JetBrains Mono', color: detailColor, fontSize: 14, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
            Text(
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
