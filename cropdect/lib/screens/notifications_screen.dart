import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cropdect/theme.dart';
import 'package:cropdect/models/notification.dart';
import 'package:cropdect/services/notification_service.dart';
import 'consult_expert_screen.dart';
import 'monitoring_history_screen.dart';
import '../widgets/translated_text.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<NotificationModel>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  void _fetchNotifications() {
    setState(() {
      _notificationsFuture = notificationService.getNotifications();
    });
  }

  Future<void> _handleNotificationTap(NotificationModel notification) async {
    // 1. Mark as read if unread
    if (!notification.isRead) {
      try {
        await notificationService.markAsRead(notification.id);
        _fetchNotifications(); // Refresh list silently
      } catch (_) {}
    }
    
    // 2. Navigate if there is a reference ID (diagnosis case)
    if (notification.referenceId != null) {
      if (notification.title == 'Expert Review Added') {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MonitoringHistoryScreen(diagnosisId: notification.referenceId!),
            ),
          );
        }
      } else if (notification.type == 'LAB_RESULT' || notification.type == 'EXPERT_UPDATE' || notification.type == 'DIAGNOSIS_UPDATE') {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConsultExpertScreen(highlightDiagnosisId: notification.referenceId),
            ),
          );
        }
      }
    }
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} at $hour:${local.minute.toString().padLeft(2, '0')} $ampm';
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'SYSTEM_ALERT':
        return Icons.warning_rounded;
      case 'EXPERT_UPDATE':
        return Icons.support_agent_rounded;
      case 'LAB_RESULT':
        return Icons.biotech_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'SYSTEM_ALERT':
        return Colors.redAccent;
      case 'EXPERT_UPDATE':
        return AppTheme.primary;
      case 'LAB_RESULT':
        return Colors.purpleAccent;
      default:
        return AppTheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: TranslatedText(
          'Alerts & Notifications',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear All Notifications',
            onPressed: () async {
              try {
                await notificationService.deleteAllNotifications();
                _fetchNotifications();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: TranslatedText('Error: $e')));
                }
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<NotificationModel>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: TranslatedText('Error loading notifications.', style: TextStyle(color: Colors.red)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const TranslatedText('No new notifications.', style: TextStyle(color: AppTheme.onSurfaceVariant)),
                ],
              ),
            );
          }

          final notifications = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              _fetchNotifications();
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final bool isUnread = !notification.isRead;

                return Dismissible(
                  key: Key('notif_${notification.id}'),
                  direction: DismissDirection.horizontal,
                  background: Container(
                    color: Colors.redAccent,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  secondaryBackground: Container(
                    color: Colors.redAccent,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    // Fire-and-forget deletion so UI is instantly updated
                    notificationService.deleteNotification(notification.id).catchError((e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: TranslatedText('Failed to delete: $e')));
                        _fetchNotifications(); // Refresh to restore the notification if it failed
                      }
                    });
                  },
                  child: Material(
                    color: isUnread ? AppTheme.primary.withValues(alpha: 0.05) : Colors.transparent,
                    child: InkWell(
                    onTap: () => _handleNotificationTap(notification),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _getColorForType(notification.type).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getIconForType(notification.type),
                              color: _getColorForType(notification.type),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: TranslatedText(
                                        notification.title,
                                        style: GoogleFonts.inter(
                                          fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                          fontSize: 16,
                                          color: isUnread ? AppTheme.onSurface : AppTheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    if (isUnread)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin: const EdgeInsets.only(left: 8),
                                        decoration: const BoxDecoration(
                                          color: Colors.redAccent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                TranslatedText(
                                  notification.message,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: AppTheme.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TranslatedText(
                                  _formatDate(notification.createdAt),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ), // Closes Row
                    ), // Closes Padding
                  ), // Closes InkWell
                ), // Closes Material
                ); // Closes Dismissible
              },
            ),
          );
        },
      ),
    );
  }
}
