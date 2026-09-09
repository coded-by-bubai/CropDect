import 'package:flutter/material.dart';
import 'package:cropdect/theme.dart';
import 'login_screen.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;
  
  late AnimationController _floatController;
  late AnimationController _pulseController;

  final List<Map<String, dynamic>> _onboardingData = [
    {
      'type': 'scan_widget',
      'title': 'Scan & Detect',
      'description': 'Instantly identify crop diseases using our advanced AI camera system with state-of-the-art accuracy.',
    },
    {
      'type': 'weather_widget',
      'title': 'Track Microclimates',
      'description': 'Get localized weather insights to predict and prevent disease outbreaks before they happen.',
    },
    {
      'type': 'treatment_widget',
      'title': 'Actionable Advice',
      'description': 'Receive targeted treatment recommendations and connect directly with local agronomists.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  void _onNextPressed() {
    HapticFeedback.lightImpact();
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.fastOutSlowIn,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04160F), // Premium dark green background
      body: Stack(
        children: [
          // Background ambient gradients
          Positioned(
            top: -100,
            left: -100,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF276C00).withValues(alpha: 0.15 + (_pulseController.value * 0.05)),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              }
            ),
          ),
          Positioned(
            bottom: -50,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF81FF45).withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Skip Button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _completeOnboarding();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                      child: Text(
                        'SKIP',
                        style: GoogleFonts.manrope(
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Carousel
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (index) {
                      HapticFeedback.selectionClick();
                      setState(() => _currentPage = index);
                    },
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      return _buildPage(index);
                    },
                  ),
                ),

                // Bottom Glassmorphic Panel
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(32, 32, 32, 48),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        border: Border(
                          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Progress Dots
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(3, (index) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutExpo,
                                margin: const EdgeInsets.symmetric(horizontal: 5.0),
                                height: 6.0,
                                width: _currentPage == index ? 32.0 : 8.0,
                                decoration: BoxDecoration(
                                  color: _currentPage == index
                                      ? const Color(0xFF81FF45)
                                      : Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4.0),
                                  boxShadow: _currentPage == index ? [
                                    const BoxShadow(
                                      color: Color(0xFF81FF45),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    )
                                  ] : null,
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 36),
                          
                          // Action Button
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: double.infinity,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: _currentPage == 2
                                    ? [const Color(0xFF81FF45), const Color(0xFF276C00)]
                                    : [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: _currentPage == 2 ? [
                                BoxShadow(
                                  color: const Color(0xFF81FF45).withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                )
                              ] : [],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _onNextPressed,
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _currentPage == 2 ? 'GET STARTED' : 'CONTINUE',
                                        style: GoogleFonts.manrope(
                                          color: _currentPage == 2 ? const Color(0xFF04160F) : Colors.white,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.2,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        _currentPage == 2 ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                                        color: _currentPage == 2 ? const Color(0xFF04160F) : Colors.white,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    final data = _onboardingData[index];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Graphic Area
          SizedBox(
            height: 300,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _floatController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 10 * _floatController.value),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glowing Center Blob
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF81FF45).withValues(alpha: 0.1),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF81FF45).withValues(alpha: 0.2),
                              blurRadius: 60,
                              spreadRadius: 20,
                            )
                          ],
                        ),
                      ),
                      // Foreground content based on type
                      if (data['type'] == 'scan_widget')
                        _buildScanGraphic()
                      else if (data['type'] == 'weather_widget')
                        _buildWeatherGraphic()
                      else if (data['type'] == 'treatment_widget')
                        _buildTreatmentGraphic(),
                    ],
                  ),
                );
              }
            ),
          ),
          const SizedBox(height: 56),
          // Text Content
          Text(
            data['title'],
            style: GoogleFonts.manrope(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            data['description'],
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.white70,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40), // Pad for bottom controls
        ],
      ),
    );
  }

  Widget _buildScanGraphic() {
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glass Scanner Box
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 30, offset: const Offset(0, 15))
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.eco_rounded, size: 80, color: Color(0xFF81FF45)),
                ),
              ),
            ),
          ),
          // Scanner Corners
          _buildScannerCorner(Alignment.topLeft),
          _buildScannerCorner(Alignment.topRight),
          _buildScannerCorner(Alignment.bottomLeft),
          _buildScannerCorner(Alignment.bottomRight),
          // Floating Camera Icon
          Positioned(
            bottom: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF81FF45),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: const Color(0xFF81FF45).withValues(alpha: 0.4), blurRadius: 15, spreadRadius: 2)
                ],
              ),
              child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF04160F), size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          border: Border(
            top: (alignment == Alignment.topLeft || alignment == Alignment.topRight) ? const BorderSide(color: Color(0xFF81FF45), width: 4) : BorderSide.none,
            bottom: (alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight) ? const BorderSide(color: Color(0xFF81FF45), width: 4) : BorderSide.none,
            left: (alignment == Alignment.topLeft || alignment == Alignment.bottomLeft) ? const BorderSide(color: Color(0xFF81FF45), width: 4) : BorderSide.none,
            right: (alignment == Alignment.topRight || alignment == Alignment.bottomRight) ? const BorderSide(color: Color(0xFF81FF45), width: 4) : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherGraphic() {
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        children: [
          _buildGlassCard(
            top: 20, left: 10, angle: -0.05,
            icon: Icons.wb_sunny_rounded, iconColor: Colors.amber, text: '24°C',
          ),
          _buildGlassCard(
            top: 50, right: 10, angle: 0.08,
            icon: Icons.water_drop_rounded, iconColor: Colors.lightBlueAccent, text: '65%',
          ),
          _buildGlassCard(
            bottom: 30, left: 60, angle: -0.03,
            icon: Icons.air_rounded, iconColor: Colors.white70, text: '12 km/h',
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({
    double? top, double? bottom, double? left, double? right, 
    required double angle, required IconData icon, required Color iconColor, required String text
  }) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: Transform.rotate(
        angle: angle,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10))
                ],
              ),
              child: Column(
                children: [
                  Icon(icon, color: iconColor, size: 36),
                  const SizedBox(height: 12),
                  Text(text, style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTreatmentGraphic() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 30, offset: const Offset(0, 15))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCheckRow(true, 1.0),
              const SizedBox(height: 20),
              _buildCheckRow(true, 0.75),
              const SizedBox(height: 20),
              _buildCheckRow(false, 0.5),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckRow(bool isChecked, double widthFactor) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isChecked ? const Color(0xFF81FF45) : Colors.transparent,
            shape: BoxShape.circle,
            border: isChecked ? null : Border.all(color: Colors.white30, width: 2),
            boxShadow: isChecked ? [
              BoxShadow(color: const Color(0xFF81FF45).withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))
            ] : null,
          ),
          child: isChecked
              ? const Icon(Icons.check_rounded, size: 18, color: Color(0xFF04160F))
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: widthFactor,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: isChecked ? Colors.white : Colors.white30,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
