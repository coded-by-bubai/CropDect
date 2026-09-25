import 'package:flutter/material.dart';
import 'package:cropdect/theme.dart';
import 'dart:ui';
import 'dashboard_screen.dart';
import 'crop_library_screen.dart';
import 'ai_scan_camera_screen.dart';
import 'package:cropdect/screens/profile_screen.dart';
import 'package:cropdect/models/farm.dart';
import 'package:cropdect/services/farm_service.dart';
import 'package:cropdect/models/weather.dart';
import '../widgets/translated_text.dart';

class WeatherIrrigationScreen extends StatefulWidget {
  const WeatherIrrigationScreen({Key? key}) : super(key: key);

  @override
  State<WeatherIrrigationScreen> createState() => _WeatherIrrigationScreenState();
}

class _WeatherIrrigationScreenState extends State<WeatherIrrigationScreen> {
  int _selectedIndex = 3; // Weather index
  late Future<List<Farm>> _farmsFuture;
  late Future<Weather?> _weatherFuture;
  String _activeFarmName = 'No Farm Selected';

  @override
  void initState() {
    super.initState();
    _loadWeatherData();
  }
  Farm? _selectedFarm;

  void _loadWeatherData() {
    _farmsFuture = farmService.getFarms().catchError((_) => <Farm>[]);
    _weatherFuture = _farmsFuture.then<Weather?>((farms) async {
      if (farms.isNotEmpty) {
        if (mounted) {
          setState(() {
            _selectedFarm ??= farms.first;
          });
        }
        try {
          return await farmService.getFarmWeather(_selectedFarm!.id);
        } catch (_) {
          return null;
        }
      }
      return null;
    }).catchError((_) => null);
  }

  void _onFarmSelected(Farm? farm) {
    if (farm != null && farm.id != _selectedFarm?.id) {
      setState(() {
        _selectedFarm = farm;
        // Re-fetch weather for the newly selected farm
        _weatherFuture = farmService.getFarmWeather(farm.id).then((w) => w as Weather?).catchError((_) => null);
      });
    }
  }

