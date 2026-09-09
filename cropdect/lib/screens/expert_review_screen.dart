import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../api_client.dart';
import 'monitoring_history_screen.dart';
import 'detection_result_screen.dart';

class ExpertReviewScreen extends StatefulWidget {
  final bool showBackButton;
  const ExpertReviewScreen({super.key, this.showBackButton = true});

  @override
  State<ExpertReviewScreen> createState() => _ExpertReviewScreenState();
}

class _ExpertReviewScreenState extends State<ExpertReviewScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _pendingReviews = [];
  List<dynamic> _labReferrals = [];
  List<dynamic> _followUpCases = [];
  List<dynamic> _completedCases = [];
  List<dynamic> _kbItems = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    List<dynamic> pending = [];
    List<dynamic> labs = [];
    List<dynamic> kb = [];
    List<dynamic> followUps = [];

    try {
      final res = await apiClient.get('/experts/pending-reviews');
      if (res.data is List) pending = res.data;
    } catch (_) {}

    try {
      final res = await apiClient.get('/labs/referrals');
      if (res.data is List) labs = res.data;
    } catch (_) {}
    
    try {
      final res = await apiClient.get('/experts/follow-ups');
      if (res.data is List) followUps = res.data;
    } catch (_) {}

    List<dynamic> completed = [];
    try {
      final res = await apiClient.get('/experts/completed-cases');
      if (res.data is List) completed = res.data;
    } catch (_) {}

    try {
      final res = await apiClient.get('/knowledge-base/');
      if (res.data is List) kb = res.data;
    } catch (_) {}

    if (mounted) {
      setState(() {
        _pendingReviews = pending;
        _labReferrals = labs;
        _followUpCases = followUps;
        _completedCases = completed;
        _kbItems = kb;
        _isLoading = false;
      });
    }
  }

  Color _severityColor(String? severity) {
    switch (severity?.toUpperCase()) {
      case 'LOW':
        return const Color(0xFF276C00);
      case 'HIGH':
        return Colors.orange.shade800;
      case 'CRITICAL':
        return AppTheme.error;
      default:
        return Colors.amber.shade800;
    }
  }

  // ── CONFIRM VALIDATION MODAL ───────────────────────────────────────────────
  void _showValidationModal(Map<String, dynamic> item) {
    final notesCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final imageUrl = item['image_url'] ?? '';
          String diagType = item['diagnosis_type'] ?? 'DISEASE';
          if (diagType == 'UNKNOWN') diagType = 'DISEASE';
          final kbName = item['disease_name'] ?? item['pest_name'] ?? item['model_version'] ?? diagType;
          final confidence = ((item['confidence'] ?? 0.0) * 100).toStringAsFixed(1);
          final severity = item['severity'] ?? 'MODERATE';

          return Container(
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.rate_review_rounded, color: AppTheme.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Expert Validation Review',
                        style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Image Preview
                  if (imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 180,
                        width: double.infinity,
                        color: AppTheme.surfaceContainerHigh,
                        child: Image.network(
                          imageUrl.startsWith('http') ? imageUrl : 'http://10.0.2.2:8000$imageUrl',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_rounded, size: 40, color: AppTheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // AI Diagnosis Summary Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'AI Prediction',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.onSurfaceVariant),
                            ),
                            Row(
                              children: [
                                Tooltip(
                                  message: 'View Full AI Detection Result',
                                  child: Material(
                                    color: AppTheme.primary.withValues(alpha: 0.1),
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => DetectionResultScreen(resultData: item, isExpertMode: true),
                                          ),
                                        );
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(6.0),
                                        child: Icon(Icons.visibility_rounded, color: AppTheme.primary, size: 16),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _severityColor(severity).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    severity.toUpperCase(),
                                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: _severityColor(severity)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          kbName,
                          style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.onSurface),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Confidence: $confidence% · Flagged for expert verification',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.orange.shade800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Expert Notes field
                  Text(
                    'Expert Agronomist Notes',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onSurface),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Enter observation, verified IPM recommendations, or guidance...',
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
                      filled: true,
                      fillColor: AppTheme.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  if (isSubmitting)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    // Primary Action: Confirm AI Diagnosis
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          setModalState(() => isSubmitting = true);
                          try {
                            await apiClient.post('/experts/validations', data: {
                              'diagnosis_id': item['id'],
                              'is_correct': true,
                              'expert_notes': notesCtrl.text.trim().isEmpty ? 'Confirmed by expert agronomist.' : notesCtrl.text.trim(),
                            });
                            if (context.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Diagnosis successfully confirmed!')),
                              );
                              _loadAllData();
                            }
                          } catch (e) {
                            setModalState(() => isSubmitting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error validating: $e')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20),
                        label: Text(
                          'Confirm AI Diagnosis',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.primary),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondaryContainer,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Secondary Row: Correct Diagnosis OR Refer to Lab
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showCorrectionModal(item);
                            },
                            icon: const Icon(Icons.edit_note_rounded, size: 18, color: AppTheme.primary),
                            label: Text(
                              'Correct',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.primary, fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.primary),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showLabReferralModal(item);
                            },
                            icon: const Icon(Icons.biotech_rounded, size: 18, color: Colors.purple),
                            label: Text(
                              'Refer to Lab',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.purple, fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.purple),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── CORRECT DIAGNOSIS MODAL ────────────────────────────────────────────────
  void _showCorrectionModal(Map<String, dynamic> item) {
    int? selectedKbId;
    String? selectedKbName;
    final notesCtrl = TextEditingController();
    final searchCtrl = TextEditingController();
    final customConditionCtrl = TextEditingController();
    bool isSubmitting = false;
    bool useCustomCondition = false;
    List<dynamic> filteredKb = List.from(_kbItems);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          void filterKb(String query) {
            setModalState(() {
              filteredKb = _kbItems
                  .where((kb) => (kb['name'] ?? '').toString().toLowerCase().contains(query.toLowerCase()))
                  .toList();
            });
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (_, scrollController) => Container(
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: ListView(
                  controller: scrollController,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: AppTheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Correct Crop Diagnosis',
                      style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AI diagnosed: ${item['label'] ?? item['diagnosis_type'] ?? 'Unknown'}',
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),

                    // Toggle: KB vs Custom
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() { useCustomCondition = false; customConditionCtrl.clear(); }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !useCustomCondition ? AppTheme.primary.withValues(alpha: 0.12) : AppTheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: !useCustomCondition ? AppTheme.primary : AppTheme.outlineVariant.withValues(alpha: 0.5),
                                  width: !useCustomCondition ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                'From Knowledge Base',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: !useCustomCondition ? AppTheme.primary : AppTheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() { useCustomCondition = true; selectedKbId = null; selectedKbName = null; }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: useCustomCondition ? Colors.orange.withValues(alpha: 0.12) : AppTheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: useCustomCondition ? Colors.orange : AppTheme.outlineVariant.withValues(alpha: 0.5),
                                  width: useCustomCondition ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                'Custom Condition',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: useCustomCondition ? Colors.orange.shade800 : AppTheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (!useCustomCondition) ...[
                      // Search bar
                      Text('Search Verified Condition', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: searchCtrl,
                        onChanged: filterKb,
                        decoration: InputDecoration(
                          hintText: 'Type to search disease or pest...',
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          filled: true,
                          fillColor: AppTheme.surfaceContainerHigh,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Selected item display
                      if (selectedKbName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Selected: $selectedKbName',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setModalState(() { selectedKbId = null; selectedKbName = null; }),
                                child: const Icon(Icons.close_rounded, size: 18, color: AppTheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),

                      // KB List
                      if (_kbItems.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Knowledge base not loaded. Use "Custom Condition" to enter the verified diagnosis manually.',
                                  style: GoogleFonts.inter(fontSize: 12, color: Colors.orange.shade800),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredKb.length,
                            itemBuilder: (ctx, i) {
                              final kb = filteredKb[i] as Map<String, dynamic>;
                              final isSelected = selectedKbId == kb['id'];
                              final category = kb['category'] ?? 'DISEASE';
                              return GestureDetector(
                                onTap: () => setModalState(() {
                                  selectedKbId = kb['id'];
                                  selectedKbName = '[$category] ${kb['name']}';
                                }),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : AppTheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? AppTheme.primary : AppTheme.outlineVariant.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: category == 'DISEASE' ? AppTheme.error.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          category,
                                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: category == 'DISEASE' ? AppTheme.error : Colors.orange.shade800),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          kb['name'] ?? 'Unknown',
                                          style: GoogleFonts.inter(fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? AppTheme.primary : AppTheme.onSurface),
                                        ),
                                      ),
                                      if (isSelected) const Icon(Icons.check_rounded, size: 18, color: AppTheme.primary),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ] else ...[
                      // Custom Condition Input
                      Text('Verified Condition Name', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: customConditionCtrl,
                        onChanged: (val) => setModalState(() {}),
                        decoration: InputDecoration(
                          hintText: 'e.g. Fusarium Crown Rot, Aphid Infestation...',
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
                          prefixIcon: const Icon(Icons.edit_rounded, size: 20),
                          filled: true,
                          fillColor: AppTheme.surfaceContainerHigh,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Custom conditions are added to the expert notes. The system will record the correction but may not link to a specific knowledge base entry.',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.orange.shade800),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Notes
                    Text('Agronomist Explanation', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Describe visual evidence and corrected IPM advisory steps...',
                        hintStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
                        filled: true,
                        fillColor: AppTheme.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Correction Button
                    if (isSubmitting)
                      const Center(child: CircularProgressIndicator())
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (!useCustomCondition && selectedKbId == null) || (useCustomCondition && customConditionCtrl.text.trim().isEmpty)
                              ? null
                              : () async {
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    final Map<String, dynamic> payload = {
                                      'diagnosis_id': item['id'],
                                      'is_correct': false,
                                    };

                                    if (!useCustomCondition) {
                                      final selectedKb = _kbItems.firstWhere((k) => k['id'] == selectedKbId, orElse: () => null);
                                      final isDisease = selectedKb?['category'] == 'DISEASE';
                                      payload['corrected_disease_id'] = isDisease ? selectedKbId : null;
                                      payload['corrected_pest_id'] = !isDisease ? selectedKbId : null;
                                      final baseName = selectedKb?['name'] ?? 'Unknown';
                                      payload['expert_notes'] = notesCtrl.text.trim().isEmpty
                                          ? 'Corrected to: $baseName.'
                                          : 'Corrected to: $baseName. ${notesCtrl.text.trim()}';
                                    } else {
                                      final customName = customConditionCtrl.text.trim();
                                      payload['expert_notes'] = 'Verified condition: $customName. ${notesCtrl.text.trim()}';
                                    }

                                    await apiClient.post('/experts/validations', data: payload);
                                    if (context.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Diagnosis successfully corrected! Farmer notified.')),
                                      );
                                      _loadAllData();
                                    }
                                  } catch (e) {
                                    setModalState(() => isSubmitting = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error updating: $e')),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'Submit Corrected Diagnosis',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── PHASE 2B: LAB REFERRAL MODAL ──────────────────────────────────────────
  void _showLabReferralModal(Map<String, dynamic> item) {
    final labNameCtrl = TextEditingController(text: 'Regional Plant Pathology Lab');
    final trackingCtrl = TextEditingController(text: 'LAB-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final notesCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.biotech_rounded, color: Colors.purple, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Refer to Laboratory',
                        style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.purple),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Order an official microscopic / PCR assay when field symptoms are ambiguous or novel.',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),

                  // Laboratory Name
                  Text(
                    'Laboratory / Institute Name',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onSurface),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: labNameCtrl,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Sample Tracking Code
                  Text(
                    'Tracking / Sample ID',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onSurface),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: trackingCtrl,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Sampling Guidelines
                  Text(
                    'Sample Collection & Transit Instructions',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onSurface),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g. Cut 3 leaf margins, keep in paper bag on ice, dispatch within 24h...',
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
                      filled: true,
                      fillColor: AppTheme.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit Lab Referral
                  if (isSubmitting)
                    const Center(child: CircularProgressIndicator())
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (labNameCtrl.text.trim().isEmpty) return;
                          setModalState(() => isSubmitting = true);
                          try {
                            await apiClient.post('/labs/referrals', data: {
                              'diagnosis_id': item['id'],
                              'lab_name': labNameCtrl.text.trim(),
                              'tracking_number': trackingCtrl.text.trim(),
                              'status': 'PENDING',
                              'results_summary': notesCtrl.text.trim().isEmpty ? 'Sample requested for laboratory confirmation.' : notesCtrl.text.trim(),
                            });
                            if (context.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Referred to laboratory! Sample ID generated.')),
                              );
                              _loadAllData();
                            }
                          } catch (e) {
                            setModalState(() => isSubmitting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error creating referral: $e')),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Generate Lab Referral & Dispatch Order',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ══════════════════ UPDATE LAB REFERRAL STATUS MODAL ══════════════════
  void _showUpdateReferralModal(Map<String, dynamic> ref) {
    String selectedStatus = ref['status'] ?? 'PENDING';
    
    // Clear the default placeholder text or transit instructions so the actual hintText is visible
    String initialNotes = ref['results_summary'] ?? '';
    if (initialNotes == 'Sample requested for laboratory confirmation.' || selectedStatus == 'PENDING') {
      initialNotes = '';
    }
    final resultsCtrl = TextEditingController(text: initialNotes);
    bool isSubmitting = false;

    final statuses = ['PENDING', 'ANALYZING', 'COMPLETED'];
    final statusColors = {
      'PENDING': Colors.orange,
      'ANALYZING': Colors.blue,
      'COMPLETED': const Color(0xFF276C00),
    };

    // Build the shared modal content
    Widget buildContent(BuildContext ctx, StateSetter setModalState, ScrollController? scrollController) {
      return Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: ListView(
          controller: scrollController,
          shrinkWrap: true,
          children: [
            // Handle bar (same as queue cases section)
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: AppTheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('Update Lab Referral',
                style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.onSurface)),
            const SizedBox(height: 4),
            Text('Tracking: ${ref['tracking_number'] ?? 'N/A'}',
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant)),
            const SizedBox(height: 20),

            // Status Selector
            Text('Status', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: statuses.map((s) {
                final isSelected = selectedStatus == s;
                final isAlreadyCompleted = ref['status'] == 'COMPLETED';
                final color = statusColors[s] ?? Colors.grey;
                final double opacity = isAlreadyCompleted && !isSelected ? 0.4 : 1.0;
                
                return GestureDetector(
                  onTap: isAlreadyCompleted ? null : () => setModalState(() => selectedStatus = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? color : AppTheme.outlineVariant.withValues(alpha: 0.5),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Opacity(
                      opacity: opacity,
                      child: Text(
                        s.replaceAll('_', ' '),
                        style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: isSelected ? color : AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Results / Notes
            Text('Lab Results / Notes', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
            const SizedBox(height: 8),
            TextField(
              controller: resultsCtrl,
              onChanged: (_) => setModalState(() {}), // Trigger rebuild to update button state
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter lab results, findings, or status update notes...',
                hintStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
                filled: true,
                fillColor: AppTheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            Builder(
              builder: (context) {
                final bool hasChanges = selectedStatus != (ref['status'] ?? 'PENDING') || 
                                        resultsCtrl.text.trim() != initialNotes.trim();
                
                bool canSubmit = hasChanges;
                if (selectedStatus == 'COMPLETED' && resultsCtrl.text.trim().isEmpty) {
                  canSubmit = false;
                }
                
                if (isSubmitting) return const Center(child: CircularProgressIndicator());
                
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: !canSubmit ? null : () async {
                    setModalState(() => isSubmitting = true);
                    try {
                      await apiClient.put('/labs/referrals/${ref['id']}', data: {
                        'status': selectedStatus,
                        'results_summary': resultsCtrl.text.trim(),
                      });
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lab referral status updated!')),
                        );
                        _loadAllData();
                      }
                    } catch (e) {
                      setModalState(() => isSubmitting = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error updating referral: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColors[selectedStatus] ?? Colors.purple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Save Status Update',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  ),
                ); // End of SizedBox
              }, // End of Builder function
            ), // End of Builder
          ],
        ),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (isDesktop) {
      // ── Desktop: centred Dialog (closes on outside tap) ────────────────
      showDialog(
        context: context,
        barrierDismissible: false,
        useSafeArea: false,
        barrierColor: Colors.transparent, // We draw our own overlay
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) => Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                // ── Full-screen dismiss layer (our own barrier) ──
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(ctx),
                    child: Container(color: Colors.black.withValues(alpha: 0.5)),
                  ),
                ),
                // ── Centred card (absorbs its own taps) ──
                Center(
                  child: GestureDetector(
                    onTap: () {}, // Block propagation to the dismiss layer
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Material(
                        borderRadius: BorderRadius.circular(24),
                        color: AppTheme.surface,
                        child: buildContent(ctx, setModalState, null),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // ── Mobile: swipe-down bottom sheet ────────────────────────────────
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        isDismissible: true,
        enableDrag: true,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) => DraggableScrollableSheet(
            initialChildSize: 0.65,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            builder: (_, scrollController) => Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: buildContent(ctx, setModalState, scrollController),
            ),
          ),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Sliver Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerHighest.withValues(alpha: 0.8),
                border: Border(bottom: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.3))),
              ),
              child: Row(
                children: [
                  if (widget.showBackButton) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded, color: AppTheme.primary, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.biotech_rounded, color: AppTheme.primary, size: 20),
                    ),
                  ],

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Agronomist Review Desk',
                          style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primary),
                        ),
                        Text(
                          'Expert triage, validation & lab referrals',
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
                    onPressed: _loadAllData,
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              color: AppTheme.surface,
              child: TabBar(
                controller: _tabController,
                onTap: (index) {
                  setState(() {
                    _tabController.index = index;
                  });
                },
                indicatorColor: AppTheme.primary,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.onSurfaceVariant,
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.pending_actions_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text('Pending (${_pendingReviews.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.biotech_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text('Lab Referrals (${_labReferrals.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.history_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text('Follow-Ups (${_followUpCases.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.task_alt_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text('Completed (${_completedCases.length})'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lock_outline_rounded, size: 48, color: Colors.orange),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(fontSize: 14, color: AppTheme.onSurface),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadAllData,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildPendingList(),
                            _buildLabList(),
                            _buildFollowUpList(),
                            _buildCompletedCasesList(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingList() {
    if (_pendingReviews.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.task_alt_rounded, size: 48, color: Color(0xFF276C00)),
              ),
              const SizedBox(height: 16),
              Text(
                'Queue is Clear!',
                style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'There are currently no cases waiting for expert review.\nScans with low confidence or manual farmer requests will appear here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingReviews.length,
      itemBuilder: (context, index) {
        final item = _pendingReviews[index] as Map<String, dynamic>;
        final imageUrl = item['image_url'] ?? '';
        String diagType = item['diagnosis_type'] ?? 'DISEASE';
        if (diagType == 'UNKNOWN') diagType = 'DISEASE';
        final kbName = item['disease_name'] ?? item['pest_name'] ?? item['model_version'] ?? diagType;
        final confidence = ((item['confidence'] ?? 0.0) * 100).toStringAsFixed(1);
        final severity = item['severity'] ?? 'MODERATE';
        final createdAt = (item['created_at'] ?? '').toString();
        final dateStr = createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
          ),
          color: AppTheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 70,
                        height: 70,
                        color: AppTheme.surfaceContainerHigh,
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl.startsWith('http') ? imageUrl : 'http://10.0.2.2:8000$imageUrl',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_rounded, color: AppTheme.onSurfaceVariant),
                              )
                            : const Icon(Icons.image_not_supported_rounded, color: AppTheme.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'AWAITING REVIEW',
                                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                                ),
                              ),
                              Text(
                                dateStr,
                                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            kbName,
                            style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'AI Conf: $confidence%',
                                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.onSurfaceVariant),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                severity.toUpperCase(),
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _severityColor(severity)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Review Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showValidationModal(item),
                    icon: const Icon(Icons.fact_check_rounded, size: 16, color: AppTheme.primary),
                    label: Text(
                      'Triage & Review Case',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.primary, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryContainer,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFollowUpList() {
    if (_followUpCases.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFE3F2FD),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.history_rounded, size: 48, color: Color(0xFF1565C0)),
              ),
              const SizedBox(height: 16),
              Text(
                'No Follow-Ups',
                style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'There are no active follow-up cases waiting for expert review.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _followUpCases.length,
      itemBuilder: (context, index) {
        final item = _followUpCases[index] as Map<String, dynamic>;
        final imageUrl = item['image_url'] ?? '';
        String diagType = item['diagnosis_type'] ?? 'DISEASE';
        if (diagType == 'UNKNOWN') diagType = 'DISEASE';
        
        final kbName = item['disease_name'] ?? item['pest_name'] ?? item['model_version'] ?? diagType;
        final severity = item['severity'] ?? 'MODERATE';

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
          ),
          color: AppTheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 70,
                        height: 70,
                        color: AppTheme.surfaceContainerHigh,
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl.startsWith('http') ? imageUrl : 'http://10.0.2.2:8000$imageUrl',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_rounded, color: AppTheme.onSurfaceVariant),
                              )
                            : const Icon(Icons.image_not_supported_rounded, color: AppTheme.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              diagType,
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.onSurfaceVariant),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            kbName,
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            severity.toUpperCase(),
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _severityColor(severity)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetectionResultScreen(resultData: item, isExpertMode: true),
                            ),
                          );
                        },
                        icon: const Icon(Icons.analytics_outlined, size: 16, color: AppTheme.primary),
                        label: Text(
                          'Original AI Detection',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.primary, fontSize: 11),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.primary),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final diagId = item['id'];
                          if (diagId != null) {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => MonitoringHistoryScreen(diagnosisId: diagId, isExpertMode: true),
                            )).then((_) {
                              _loadAllData();
                            });
                          }
                        },
                        icon: const Icon(Icons.history_rounded, size: 16, color: Colors.white),
                        label: Text(
                          'Review Follow-Up Logs',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 11),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLabList() {
    if (_labReferrals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.biotech_rounded, size: 48, color: Colors.purple),
              ),
              const SizedBox(height: 16),
              Text(
                'No Active Lab Referrals',
                style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'When you refer complex or unusual samples to diagnostic laboratories, tracking numbers and status will show here.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _labReferrals.length,
      itemBuilder: (context, index) {
        final ref = _labReferrals[index] as Map<String, dynamic>;
        final labName = ref['lab_name'] ?? 'Diagnostic Lab';
        final tracking = ref['tracking_number'] ?? 'N/A';
        final status = ref['status'] ?? 'PENDING';
        final summary = ref['results_summary'] ?? '';
        final statusColor = status == 'COMPLETED'
            ? const Color(0xFF276C00)
            : status == 'ANALYZING'
                ? Colors.blue
                : status == 'CANCELLED'
                    ? AppTheme.error
                    : Colors.purple;
        final statusBg = status == 'COMPLETED'
            ? const Color(0xFFE8F5E9)
            : status == 'ANALYZING'
                ? Colors.blue.withValues(alpha: 0.1)
                : status == 'CANCELLED'
                    ? AppTheme.error.withValues(alpha: 0.1)
                    : Colors.purple.withValues(alpha: 0.12);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
          ),
          color: AppTheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.science_rounded, size: 18, color: Colors.purple),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              labName,
                              style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.onSurface),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status.replaceAll('_', ' '),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tracking Code: $tracking',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.onSurfaceVariant),
                ),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    summary,
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurface),
                  ),
                ],
                const SizedBox(height: 12),
                // Update Status Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showUpdateReferralModal(ref),
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: Text('Update Status & Results', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple,
                      side: BorderSide(color: Colors.purple.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompletedCasesList() {
    if (_completedCases.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.task_alt_rounded, size: 48, color: AppTheme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'No Completed Cases Yet',
                style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'Cases you confirm or correct will appear here as your personal review history.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _completedCases.length,
      itemBuilder: (context, index) {
        final c = _completedCases[index] as Map<String, dynamic>;
        final status = c['status'] ?? 'CONFIRMED';
        final isConfirmed = status == 'CONFIRMED';
        final label = c['label'] ?? c['diagnosis_type'] ?? 'Unknown';
        final cropName = c['crop_name'] ?? 'Unknown Crop';
        final confidence = ((c['confidence'] as num?)?.toDouble() ?? 0.0) * 100;
        final severity = (c['severity'] ?? 'unknown').toString().toUpperCase();
        final imageUrl = c['image_url'] ?? '';
        final createdAt = c['created_at'] != null
            ? c['created_at'].toString().substring(0, 10)
            : 'N/A';
        final expertName = c['expert_name'] ?? 'You';
        final expertNotes = c['expert_notes'] ?? '';

        final statusColor = isConfirmed ? const Color(0xFF276C00) : AppTheme.primary;
        final statusBg = isConfirmed ? const Color(0xFFE8F5E9) : AppTheme.primary.withValues(alpha: 0.1);
        final statusIcon = isConfirmed ? Icons.check_circle_rounded : Icons.edit_note_rounded;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
          ),
          color: AppTheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Thumbnail
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isConfirmed ? const Color(0xFFE8F5E9) : const Color(0xFFFFEDE6),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl.startsWith('http') ? imageUrl : 'http://10.0.2.2:8000$imageUrl',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  isConfirmed ? Icons.check_circle_outline_rounded : Icons.edit_rounded,
                                  color: statusColor, size: 26,
                                ),
                              )
                            : Icon(isConfirmed ? Icons.check_circle_outline_rounded : Icons.edit_rounded, color: statusColor, size: 26),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$cropName · ${confidence.toInt()}% conf',
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            isConfirmed ? 'Confirmed' : 'Corrected',
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Severity + Date row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _severityColor(severity).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        severity,
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _severityColor(severity)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.calendar_today_rounded, size: 12, color: AppTheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(createdAt, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.onSurfaceVariant)),
                    const Spacer(),
                    Icon(Icons.person_rounded, size: 13, color: AppTheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(expertName, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.onSurfaceVariant)),
                  ],
                ),
                // Expert notes
                if (expertNotes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      expertNotes,
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.onSurface, fontStyle: FontStyle.italic),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
