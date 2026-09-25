import 'package:flutter/material.dart';
import 'package:cropdect/theme.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'dashboard_screen.dart';
import 'crop_library_screen.dart';
import 'weather_irrigation_screen.dart';
import 'ai_scan_camera_screen.dart';
import 'profile_screen.dart';
import 'consult_expert_screen.dart';
import 'chat_screen.dart';
import '../api_client.dart';
import 'dart:io';
import 'monitoring_history_screen.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:translator/translator.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import '../main.dart';
import '../widgets/translated_text.dart';

class DetectionResultScreen extends StatefulWidget {
  final Map<String, dynamic>? resultData;
  final File? imageFile;
  final Uint8List? imageBytes;
  final bool isExpertMode;

  const DetectionResultScreen({super.key, this.resultData, this.imageFile, this.imageBytes, this.isExpertMode = false});

  @override
  State<DetectionResultScreen> createState() => _DetectionResultScreenState();
}

class _DetectionResultScreenState extends State<DetectionResultScreen> with TickerProviderStateMixin {
  late LanguageState _localLangState;
  late AnimationController _pulseController;
  late AnimationController _entranceController;
  
  final int _selectedIndex = 2; // Scan index
  bool _showOverlay = true;
  Map<String, dynamic>? _ipmPlan;
  bool _ipmLoading = false;
  
  // Animation variables
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Language & TTS variables
  final FlutterTts _flutterTts = FlutterTts();
  final GoogleTranslator _translator = GoogleTranslator();

  String _selectedLanguage = 'en';
  bool _isTranslating = false;
  bool _isPlayingTts = false;

  String? _translatedDiseaseName;
  String? _translatedSeverityLabel;
  String? _translatedActionPreview;
  Map<String, dynamic>? _translatedIpmPlan;

  String? _translatedIpmHeader;
  String? _translatedWarningLabel;
  String? _translatedSectionLabel;
  String? _translatedImmediateActionsTitle;
  String? _translatedCulturalPracticesTitle;
  String? _translatedBiologicalControlsTitle;
  String? _translatedChemicalControlsTitle;
  
  String? _translatedListenButton;
  String? _translatedStopButton;
  String? _translatedTranslatingLabel;

