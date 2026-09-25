import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme.dart';
import '../api_client.dart';
import 'detection_result_screen.dart';
import '../widgets/translated_text.dart';

class ConsultExpertScreen extends StatefulWidget {
  final int? highlightDiagnosisId;
  const ConsultExpertScreen({super.key, this.highlightDiagnosisId});

  @override
  State<ConsultExpertScreen> createState() => _ConsultExpertScreenState();
}

class _ConsultExpertScreenState extends State<ConsultExpertScreen> {
  late Future<List<dynamic>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _fetchHistory();
  }

  Future<List<dynamic>> _fetchHistory() async {
    try {
      final response = await apiClient.get('/diagnostics/history');
      if (response.statusCode == 200) {
        final list = (response.data as List)
            .where((d) => d['status'] == 'EXPERT_REVIEW' || d['status'] == 'CONFIRMED' || d['status'] == 'CORRECTED' || d['status'] == 'LAB_REFERRED')
            .toList();
            
        if (widget.highlightDiagnosisId != null) {
          list.sort((a, b) {
            if (a['id'] == widget.highlightDiagnosisId) return -1;
            if (b['id'] == widget.highlightDiagnosisId) return 1;
            return 0;
          });
        }
        return list;
      }
    } catch (_) {}
    return [];
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'EXPERT_REVIEW': return Colors.orange;
      case 'CONFIRMED': return AppTheme.secondary;
      case 'CORRECTED': return AppTheme.primary;
      case 'LAB_REFERRED': return Colors.purple;
      default: return AppTheme.onSurfaceVariant;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'EXPERT_REVIEW': return Icons.hourglass_top_rounded;
      case 'CONFIRMED': return Icons.check_circle_rounded;
      case 'CORRECTED': return Icons.edit_note_rounded;
      case 'LAB_REFERRED': return Icons.biotech_rounded;
      default: return Icons.help_outline;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'EXPERT_REVIEW': return 'Awaiting Expert Review';
      case 'CONFIRMED': return 'Expert Confirmed';
      case 'CORRECTED': return 'Expert Corrected Diagnosis';
      case 'LAB_REFERRED': return 'Referred to Laboratory';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _historyFuture = _fetchHistory();
            });
            await _historyFuture;
          },
          color: AppTheme.primary,
          child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppTheme.surfaceContainerHighest.withValues(alpha: 0.8),
              elevation: 0,
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(color: Colors.transparent),
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, color: AppTheme.primary),
                onPressed: () => Navigator.pop(context),
              ),
              title: const TranslatedText('Expert Consultations', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primaryContainer, AppTheme.primaryContainer.withValues(alpha: 0.6)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), shape: BoxShape.circle),
                            child: const Icon(Icons.verified_user_rounded, color: AppTheme.primary, size: 24),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TranslatedText('Expert Review System', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.onPrimaryContainer)),
                                SizedBox(height: 4),
                                TranslatedText('Scans with low AI confidence are automatically sent to agronomists for validation.', style: TextStyle(fontSize: 12, color: AppTheme.onPrimaryContainer)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const TranslatedText('YOUR CONSULTATIONS', style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    const SizedBox(height: 16),
                    FutureBuilder<List<dynamic>>(
                      future: _historyFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
                        }
                        final items = snapshot.data ?? [];
                        if (items.isEmpty) {
                          return _buildEmptyState();
                        }
                        return Column(
                          children: items.map((diag) => _buildConsultCard(diag)).toList(),
                        );
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
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.primaryContainer, shape: BoxShape.circle),
            child: const Icon(Icons.search_off_rounded, color: AppTheme.primary, size: 40),
          ),
          const SizedBox(height: 20),
          const TranslatedText('No Expert Reviews Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.onSurface)),
          const SizedBox(height: 8),
          const TranslatedText(
            'When your crop scan requires expert validation, it will appear here. Scans with AI confidence below 85% are automatically flagged for expert review.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildConsultCard(Map<String, dynamic> diag) {
    final bool isHighlighted = diag['id'] == widget.highlightDiagnosisId;
    final status = diag['status'] ?? 'UNKNOWN';
    final statusColor = _statusColor(status);
    final label = diag['label'] ?? 'Unknown Condition';
    final cropName = diag['crop_name'] ?? '';
    final confidence = ((diag['confidence'] as num?)?.toDouble() ?? 0) * 100;
    final severity = diag['severity'] ?? '';
    final imageUrl = diag['image_url'] as String?;
    final expertNotes = diag['expert_notes'] as String?;
    final expertName = diag['expert_name'] ?? 'Agronomist';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetectionResultScreen(resultData: diag),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isHighlighted ? statusColor.withValues(alpha: 0.05) : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isHighlighted ? statusColor : statusColor.withValues(alpha: 0.3),
            width: isHighlighted ? 2.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isHighlighted ? statusColor.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.04), 
              blurRadius: isHighlighted ? 16 : 12, 
              offset: const Offset(0, 4)
            )
          ],
        ),
      child: Column(
        children: [
          // Status header stripe
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(_statusIcon(status), color: statusColor, size: 16),
                const SizedBox(width: 8),
                Expanded(child: TranslatedText(_statusLabel(status), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: TranslatedText(status.replaceAll('_', ' '), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          // Card body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageUrl != null && imageUrl.startsWith('http')
                      ? Image.network(imageUrl, width: 72, height: 72, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imageFallback())
                      : _imageFallback(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TranslatedText(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.onSurface)),
                      if (cropName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        TranslatedText(cropName, style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12)),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _infoChip('AI: ${confidence.toStringAsFixed(0)}%', Icons.psychology_rounded, AppTheme.primary),
                          const SizedBox(width: 8),
                          if (severity.isNotEmpty)
                            _infoChip(severity, Icons.thermostat_rounded, _severityColor(severity)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Status-specific message
          if (status == 'EXPERT_REVIEW')
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: const Row(children: [
                Icon(Icons.access_time_rounded, color: Colors.orange, size: 14),
                SizedBox(width: 8),
                Expanded(child: TranslatedText('An agronomist will review this shortly. You will be notified.', style: TextStyle(color: Colors.orange, fontSize: 12))),
              ]),
            )
          else if (status == 'CONFIRMED' || status == 'CORRECTED' || status == 'LAB_REFERRED')
            Builder(
              builder: (context) {
                final isLabResult = expertName == 'Laboratory Diagnostics' || (expertNotes != null && expertNotes.contains('[Lab Result:'));
                final isLabInstruction = expertNotes != null && expertNotes.contains('[Lab Instructions:');
                final isLabUpdate = expertNotes != null && expertNotes.contains('[Lab Update:');
                final isLab = isLabResult || isLabInstruction || isLabUpdate;
                
                final bgColor = isLab ? Colors.purple : AppTheme.secondary;
                final iconData = isLab ? Icons.science_rounded : Icons.check_circle_rounded;
                
                String titleText = '';
                if (status == 'LAB_REFERRED') {
                  titleText = 'Referred to laboratory for analysis.';
                } else {
                  titleText = isLabResult
                      ? 'Laboratory analysis completed.'
                      : (status == 'CORRECTED' ? '$expertName updated the diagnosis.' : '$expertName confirmed the AI diagnosis.');
                }
                
                // Clean up the prefix for a cleaner UI if present
                String displayNotes = expertNotes ?? '';
                String labName = 'Laboratory';
                if (isLabResult && displayNotes.startsWith('[Lab Result:')) {
                  final endIndex = displayNotes.indexOf(']');
                  if (endIndex != -1) {
                    labName = displayNotes.substring(13, endIndex);
                    displayNotes = displayNotes.substring(endIndex + 1).trim();
                  }
                } else if (isLabInstruction && displayNotes.startsWith('[Lab Instructions:')) {
                  final endIndex = displayNotes.indexOf(']');
                  if (endIndex != -1) {
                    labName = displayNotes.substring(19, endIndex);
                    displayNotes = displayNotes.substring(endIndex + 1).trim();
                  }
                } else if (isLabUpdate && displayNotes.startsWith('[Lab Update:')) {
                  final endIndex = displayNotes.indexOf(']');
                  if (endIndex != -1) {
                    labName = displayNotes.substring(13, endIndex);
                    displayNotes = displayNotes.substring(endIndex + 1).trim();
                  }
                }

                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: bgColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(iconData, color: bgColor, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: TranslatedText(titleText, style: TextStyle(color: bgColor, fontSize: 13, fontWeight: FontWeight.bold))),
                      ]),
                      if (displayNotes.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isLab ? Colors.white : AppTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                            border: isLab ? Border.all(color: bgColor.withValues(alpha: 0.3)) : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isLab) ...[
                                Row(
                                  children: [
                                    Icon(Icons.biotech_rounded, size: 14, color: bgColor),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: TranslatedText(
                                        isLabResult ? 'OFFICIAL REPORT: ${labName.toUpperCase()}' : 
                                        isLabInstruction ? 'SAMPLING INSTRUCTIONS: ${labName.toUpperCase()}' :
                                        'LABORATORY UPDATE: ${labName.toUpperCase()}', 
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: bgColor, letterSpacing: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                              TranslatedText(
                                displayNotes,
                                style: TextStyle(
                                  fontSize: 13, 
                                  height: 1.4,
                                  fontStyle: isLab ? FontStyle.normal : FontStyle.italic, 
                                  color: AppTheme.onSurface
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }
            ),
        ],
      ),
    ));
  }

  Widget _infoChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 4),
        TranslatedText(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _imageFallback() => Container(
    width: 72, height: 72,
    decoration: BoxDecoration(color: AppTheme.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
    child: const Icon(Icons.image_not_supported_rounded, color: AppTheme.onSurfaceVariant, size: 28),
  );

  Color _severityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL': return AppTheme.error;
      case 'HIGH': return Colors.orange;
      case 'MODERATE': return Colors.amber;
      default: return AppTheme.secondary;
    }
  }
}
