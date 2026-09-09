import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cropdect/models/monitoring_log.dart';
import 'package:cropdect/services/monitoring_service.dart';
import 'package:cropdect/theme.dart';

class MonitoringHistoryScreen extends StatefulWidget {
  final int diagnosisId;
  final bool isExpertMode;

  const MonitoringHistoryScreen({Key? key, required this.diagnosisId, this.isExpertMode = false}) : super(key: key);

  @override
  State<MonitoringHistoryScreen> createState() => _MonitoringHistoryScreenState();
}

class _MonitoringHistoryScreenState extends State<MonitoringHistoryScreen> {
  late Future<List<MonitoringLog>> _logsFuture;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  void _fetchLogs() {
    setState(() {
      _logsFuture = monitoringService.getMonitoringLogs(widget.diagnosisId);
    });
  }

  String _resolveImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (!path.startsWith('/')) path = '/$path';
    return 'http://127.0.0.1:8000$path';
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'IMPROVING': return Icons.trending_up_rounded;
      case 'WORSENING': return Icons.trending_down_rounded;
      case 'RESOLVED': return Icons.check_circle_rounded;
      default: return Icons.horizontal_rule_rounded;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'IMPROVING': return 'Improving';
      case 'WORSENING': return 'Worsening';
      case 'RESOLVED': return 'Resolved';
      default: return 'No Change';
    }
  }

  void _showExpertReviewDialog(MonitoringLog log) {
    final notesController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceContainerLowest,
              title: Text('Expert Review', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: AppTheme.primary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Provide agronomic advice or feedback for this follow-up log.', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Your recommendations...',
                      filled: true,
                      fillColor: AppTheme.surfaceContainerHigh,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.outline)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : () async {
                    if (notesController.text.trim().isEmpty) return;
                    setDialogState(() => isSubmitting = true);
                    try {
                      await monitoringService.submitExpertReview(
                        logId: log.id,
                        expertNotes: notesController.text,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      _fetchLogs();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Expert review submitted successfully!'), backgroundColor: Color(0xFF1565C0)),
                        );
                      }
                    } catch (e) {
                      setDialogState(() => isSubmitting = false);
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Submit Review', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'IMPROVING': return const Color(0xFF2E7D32);
      case 'WORSENING': return const Color(0xFFD32F2F);
      case 'RESOLVED': return const Color(0xFF1B5E20);
      default: return const Color(0xFFE65100);
    }
  }

  void _showAddLogSheet() {
    File? selectedImage;
    XFile? selectedXFile;
    String healthStatus = 'NO_CHANGE';
    final notesController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Add Follow-Up Log', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, color: AppTheme.outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Status Dropdown
                    Text('Crop Health Status', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: healthStatus,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primary),
                          items: [
                            DropdownMenuItem(value: 'IMPROVING', child: Row(children: [Icon(Icons.trending_up_rounded, color: _getStatusColor('IMPROVING'), size: 18), const SizedBox(width: 8), const Text('Improving')])),
                            DropdownMenuItem(value: 'NO_CHANGE', child: Row(children: [Icon(Icons.horizontal_rule_rounded, color: _getStatusColor('NO_CHANGE'), size: 18), const SizedBox(width: 8), const Text('No Change')])),
                            DropdownMenuItem(value: 'WORSENING', child: Row(children: [Icon(Icons.trending_down_rounded, color: _getStatusColor('WORSENING'), size: 18), const SizedBox(width: 8), const Text('Worsening')])),
                            DropdownMenuItem(value: 'RESOLVED', child: Row(children: [Icon(Icons.check_circle_rounded, color: _getStatusColor('RESOLVED'), size: 18), const SizedBox(width: 8), const Text('Resolved (Cured)')])),
                          ],
                          onChanged: (val) {
                            if (val != null) setSheetState(() => healthStatus = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Image Picker
                    Text('Current Photo (Optional)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    if (selectedImage == null && selectedXFile == null)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                                if (image != null) {
                                  selectedXFile = image;
                                  if (!kIsWeb) selectedImage = File(image.path);
                                  setSheetState(() {});
                                }
                              },
                              icon: const Icon(Icons.camera_alt_rounded, size: 18),
                              label: const Text('Camera'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                                if (image != null) {
                                  selectedXFile = image;
                                  if (!kIsWeb) selectedImage = File(image.path);
                                  setSheetState(() {});
                                }
                              },
                              icon: const Icon(Icons.photo_library_rounded, size: 18),
                              label: const Text('Gallery'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Stack(
                        children: [
                          Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.outlineVariant),
                              image: selectedImage != null
                                  ? DecorationImage(image: FileImage(selectedImage!), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: selectedImage == null && selectedXFile != null
                                ? const Center(child: Icon(Icons.image_rounded, color: AppTheme.primary, size: 32))
                                : null,
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Material(
                              color: Colors.black54,
                              shape: const CircleBorder(),
                              child: IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  selectedXFile = null;
                                  selectedImage = null;
                                  setSheetState(() {});
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),

                    // Notes
                    Text('Observations', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'What have you noticed? Applied any treatments?',
                        filled: true,
                        fillColor: AppTheme.surfaceContainerHigh,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isSubmitting ? null : () async {
                          setSheetState(() => isSubmitting = true);
                          try {
                            await monitoringService.addMonitoringLog(
                              diagnosisId: widget.diagnosisId,
                              healthStatus: healthStatus,
                              notes: notesController.text,
                              imageFile: selectedImage,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            _fetchLogs();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Follow-up log saved successfully!'), backgroundColor: Color(0xFF2E7D32)),
                              );
                            }
                          } catch (e) {
                            setSheetState(() => isSubmitting = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                            }
                          }
                        },
                        icon: isSubmitting
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_rounded),
                        label: Text(isSubmitting ? 'Saving...' : 'Save Log', style: const TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Monitoring History', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surfaceContainerLowest,
        elevation: 0,
      ),
      body: FutureBuilder<List<MonitoringLog>>(
        future: _logsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text('Failed to load monitoring logs', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.outline), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _fetchLogs,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final logs = snapshot.data ?? [];

          if (logs.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                _fetchLogs();
                await _logsFuture;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.monitor_heart_outlined, size: 72, color: AppTheme.primary.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Text('No follow-up logs yet', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.onSurface)),
                          const SizedBox(height: 8),
                          Text('Track the progress of your crop\nby adding follow-up reports over time.', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.outline), textAlign: TextAlign.center),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _showAddLogSheet,
                            icon: const Icon(Icons.add_a_photo_rounded),
                            label: const Text('Add First Log', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _fetchLogs();
              await _logsFuture;
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
              itemCount: logs.length + 1, // +1 for the header
            itemBuilder: (context, index) {
              if (index == 0) {
                // Timeline header
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.timeline_rounded, color: AppTheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('${logs.length} follow-up${logs.length == 1 ? '' : 's'} recorded', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    ],
                  ),
                );
              }

              final log = logs[index - 1];
              final isFirst = index == 1;
              final statusColor = _getStatusColor(log.healthStatus);

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Timeline indicator
                    SizedBox(
                      width: 32,
                      child: Column(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 3),
                            ),
                          ),
                          Expanded(
                            child: Container(width: 2, color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Card content
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isFirst ? statusColor.withValues(alpha: 0.4) : AppTheme.outlineVariant),
                          boxShadow: isFirst ? [BoxShadow(color: statusColor.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))] : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('MMM dd, yyyy • hh:mm a').format(log.createdAt),
                                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.outline, fontWeight: FontWeight.w600),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_getStatusIcon(log.healthStatus), size: 14, color: statusColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        _getStatusLabel(log.healthStatus),
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (log.imageUrl != null) ...[
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  _resolveImageUrl(log.imageUrl!),
                                  height: 160,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 80,
                                    decoration: BoxDecoration(color: AppTheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(10)),
                                    child: const Center(child: Icon(Icons.broken_image_rounded, color: AppTheme.outline)),
                                  ),
                                ),
                              ),
                            ],
                            if (log.notes != null && log.notes!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.notes_rounded, size: 16, color: AppTheme.outline),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(log.notes!, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurface))),
                                  ],
                                ),
                              ),
                            ],
                            // Expert review section
                            if (log.expertReviewed && log.expertNotes != null && log.expertNotes!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE3F2FD),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF90CAF9)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF1565C0)),
                                        const SizedBox(width: 6),
                                        Text('Expert Review', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1565C0))),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(log.expertNotes!, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0D47A1), fontStyle: FontStyle.italic)),
                                  ],
                                ),
                              ),
                            ] else if (!log.expertReviewed && log.healthStatus != 'RESOLVED') ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.schedule_rounded, size: 14, color: AppTheme.outline.withValues(alpha: 0.6)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text('Awaiting expert review', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.outline.withValues(alpha: 0.6))),
                                  ),
                                  if (widget.isExpertMode)
                                    TextButton.icon(
                                      onPressed: () => _showExpertReviewDialog(log),
                                      icon: const Icon(Icons.add_comment_rounded, size: 14, color: Color(0xFF1565C0)),
                                      label: Text('Add Review', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1565C0))),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          );
        },
      ),
      floatingActionButton: widget.isExpertMode
          ? null
          : FutureBuilder<List<MonitoringLog>>(
              future: _logsFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  final latestLog = snapshot.data!.first;
                  if (latestLog.healthStatus == 'RESOLVED') {
                    return const SizedBox.shrink();
                  }
                }
                return FloatingActionButton.extended(
                  onPressed: _showAddLogSheet,
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_a_photo_rounded),
                  label: const Text('Add Log', style: TextStyle(fontWeight: FontWeight.bold)),
                );
              },
            ),
    );
  }
}