  final List<Map<String, String>> _supportedLanguages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'hi', 'name': 'हिंदी (Hindi)'},
    {'code': 'bn', 'name': 'বাংলা (Bengali)'},
    {'code': 'mr', 'name': 'मराठी (Marathi)'},
  ];

  @override
  void initState() {
    super.initState();
    
    // Initialize local language state for this screen ONLY, based on global setting
    _localLangState = LanguageState('en'); // Will be updated in post frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final globalLang = context.read<LanguageState>().currentLanguage;
        _localLangState = LanguageState(globalLang);
        setState(() {
          _selectedLanguage = globalLang;
        });
        _fetchIPMPlan(); // Re-fetch or translate based on new language
      }
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.2, 1.0, curve: Curves.easeOut)),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic)),
    );

    _entranceController.forward();
    _initTts();
  }

  void _initTts() {
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isPlayingTts = false);
    });
    _flutterTts.setErrorHandler((msg) {
      if (mounted) setState(() => _isPlayingTts = false);
    });
  }

  Future<void> _fetchIPMPlan() async {
    final diagnosisId = widget.resultData?['id'];
    if (diagnosisId == null) return;
    setState(() => _ipmLoading = true);
    try {
      final response = await apiClient.get('/diagnostics/$diagnosisId/ipm-plan');
      if (response.statusCode == 200) {
        setState(() => _ipmPlan = response.data as Map<String, dynamic>);
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _ipmLoading = false);
      if (_selectedLanguage != 'en') {
        _translateContent();
      }
    }
  }

  Future<void> _translateContent() async {
    if (_selectedLanguage == 'en') {
      setState(() {
        _translatedDiseaseName = null;
        _translatedSeverityLabel = null;
        _translatedActionPreview = null;
        _translatedIpmPlan = null;
        _translatedWarningLabel = null;
        _translatedSectionLabel = null;
        _translatedIpmHeader = null;
        _translatedImmediateActionsTitle = null;
        _translatedCulturalPracticesTitle = null;
        _translatedBiologicalControlsTitle = null;
        _translatedChemicalControlsTitle = null;
        _translatedListenButton = null;
        _translatedStopButton = null;
        _translatedTranslatingLabel = null;
      });
      return;
    }

    setState(() => _isTranslating = true);

    String replaceDigits(String input, String langCode) {
      if (langCode == 'en') return input;
      const hindiDigits = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];
      const bengaliDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
      const teluguDigits = ['౦', '౧', '౨', '౩', '౪', '౫', '౬', '౭', '౮', '౯'];
      
      List<String>? targetDigits;
      if (langCode == 'hi' || langCode == 'mr') targetDigits = hindiDigits;
      else if (langCode == 'bn') targetDigits = bengaliDigits;
      else if (langCode == 'te') targetDigits = teluguDigits;
      
      if (targetDigits == null) return input;
      
      String output = input;
      for (int i = 0; i < 10; i++) output = output.replaceAll(i.toString(), targetDigits[i]);
      return output;
    }

    try {
      final severity = widget.resultData?['severity'] ?? 'MODERATE';
      final isHealthy = (widget.resultData?['diagnosis_type'] ?? '') == 'HEALTHY';
      final label = widget.resultData?['label'] ?? widget.resultData?['diagnosis_type'] ?? 'Unknown Condition';

      final severityLabel = isHealthy ? 'ALL CLEAR' : 'DETECTED ${severity.toUpperCase()}';
      final actionPreview = isHealthy
          ? 'No disease or pest detected. Your crop appears healthy.'
          : 'Immediate attention required. Scroll down to view the full Integrated Pest Management (IPM) plan.';

      final tLabel = await _translator.translate(label, to: _selectedLanguage);
      final tSeverity = await _translator.translate(severityLabel, to: _selectedLanguage);
      final tAction = await _translator.translate(actionPreview, to: _selectedLanguage);
      
      final tHeader = await _translator.translate('TREATMENT & MANAGEMENT (IPM)', to: _selectedLanguage);
      final tImmediate = await _translator.translate('Immediate Actions', to: _selectedLanguage);
      final tCultural = await _translator.translate('Cultural Practices', to: _selectedLanguage);
      final tBiological = await _translator.translate('Biological Controls', to: _selectedLanguage);
      final tChemical = await _translator.translate('Chemical Controls', to: _selectedLanguage);
      
      final tListen = await _translator.translate('Listen', to: _selectedLanguage);
      final tStop = await _translator.translate('Stop', to: _selectedLanguage);
      final tTranslating = await _translator.translate('Translating...', to: _selectedLanguage);
      final tWarning = await _translator.translate('Warning', to: _selectedLanguage);
      final tSection = await _translator.translate('Section', to: _selectedLanguage);

      Map<String, dynamic>? tIpmPlan;
      if (_ipmPlan != null) {
        tIpmPlan = {};
        for (var entry in _ipmPlan!.entries) {
          if (entry.value is List) {
            List<String> tList = [];
            for (var item in (entry.value as List)) {
              final tItem = await _translator.translate(item.toString(), to: _selectedLanguage);
              tList.add(replaceDigits(tItem.text, _selectedLanguage));
            }
            tIpmPlan[entry.key] = tList;
          } else if (entry.value is String) {
            final tString = await _translator.translate(entry.value.toString(), to: _selectedLanguage);
            tIpmPlan[entry.key] = replaceDigits(tString.text, _selectedLanguage);
          } else {
             tIpmPlan[entry.key] = entry.value;
          }
        }
      }

      if (mounted) {
        setState(() {
          _translatedDiseaseName = replaceDigits(tLabel.text, _selectedLanguage);
          _translatedSeverityLabel = replaceDigits(tSeverity.text, _selectedLanguage);
          _translatedActionPreview = replaceDigits(tAction.text, _selectedLanguage);
          _translatedIpmPlan = tIpmPlan; // The items are translated below
          _translatedIpmHeader = replaceDigits(tHeader.text, _selectedLanguage);
          _translatedImmediateActionsTitle = replaceDigits(tImmediate.text, _selectedLanguage);
          _translatedCulturalPracticesTitle = replaceDigits(tCultural.text, _selectedLanguage);
          _translatedBiologicalControlsTitle = replaceDigits(tBiological.text, _selectedLanguage);
          _translatedChemicalControlsTitle = replaceDigits(tChemical.text, _selectedLanguage);
          _translatedListenButton = replaceDigits(tListen.text, _selectedLanguage);
          _translatedStopButton = replaceDigits(tStop.text, _selectedLanguage);
          _translatedTranslatingLabel = replaceDigits(tTranslating.text, _selectedLanguage);
          _translatedWarningLabel = replaceDigits(tWarning.text, _selectedLanguage);
          _translatedSectionLabel = replaceDigits(tSection.text, _selectedLanguage);
        });
      }
    } catch (_) {} 
    finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  Future<void> _speakResults() async {
    if (_isPlayingTts) {
      await _flutterTts.stop();
      if (mounted) setState(() => _isPlayingTts = false);
      return;
    }

    setState(() => _isPlayingTts = true);
    await _flutterTts.setLanguage(_selectedLanguage);
    
    final label = _translatedDiseaseName ?? widget.resultData?['label'] ?? widget.resultData?['diagnosis_type'] ?? 'Unknown Condition';
    final severity = _translatedSeverityLabel ?? ((widget.resultData?['diagnosis_type'] ?? '') == 'HEALTHY' ? 'All Clear' : 'Detected');

    String speechText = "$label. $severity.";

    if ((_translatedIpmPlan ?? _ipmPlan) != null) {
      final planToRead = _translatedIpmPlan ?? _ipmPlan!;
      
      if (planToRead.containsKey('severity_warning') && planToRead['severity_warning'].toString().isNotEmpty) {
        final warnLbl = _translatedWarningLabel ?? 'Warning';
        speechText += " $warnLbl: ${planToRead['severity_warning']}.";
      }

      for (var entry in planToRead.entries) {
        if (entry.key == 'severity_warning') continue;
        
        if (entry.value is List && (entry.value as List).isNotEmpty) {
          final secLbl = _translatedSectionLabel ?? 'Section';
          
          String title = entry.key;
          if (entry.key == 'immediate_actions') title = _translatedImmediateActionsTitle ?? 'Immediate Actions';
          else if (entry.key == 'cultural_practices') title = _translatedCulturalPracticesTitle ?? 'Cultural Practices';
          else if (entry.key == 'biological_controls') title = _translatedBiologicalControlsTitle ?? 'Biological Controls';
          else if (entry.key == 'chemical_controls') title = _translatedChemicalControlsTitle ?? 'Chemical Controls';
          else {
            title = entry.key.split('_').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
          }

          speechText += " $secLbl $title. ${(entry.value as List).join('. ')}.";
        }
      }
    }

    await _flutterTts.speak(speechText);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _pulseController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex && index != 2) return;
    
    Widget targetScreen;
    switch (index) {
      case 0: targetScreen = const DashboardScreen(); break;
      case 1: targetScreen = const CropLibraryScreen(); break;
      case 2: targetScreen = const AIScanCameraScreen(); break;
      case 3: targetScreen = const WeatherIrrigationScreen(); break;
      case 4: targetScreen = const ProfileScreen(); break;
      default: return;
    }
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => targetScreen,
        transitionDuration: Duration.zero,
      ),
    );
  }

  Future<void> _requestExpertReviewAndNavigate() async {
    final diagnosisId = widget.resultData?['id'];
    if (diagnosisId != null) {
      try {
        await apiClient.post('/diagnostics/$diagnosisId/request-review');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: TranslatedText('Scan submitted for Expert Agronomist verification!')),
          );
        }
      } catch (_) {}
    }
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ConsultExpertScreen()),
      );
    }
  }


  List<Color> _getSeverityGradient(String? severity) {
    switch ((severity ?? 'MODERATE').toUpperCase()) {
      case 'LOW': return [const Color(0xFF2E7D32), const Color(0xFF1B5E20)];
      case 'HIGH': return [Colors.deepOrange, Colors.orange.shade900];
      case 'CRITICAL': return [const Color(0xFFD32F2F), const Color(0xFF880E4F)]; // Vibrant red to deep crimson
      default: return [Colors.amber.shade700, Colors.orange.shade800];
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LanguageState>.value(
      value: _localLangState,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 800;
          return isDesktop ? _buildDesktopLayout(context) : _buildMobileLayout(context);
        },
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final severity = widget.resultData?['severity'] ?? 'MODERATE';
    final isHealthy = (widget.resultData?['diagnosis_type'] ?? '') == 'HEALTHY';
    final gradient = isHealthy ? [const Color(0xFF1B5E20), const Color(0xFF388E3C)] : _getSeverityGradient(severity);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          // ── LEFT PANEL: Hero Image ──────────────────────────────────────
          Expanded(
            flex: 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Full-height image
                widget.imageBytes != null 
                    ? Image.memory(widget.imageBytes!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade900,
                          child: const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 48))))
                    : widget.imageFile != null
                        ? Image.file(widget.imageFile!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade900,
                              child: const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 48))))
                        : Image.network(
                            widget.resultData?['image_url'] ?? 'https://via.placeholder.com/800',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade900,
                              child: const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 48)))),
                // Dark gradient
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withValues(alpha: 0.3), Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                    ),
                  ),
                ),
                // Back button top-left
                Positioned(
                  top: 24,
                  left: 24,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                // Crop name + confidence overlay at bottom
                Positioned(
                  bottom: 32,
                  left: 32,
                  right: 32,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TranslatedText('ANALYZED CROP',
                                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white60, letterSpacing: 1.5)),
                                const SizedBox(height: 4),
                                TranslatedText(widget.resultData?['crop_name'] ?? 'Unknown Crop',
                                    style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
                              ),
                              child: Column(
                                children: [
                                  TranslatedText('AI CONFIDENCE',
                                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1.0)),
                                  const SizedBox(height: 2),
                                  TranslatedText(
                                    widget.resultData != null ? '${((widget.resultData!['confidence'] ?? 0.984) * 100).toStringAsFixed(1)}%' : '98.4%',
                                    style: GoogleFonts.robotoMono(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.greenAccent),
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
              ],
            ),
          ),

          // ── RIGHT PANEL: Details ────────────────────────────────────────
          Expanded(
            flex: 6,
            child: Column(
              children: [
                // Action Panel Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TranslatedText('Detection Results',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.onSurface)),
                      const SizedBox(height: 16),
                      // Action buttons in a row
                      if (!widget.isExpertMode)
                        Row(
                          children: [
                            _buildDesktopActionButton(
                              icon: Icons.chat_bubble_rounded,
                              label: 'Ask AI',
                              onTap: () {
                                final diseaseName = widget.resultData?['label'] ?? 'crop disease';
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => ChatScreen(initialQuery: 'I need expert agronomic advice for treating $diseaseName.'),
                                ));
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildDesktopActionButton(
                              icon: Icons.history_rounded,
                              label: 'Monitor',
                              onTap: () {
                                if (widget.resultData != null && widget.resultData!['id'] != null) {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => MonitoringHistoryScreen(diagnosisId: widget.resultData!['id']),
                                  ));
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: TranslatedText('Please save the diagnosis first before monitoring.')),
                                  );
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _requestExpertReviewAndNavigate,
                              icon: const Icon(Icons.support_agent_rounded, size: 16),
                              label: TranslatedText('Consult Expert', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // Scrollable detail content
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Diagnosis badge card
                            _buildDesktopDiagnosisCard(gradient, isHealthy, severity),
                            const SizedBox(height: 32),
                            _buildIPMSection(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom nav
                _buildBottomNavBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: AppTheme.primary),
      label: TranslatedText(label, style: GoogleFonts.inter(color: AppTheme.primary, fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildDesktopDiagnosisCard(List<Color> gradient, bool isHealthy, String severity) {
    final label = widget.resultData?['label'] ?? widget.resultData?['diagnosis_type'] ?? 'Unknown Condition';
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: gradient.last.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Stack(
        children: [
          Positioned(right: -20, top: -20,
              child: Icon(isHealthy ? Icons.eco_rounded : Icons.coronavirus_rounded,
                  size: 160, color: Colors.white.withValues(alpha: 0.1))),
          Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                      child: TranslatedText(
                        _translatedSeverityLabel ?? (isHealthy ? 'ALL CLEAR' : 'DETECTED ${severity.toUpperCase()}'),
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.5)),
                    ),
                    const Icon(Icons.health_and_safety, color: Colors.white, size: 28),
                  ],
                ),
                const SizedBox(height: 16),
                TranslatedText(_translatedDiseaseName ?? label,
                    style: GoogleFonts.manrope(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
                const SizedBox(height: 8),
                if (isHealthy)
                  TranslatedText(_translatedActionPreview ?? 'No disease or pest detected. Your crop appears healthy.',
                      style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withValues(alpha: 0.9))),
                const SizedBox(height: 24),
                // Language & TTS row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedLanguage,
                            dropdownColor: AppTheme.surface,
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            isExpanded: true,
                            items: _supportedLanguages.map((lang) => DropdownMenuItem<String>(
                              value: lang['code'],
                              child: TranslatedText(lang['name']!, style: GoogleFonts.inter(
                                  color: _selectedLanguage == lang['code'] ? Colors.white : AppTheme.onSurface),
                                  overflow: TextOverflow.ellipsis),
                            )).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedLanguage = val);
                                _localLangState.changeLanguage(val); // This won't affect global because it's local instance!
                                _translateContent();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isTranslating ? null : _speakResults,
                        icon: _isTranslating
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Icon(_isPlayingTts ? Icons.stop_rounded : Icons.volume_up_rounded, size: 18),
                        label: TranslatedText(
                          _isTranslating ? (_translatedTranslatingLabel ?? 'Translating...')
                              : (_isPlayingTts ? (_translatedStopButton ?? 'Stop') : (_translatedListenButton ?? 'Listen')),
                          style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          foregroundColor: Colors.white, elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
        backgroundColor: AppTheme.background,
        extendBody: true,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 120.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPremiumDiagnosisCard(),
                        const SizedBox(height: 32),
                        _buildIPMSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNavBar(),
    );
  }


  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 380,
      backgroundColor: AppTheme.surface.withValues(alpha: 0.8),
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        if (!widget.isExpertMode) ...[
          Container(
            margin: const EdgeInsets.only(right: 4, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton.icon(
              onPressed: () {
                final diseaseName = widget.resultData?['label'] ?? 'crop disease';
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    initialQuery: 'I need expert agronomic advice for treating $diseaseName. What are the best immediate treatments, chemical dosage rates, and cultural practices to prevent it from spreading?',
                  ),
                ));
              },
              icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
              label: const TranslatedText('Ask AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
            ),
          ),
          if (widget.resultData != null && widget.resultData!['id'] != null)
            Container(
              margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => MonitoringHistoryScreen(diagnosisId: widget.resultData!['id']),
                  ));
                },
                icon: const Icon(Icons.history_rounded, color: Colors.white, size: 18),
                label: const TranslatedText('Monitor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
              ),
            ),
        ],
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Base Image
            widget.imageBytes != null 
                ? Image.memory(
                    widget.imageBytes!,
                    fit: BoxFit.cover,
                  )
                : widget.imageFile != null
                    ? Image.file(
                        widget.imageFile!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade900,
                          child: const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 40)),
                        ),
                      )
                    : Image.network(
                    widget.resultData?['image_url'] ?? 'https://via.placeholder.com/400',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey.shade900,
                      child: const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 40)),
                    ),
                  ),
            
            // Subtle Dark Gradient Overlay for text readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
            
            // Removed fake bounding box overlay as our ML model is a classifier, not an object detector.

            // Glassmorphism Floating Info Card at bottom of Hero
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TranslatedText(
                              'ANALYZED CROP',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1.5),
                            ),
                            const SizedBox(height: 4),
                            TranslatedText(
                              widget.resultData?['crop_name'] ?? 'Wheat Field',
                              style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              TranslatedText(
                                'AI CONFIDENCE',
                                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 1.0),
                              ),
                              const SizedBox(height: 2),
                              TranslatedText(
                                widget.resultData != null ? '${((widget.resultData!['confidence'] ?? 0.984) * 100).toStringAsFixed(1)}%' : '98.4%',
                                style: GoogleFonts.robotoMono(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.greenAccent),
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
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumDiagnosisCard() {
    final severity = widget.resultData?['severity'] ?? 'MODERATE';
    final isHealthy = (widget.resultData?['diagnosis_type'] ?? '') == 'HEALTHY';
    final gradient = isHealthy ? [const Color(0xFF1B5E20), const Color(0xFF388E3C)] : _getSeverityGradient(severity);
    final iconData = isHealthy ? Icons.eco_rounded : Icons.coronavirus_rounded;
    final label = widget.resultData?['label'] ?? widget.resultData?['diagnosis_type'] ?? 'Unknown Condition';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background subtle pattern
          Positioned(
            right: -20,
            top: -20,
            child: Icon(iconData, size: 140, color: Colors.white.withValues(alpha: 0.1)),
          ),
          Padding(
            padding: const EdgeInsets.all(28.0),
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
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TranslatedText(
                        _translatedSeverityLabel ?? (isHealthy ? 'ALL CLEAR' : 'DETECTED ${severity.toUpperCase()}'),
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.5),
                      ),
                    ),
                    const Icon(Icons.health_and_safety, color: Colors.white, size: 24),
                  ],
                ),
                const SizedBox(height: 16),
                TranslatedText(
                  _translatedDiseaseName ?? label,
                  style: GoogleFonts.manrope(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1),
                ),
                const SizedBox(height: 24),
                

                if (isHealthy)
                  TranslatedText(
                    _translatedActionPreview ?? 'No disease or pest detected. Your crop appears healthy.',
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withValues(alpha: 0.9)),
                  ),

                const SizedBox(height: 24),
                // Language & TTS Controls
                if (!widget.isExpertMode)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedLanguage,
                              dropdownColor: AppTheme.surface,
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              isExpanded: true,
                              items: _supportedLanguages.map((lang) {
                                return DropdownMenuItem<String>(
                                  value: lang['code'],
                                  child: TranslatedText(
                                    lang['name']!,
                                    style: GoogleFonts.inter(
                                      color: _selectedLanguage == lang['code'] ? Colors.white : AppTheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedLanguage = val);
                                  _localLangState.changeLanguage(val);
                                  _translateContent();
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isTranslating ? null : _speakResults,
                          icon: _isTranslating
                              ? const SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Icon(_isPlayingTts ? Icons.stop_rounded : Icons.volume_up_rounded, size: 18),
                          label: TranslatedText(
                            _isTranslating 
                              ? (_translatedTranslatingLabel ?? 'Translating...') 
                              : (_isPlayingTts ? (_translatedStopButton ?? 'Stop') : (_translatedListenButton ?? 'Listen')),
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildIPMSection() {
    final isHealthy = (widget.resultData?['diagnosis_type'] ?? '') == 'HEALTHY';
    if (isHealthy && _ipmPlan == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TranslatedText(
          _translatedIpmHeader ?? 'TREATMENT & MANAGEMENT (IPM)',
          style: GoogleFonts.inter(color: AppTheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2),
        ),
        const SizedBox(height: 16),
        
        if (_ipmLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  const CircularProgressIndicator(color: AppTheme.primary),
                  const SizedBox(height: 16),
                  TranslatedText('Generating personalized treatment...', style: GoogleFonts.inter(color: AppTheme.onSurfaceVariant, fontSize: 13)),
                ],
              ),
            ),
          )
        else if (_ipmPlan == null)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppTheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              const Icon(Icons.info_outline, color: AppTheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(child: TranslatedText('Treatment plan unavailable for this scan.', style: GoogleFonts.inter(color: AppTheme.onSurfaceVariant))),
            ]),
          )
        else ...(() {
          final planToUse = _translatedIpmPlan ?? _ipmPlan!;
          return [
            // Severity warning banner
            if ((planToUse['severity_warning'] ?? '').isNotEmpty)
              _buildIPMBanner(planToUse['severity_warning']),
              
            const SizedBox(height: 16),
            
            _buildAccordionItem(
              icon: Icons.flash_on_rounded, 
              title: _translatedImmediateActionsTitle ?? 'Immediate Actions', 
              color: AppTheme.error, 
              items: (planToUse['immediate_actions'] as List?)?.cast<String>() ?? [],
              initiallyExpanded: true,
            ),
            const SizedBox(height: 12),
            _buildAccordionItem(
              icon: Icons.grass_rounded, 
              title: _translatedCulturalPracticesTitle ?? 'Cultural Practices', 
              color: AppTheme.secondary, 
              items: (planToUse['cultural_practices'] as List?)?.cast<String>() ?? [],
            ),
            if ((planToUse['biological_controls'] as List?)?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              _buildAccordionItem(
                icon: Icons.eco_rounded, 
                title: _translatedBiologicalControlsTitle ?? 'Biological Controls', 
                color: const Color(0xFF2E7D32), 
                items: (planToUse['biological_controls'] as List).cast<String>(),
              ),
            ],
            if ((planToUse['chemical_controls'] as List?)?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              _buildAccordionItem(
                icon: Icons.science_rounded, 
                title: _translatedChemicalControlsTitle ?? 'Chemical Controls', 
                color: Colors.orange.shade800, 
                items: (planToUse['chemical_controls'] as List).cast<String>(),
              ),
            ],
          ];
        }()),
      ],
    );
  }

  Widget _buildAccordionItem({required IconData icon, required String title, required Color color, required List<String> items, bool initiallyExpanded = true}) {
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2)),
        ],
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          iconColor: color,
          collapsedIconColor: color.withValues(alpha: 0.7),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          childrenPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              TranslatedText(title, style: GoogleFonts.manrope(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          children: items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6, right: 12),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.6), shape: BoxShape.circle),
                ),
                Expanded(
                  child: TranslatedText(
                    item, 
                    style: GoogleFonts.inter(color: AppTheme.onSurface, fontSize: 14, height: 1.5, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildIPMBanner(String text) {
    final isAlert = text.toLowerCase().contains('critical') || text.toLowerCase().contains('high');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAlert ? AppTheme.errorContainer : AppTheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isAlert ? AppTheme.error.withValues(alpha: 0.3) : AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isAlert ? Icons.warning_amber_rounded : Icons.check_circle_outline, color: isAlert ? AppTheme.error : AppTheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: TranslatedText(text, style: GoogleFonts.inter(color: isAlert ? AppTheme.onErrorContainer : AppTheme.onPrimaryContainer, fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildFloatingActionPanel() {
    if (widget.isExpertMode) return const SizedBox.shrink();
    return Positioned(
      bottom: 90, // Above the bottom nav bar
      left: 16,
      right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      final diseaseName = widget.resultData?['label'] ?? 'crop disease';
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            initialQuery: 'I need expert agronomic advice for treating $diseaseName. What are the best immediate treatments, chemical dosage rates, and cultural practices to prevent it from spreading?',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_rounded, color: AppTheme.primary, size: 16),
                    label: TranslatedText('Ask AI', style: GoogleFonts.inter(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      if (widget.resultData != null && widget.resultData!['id'] != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MonitoringHistoryScreen(diagnosisId: widget.resultData!['id']),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: TranslatedText('Please save the diagnosis first before monitoring.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.history_rounded, color: AppTheme.primary, size: 16),
                    label: TranslatedText('Monitor', style: GoogleFonts.inter(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _requestExpertReviewAndNavigate,
                    icon: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 16),
                    label: TranslatedText('Consult Expert', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primary,
                      elevation: 4,
                      shadowColor: AppTheme.primary.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
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
