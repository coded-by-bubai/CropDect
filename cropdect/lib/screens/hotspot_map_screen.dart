import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../api_client.dart';

class HotspotMapScreen extends StatefulWidget {
  final bool showBackButton;
  const HotspotMapScreen({super.key, this.showBackButton = true});

  @override
  State<HotspotMapScreen> createState() => _HotspotMapScreenState();
}

class _HotspotMapScreenState extends State<HotspotMapScreen> {
  final MapController _mapController = MapController();
  LatLng _currentCenter = const LatLng(20.5937, 78.9629); // Default center (India)
  bool _isLoading = true;
  List<dynamic> _hotspots = [];
  String? _selectedDisease;
  double? _selectedRadiusKm;
  bool _criticalOnly = false;
  bool _showOutbreaks = true;
  Map<String, dynamic>? _selectedMarkerData;
  List<dynamic> _clusters = [];

  @override
  void initState() {
    super.initState();
    _initUserLocationAndFetch();
  }

  Future<void> _initUserLocationAndFetch() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 5)),
      );
      _currentCenter = LatLng(pos.latitude, pos.longitude);
      _mapController.move(_currentCenter, 11.0);
    } catch (_) {}

    await _fetchHotspots();
  }

  Future<void> _fetchHotspots() async {
    setState(() => _isLoading = true);

    try {
      final queryParams = <String, dynamic>{};
      if (_selectedDisease != null && _selectedDisease!.isNotEmpty) {
        queryParams['disease_name'] = _selectedDisease;
      }
      if (_selectedRadiusKm != null) {
        queryParams['radius_km'] = _selectedRadiusKm;
        queryParams['lat'] = _currentCenter.latitude;
        queryParams['lng'] = _currentCenter.longitude;
      }

      final response = await apiClient.get('/diagnostics/hotspots', queryParameters: queryParams);
      if (mounted && response.statusCode == 200) {
        setState(() {
          _hotspots = response.data['hotspots'] ?? [];
          _clusters = response.data['clusters'] ?? [];
          _isLoading = false;
        });

        if (_clusters.isNotEmpty && _selectedRadiusKm == null) {
          final first = _clusters.first;
          final lat = (first['latitude'] as num).toDouble();
          final lng = (first['longitude'] as num).toDouble();
          _mapController.move(LatLng(lat, lng), 9.0);
        } else if (_hotspots.isNotEmpty) {
          final first = _hotspots.first;
          final lat = (first['latitude'] as num).toDouble();
          final lng = (first['longitude'] as num).toDouble();
          final zoom = _selectedRadiusKm == null ? 6.0 : 11.0;
          _mapController.move(LatLng(lat, lng), zoom);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _severityColor(String? severity) {
    switch (severity?.toUpperCase()) {
      case 'CRITICAL':
        return AppTheme.error;
      case 'HIGH':
        return Colors.orange.shade800;
      case 'MODERATE':
        return Colors.amber.shade800;
      case 'LOW':
        return const Color(0xFF276C00);
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayedHotspots = _hotspots.where((spot) {
      if (!_criticalOnly) return true;
      return (spot['severity']?.toString().toUpperCase() == 'CRITICAL');
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // ── MAP LAYER ──────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 10.0,
              minZoom: 3.0,
              maxZoom: 18.0,
              onTap: (tapPosition, point) {
                if (_showOutbreaks && _clusters.isNotEmpty) {
                  const distanceCalc = Distance();
                  for (final c in _clusters) {
                    final lat = (c['latitude'] as num).toDouble();
                    final lng = (c['longitude'] as num).toDouble();
                    final radius = (c['radius_km'] as num).toDouble() * 1000.0;
                    
                    final dist = distanceCalc.distance(point, LatLng(lat, lng));
                    if (dist <= radius) {
                      setState(() {
                        _selectedMarkerData = {
                          'severity': 'CRITICAL',
                          'disease_name': '${c['disease_name']} Outbreak',
                          'crop_name': 'Regional Area (${c['case_count']} cases)',
                          'timestamp': '15km Radius Zone',
                          'latitude': (lat * 1000).round() / 1000,
                          'longitude': (lng * 1000).round() / 1000,
                        };
                      });
                      return; // Stop checking after finding the first one
                    }
                  }
                }
                
                // If not tapped on a cluster, close the selected marker
                if (_selectedMarkerData != null) {
                  setState(() => _selectedMarkerData = null);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.cropdect',
              ),
              if (_showOutbreaks && _clusters.isNotEmpty)
                CircleLayer(
                  circles: _clusters.map((c) {
                    final lat = (c['latitude'] as num).toDouble();
                    final lng = (c['longitude'] as num).toDouble();
                    final radius = (c['radius_km'] as num).toDouble() * 1000.0;
                    return CircleMarker(
                      point: LatLng(lat, lng),
                      color: Colors.red.withValues(alpha: 0.15),
                      borderColor: Colors.red.withValues(alpha: 0.8),
                      borderStrokeWidth: 2,
                      useRadiusInMeter: true,
                      radius: radius,
                    );
                  }).toList(),
                ),

              MarkerLayer(
                markers: displayedHotspots.map((spot) {
                  final lat = (spot['latitude'] as num).toDouble();
                  final lng = (spot['longitude'] as num).toDouble();
                  final severity = spot['severity'] ?? 'MODERATE';
                  final color = _severityColor(severity);

                  return Marker(
                    point: LatLng(lat, lng),
                    width: 46,
                    height: 46,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedMarkerData = spot);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: 0.25),
                          border: Border.all(color: color, width: 2),
                        ),
                        child: Center(
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (_showOutbreaks && _clusters.isNotEmpty)
                MarkerLayer(
                  markers: _clusters.map((c) {
                    final lat = (c['latitude'] as num).toDouble();
                    final lng = (c['longitude'] as num).toDouble();
                    final count = c['case_count'] ?? 0;
                    return Marker(
                      point: LatLng(lat, lng),
                      width: 120,
                      height: 44,
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedMarkerData = {
                                'severity': 'CRITICAL',
                                'disease_name': '${c['disease_name']} Outbreak',
                                'crop_name': 'Regional Area (${c['case_count']} cases)',
                                'timestamp': '15km Radius Zone',
                                'latitude': (lat * 1000).round() / 1000,
                                'longitude': (lng * 1000).round() / 1000,
                              };
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade900,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 3)),
                              ],
                            ),
                            child: Text(
                              '$count Cases',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),

          // ── TOP HEADER / CONTROLS ──────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  // App Bar Card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surface.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                    child: Row(
                      children: [
                        if (widget.showBackButton)
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_rounded, color: AppTheme.primary, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Crop Disease Hotspot Map',
                                style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.primary),
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                                child: Text(
                                  '${displayedHotspots.length} verified surveillance points',
                                  key: ValueKey(displayedHotspots.length),
                                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.my_location_rounded, color: AppTheme.primary),
                          tooltip: 'Recenter to GPS',
                          onPressed: () async {
                            try {
                              LocationPermission permission = await Geolocator.checkPermission();
                              if (permission == LocationPermission.denied) {
                                permission = await Geolocator.requestPermission();
                                if (permission == LocationPermission.denied) return;
                              }
                              if (permission == LocationPermission.deniedForever) return;

                              final pos = await Geolocator.getCurrentPosition();
                              _currentCenter = LatLng(pos.latitude, pos.longitude);
                              _mapController.move(_currentCenter, 13.0);
                            } catch (_) {}
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
                          onPressed: _fetchHotspots,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

                  // Radius Filter Bar
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All Outbreaks', _selectedRadiusKm == null, () {
                          setState(() => _selectedRadiusKm = null);
                          _fetchHotspots();
                        }),
                        const SizedBox(width: 8),
                        _buildFilterChip('Within 15 km', _selectedRadiusKm == 15.0, () {
                          setState(() => _selectedRadiusKm = 15.0);
                          _fetchHotspots();
                        }),
                        const SizedBox(width: 8),
                        _buildFilterChip('Within 50 km', _selectedRadiusKm == 50.0, () {
                          setState(() => _selectedRadiusKm = 50.0);
                          _fetchHotspots();
                        }),
                        const SizedBox(width: 12),
                        Container(width: 1, height: 24, color: AppTheme.outlineVariant),
                        const SizedBox(width: 12),
                        _buildFilterChip('Critical Only', _criticalOnly, () {
                          setState(() {
                            _criticalOnly = !_criticalOnly;
                            // Clear selected marker if it gets hidden
                            if (_criticalOnly && _selectedMarkerData != null) {
                              if (_selectedMarkerData!['severity']?.toString().toUpperCase() != 'CRITICAL') {
                                _selectedMarkerData = null;
                              }
                            }
                          });
                        }),
                        const SizedBox(width: 8),
                        _buildFilterChip('Show Outbreaks', _showOutbreaks, () {
                          setState(() => _showOutbreaks = !_showOutbreaks);
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── LOADING INDICATOR ──────────────────────────────────────────────
          if (_isLoading)
            Positioned(
              top: 140,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Text('Querying geospatial records...', style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),

          // ── MAP LEGEND ─────────────────────────────────────────────────────
          Positioned(
            bottom: _selectedMarkerData != null ? 190 : 20,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegendRow(AppTheme.error, 'Critical (Spread risk)'),
                  const SizedBox(height: 4),
                  _buildLegendRow(Colors.orange.shade800, 'High Severity'),
                  const SizedBox(height: 4),
                  _buildLegendRow(Colors.amber.shade800, 'Moderate'),
                  const SizedBox(height: 4),
                  _buildLegendRow(const Color(0xFF276C00), 'Low / Healthy'),
                ],
              ),
            ),
          ),

          // ── SELECTED MARKER DETAIL CARD ────────────────────────────────────
          if (_selectedMarkerData != null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _severityColor(_selectedMarkerData!['severity']).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            (_selectedMarkerData!['severity'] ?? 'MODERATE').toString().toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _severityColor(_selectedMarkerData!['severity']),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => setState(() => _selectedMarkerData = null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedMarkerData!['disease_name'] ?? 'Crop Disease Outbreak',
                      style: GoogleFonts.manrope(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Crop: ${_selectedMarkerData!['crop_name'] ?? 'Farm plot'} · Reported: ${_selectedMarkerData!['timestamp']?.toString().substring(0, 10) ?? 'Recent'}',
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Coordinates: ${_selectedMarkerData!['latitude']}, ${_selectedMarkerData!['longitude']}',
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isSelected ? AppTheme.primary.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
          ),
          child: Text(label),
        ),
      ),
    );
  }

  Widget _buildLegendRow(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(text, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
      ],
    );
  }
}