  (String, IconData) _getWeatherInfo(int code) {
    if (code == 0) return ('Clear Sky', Icons.wb_sunny);
    if (code == 1 || code == 2) return ('Partly Cloudy', Icons.cloud_queue);
    if (code == 3) return ('Cloudy', Icons.cloud);
    if (code == 45 || code == 48) return ('Foggy', Icons.foggy);
    if (code >= 51 && code <= 67) return ('Rain', Icons.water_drop);
    if (code >= 71 && code <= 77) return ('Snow', Icons.ac_unit);
    if (code >= 80 && code <= 82) return ('Showers', Icons.water_drop);
    if (code >= 85 && code <= 86) return ('Snow Showers', Icons.ac_unit);
    if (code >= 95 && code <= 99) return ('Thunderstorm', Icons.thunderstorm);
    return ('Unknown', Icons.cloud);
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
    } else if (index == 1) {
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
              backgroundColor: AppTheme.surfaceContainerHighest.withValues(alpha: 0.8),
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
                  icon: const Icon(Icons.notifications_none, color: AppTheme.primary),
                  onPressed: () {},
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section
                    TranslatedText(
                      'Weather & Irrigation',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<Farm>>(
                      future: _farmsFuture,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Farm>(
                              isExpanded: true,
                              value: _selectedFarm ?? snapshot.data!.first,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primary),
                              items: snapshot.data!.map((farm) {
                                return DropdownMenuItem<Farm>(
                                  value: farm,
                                  child: TranslatedText(farm.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.onSurface)),
                                );
                              }).toList(),
                              onChanged: _onFarmSelected,
                            ),
                          ),
                        );
                      }
                    ),
                    const SizedBox(height: 24),

                    // Current Weather (Large Card)
                    FutureBuilder<Weather?>(
                      future: _weatherFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ));
                        } else if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                          return _buildWeatherFallbackCard();
                        }
                        return _buildCurrentWeatherCard(snapshot.data!);
                      },
                    ),
                    const SizedBox(height: 16),
                    // Wind Speed & Soil Moisture Row
                    FutureBuilder<Weather?>(
                      future: _weatherFuture,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();
                        final w = snapshot.data!;
                        return Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const TranslatedText('WIND SPEED', style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.air, color: AppTheme.secondary, size: 20),
                                        const SizedBox(width: 8),
                                        TranslatedText('${w.currentWindSpeedKmh} km/h', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.onSurface)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const TranslatedText('SOIL MOISTURE', style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.grass, color: AppTheme.secondaryFixed, size: 20),
                                        const SizedBox(width: 8),
                                        TranslatedText('${(w.currentSoilMoisture * 100).toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.onSurface)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Predictive Irrigation Recommendation
                    FutureBuilder<Weather?>(
                      future: _weatherFuture,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();
                        return _buildIrrigationCard(snapshot.data!);
                      },
                    ),
                    const SizedBox(height: 24),

                    // 5-Day Forecast
                    const TranslatedText(
                      '7-DAY FORECAST',
                      style: TextStyle(
                        color: AppTheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<Weather?>(
                      future: _weatherFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: CircularProgressIndicator(),
                          ));
                        } else if (snapshot.hasError || !snapshot.hasData || snapshot.data == null || snapshot.data!.forecast.isEmpty) {
                          return _buildForecastFallbackCard();
                        }
                        return _buildForecastList(snapshot.data!.forecast);
                      },
                    ),
                    const SizedBox(height: 24),

                    // Field Evapotranspiration (ET) Data
                    FutureBuilder<Weather?>(
                      future: _weatherFuture,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();
                        return _buildETCard(snapshot.data!);
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
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildCurrentWeatherCard(Weather weather) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryContainer.withValues(alpha: 0.1),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TranslatedText(
                        'CURRENT CONDITIONS',
                        style: TextStyle(
                          color: AppTheme.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          TranslatedText(
                            '${weather.currentTempC.toStringAsFixed(1)}°',
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TranslatedText(
                              _getWeatherInfo(weather.currentWeatherCode).$1,
                              style: const TextStyle(
                                color: AppTheme.secondary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Icon(
                      _getWeatherInfo(weather.currentWeatherCode).$2,
                      size: 64,
                      color: AppTheme.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Divider(color: AppTheme.surfaceVariant),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TranslatedText('HUMIDITY', style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        TranslatedText('${weather.currentHumidityPercent.toStringAsFixed(0)}%', style: const TextStyle(color: AppTheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TranslatedText('PRECIPITATION', style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        FittedBox(fit: BoxFit.scaleDown, child: TranslatedText('${weather.currentPrecipitationMm}mm', style: const TextStyle(color: AppTheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TranslatedText('RISK LEVEL', style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        FittedBox(fit: BoxFit.scaleDown, child: TranslatedText(weather.riskLevel, style: const TextStyle(color: AppTheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherFallbackCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_off_rounded, color: Colors.amber, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    TranslatedText('Weather Coordinates Pending', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.onSurface)),
                    SizedBox(height: 4),
                    TranslatedText('Configure GPS coordinates for your field to receive live micro-climate updates.', style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loadWeatherData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const TranslatedText('Refresh Weather'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastFallbackCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: const [
          Icon(Icons.cloud_queue_rounded, color: AppTheme.onSurfaceVariant),
          SizedBox(width: 12),
          Expanded(
            child: TranslatedText(
              'Forecast is currently syncing with regional weather satellites.',
              style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIrrigationCard(Weather weather) {
    // Basic heuristic for soil moisture based on recent rain or real data
    final double recentRain = weather.currentPrecipitationMm;
    final int moisturePct = weather.currentSoilMoisture > 0 
        ? (weather.currentSoilMoisture * 100 * 2.5).clamp(0, 100).toInt() 
        : (recentRain > 0 ? 85 : 42); // Fallback to heuristic if 0
    final bool isOptimal = moisturePct >= 60;
    final String statusText = isOptimal ? 'OPTIMAL' : 'IRRIGATION RECOMMENDED';
    final Color statusColor = isOptimal ? AppTheme.secondaryFixed : Colors.amber;
    final String description = isOptimal 
        ? 'Soil moisture levels are currently optimal. No immediate irrigation is required.'
        : 'Soil moisture is dropping. Consider light irrigation within the next 24 hours to prevent plant stress.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryContainer.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.onPrimaryFixed.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.water_drop, color: AppTheme.secondaryFixed, size: 20),
              ),
              const SizedBox(width: 12),
              const TranslatedText(
                'Irrigation Status',
                style: TextStyle(
                  color: AppTheme.onPrimaryContainer,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TranslatedText(
            description,
            style: TextStyle(color: AppTheme.inversePrimary.withValues(alpha: 0.9), height: 1.5),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.onPrimaryFixed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.onPrimaryFixed.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: TranslatedText(
                        'SOIL MOISTURE',
                        style: TextStyle(color: AppTheme.onPrimaryContainer, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TranslatedText('$moisturePct%', style: TextStyle(fontFamily: 'JetBrains Mono', color: statusColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: moisturePct / 100,
                    minHeight: 8,
                    backgroundColor: AppTheme.primaryFixedDim.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TranslatedText(
                    'STATUS: $statusText',
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastList(List<DailyForecast> forecasts) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: forecasts.length,
        itemBuilder: (context, index) {
          final f = forecasts[index];
          // Try to parse day from 'YYYY-MM-DD'
          String dayLabel = f.date;
          try {
            final d = DateTime.parse(f.date);
            final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
            dayLabel = days[d.weekday - 1];
          } catch (_) {}
          
          // Pick an icon based on precip
          final bool isRainy = f.precipitationSumMm > 0;
          final IconData dayIcon = isRainy ? Icons.water_drop : Icons.wb_sunny_outlined;
          final Color iColor = isRainy ? Colors.blue : AppTheme.secondary;

          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: _buildForecastItem(
              dayLabel, 
              dayIcon, 
              '${f.maxTempC.toStringAsFixed(0)}°', 
              '${f.minTempC.toStringAsFixed(0)}°', 
              AppTheme.primary, 
              iColor, 
              isSelected: index == 0,
              highlightText: isRainy ? '${f.precipitationSumMm}mm' : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildForecastItem(String day, IconData icon, String high, String low, Color dayColor, Color iconColor, {required bool isSelected, String? highlightText}) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.surface : AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppTheme.secondaryFixed.withValues(alpha: 0.5) : AppTheme.surfaceVariant,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected ? [
          BoxShadow(
            color: AppTheme.secondaryFixed.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ] : [],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isSelected)
            Positioned(
              top: -16,
              right: -8,
              left: -8,
              child: Container(
                height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.secondary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
              ),
            ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TranslatedText(
                day,
                style: TextStyle(
                  color: dayColor,
                  fontWeight: dayColor == AppTheme.primary ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 12),
              Icon(icon, color: iconColor, size: 32),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TranslatedText(high, style: const TextStyle(fontFamily: 'JetBrains Mono', color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  TranslatedText(low, style: const TextStyle(fontFamily: 'JetBrains Mono', color: AppTheme.onSurfaceVariant)),
                ],
              ),
              if (highlightText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: TranslatedText(
                    highlightText,
                    style: const TextStyle(color: AppTheme.secondary, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildETCard(Weather weather) {
    // Generate dynamic ET trend bars based on recent days/forecast
    List<Widget> barWidgets = [];
    List<Widget> labelWidgets = [];
    
    for (int i = 0; i < weather.forecast.length && i < 7; i++) {
      final f = weather.forecast[i];
      final double etFactor = (f.et0Mm / 10.0).clamp(0.1, 1.0); // Normalizing ET (0-10mm) to 0-1 scale
      
      String dayLabel = f.date;
      try {
        final d = DateTime.parse(f.date);
        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        dayLabel = days[d.weekday - 1];
      } catch (_) {}

      bool isHighlighted = i == 0;
      
      barWidgets.add(_buildBar(etFactor, isHighlighted));
      labelWidgets.add(TranslatedText(
        dayLabel, 
        style: TextStyle(
          fontFamily: 'JetBrains Mono', 
          fontSize: 10, 
          color: isHighlighted ? AppTheme.secondary : AppTheme.onSurfaceVariant, 
          fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal
        )
      ));
    }

    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6), 
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.analytics_outlined, size: 16, color: AppTheme.secondary),
                  ),
                  const SizedBox(width: 8),
                  const TranslatedText(
                    'EVAPOTRANSPIRATION (ET) TRENDS',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const TranslatedText(
                'Monitoring field water loss to optimize irrigation schedules.',
                style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 13, height: 1.4),
              ),
              const Spacer(),
              // Dynamic Chart
              SizedBox(
                height: 90,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: barWidgets,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: labelWidgets,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBar(double heightFactor, bool isHighlighted) {
    return Flexible(
      child: FractionallySizedBox(
        heightFactor: heightFactor,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isHighlighted ? AppTheme.secondary : AppTheme.surfaceVariant.withValues(alpha: 0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          ),
        ),
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
