import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme.dart';
import '../api_client.dart';
import '../widgets/translated_text.dart';

class ChatScreen extends StatefulWidget {
  final String? initialQuery;
  const ChatScreen({super.key, this.initialQuery});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  // Each message: {sender: 'user'|'ai', text: '...', sources: [...], time: '...'}
  final List<Map<String, dynamic>> _messages = [
    {
      'sender': 'ai',
      'text': 'Hello! I\'m your AI Agronomist. I can answer questions about crop diseases, pest control, irrigation, fertilizers, and more.\n\nI remember our conversation context, so feel free to ask follow-up questions!',
      'sources': <String>[],
      'time': _nowTime(),
    }
  ];

  bool _isLoading = false;
  String _selectedLanguage = 'auto';
  late AnimationController _dotController;

  final List<Map<String, String>> _languages = [
    {'code': 'auto', 'label': 'Auto-detect'},
    {'code': 'English', 'label': 'English'},
    {'code': 'Hindi', 'label': 'हिंदी'},
    {'code': 'Bengali', 'label': 'বাংলা'},
    {'code': 'Marathi', 'label': 'मराठी'},
    {'code': 'Telugu', 'label': 'తెలుగు'},
    {'code': 'Tamil', 'label': 'தமிழ்'},
  ];

  final List<String> _suggestedQuestions = [
    'How to treat tomato blight?',
    'Best fertilizer for wheat?',
    'Irrigate in hot weather?',
    'Identify aphid symptoms',
    'Organic pest control methods?',
    'Prevent powdery mildew?',
  ];

  static String _nowTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage(widget.initialQuery!);
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _dotController.dispose();
    super.dispose();
  }

  /// Build conversation history to send to the backend (excludes first greeting)
  List<Map<String, String>> _buildHistory() {
    final history = <Map<String, String>>[];
    for (final msg in _messages.skip(1)) {
      history.add({
        'role': msg['sender'] == 'user' ? 'user' : 'model',
        'content': msg['text'] as String,
      });
    }
    return history;
  }

  Future<void> _sendMessage([String? customText]) async {
    final query = customText ?? _messageController.text.trim();
    if (query.isEmpty || _isLoading) return;

    if (customText == null) _messageController.clear();
    _inputFocusNode.unfocus();

    setState(() {
      _messages.add({'sender': 'user', 'text': query, 'sources': <String>[], 'time': _nowTime()});
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final history = _buildHistory()
          .take(_buildHistory().length - 1) // don't include the message we just added
          .toList();

      final response = await apiClient.post(
        '/chat/ask',
        data: {
          'query': query,
          'history': history,
          if (_selectedLanguage != 'auto') 'language': _selectedLanguage,
        },
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _messages.add({
            'sender': 'ai',
            'text': response.data['answer'] ?? 'No response received.',
            'sources': (response.data['context_used'] as List?)?.cast<String>() ?? <String>[],
            'time': _nowTime(),
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'sender': 'ai',
            'text': 'I encountered an issue contacting the advisory service. Please check your connection and try again.',
            'sources': <String>[],
            'time': _nowTime(),
          });
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _messages.add({
        'sender': 'ai',
        'text': 'Chat cleared. How can I help you with your crops today?',
        'sources': <String>[],
        'time': _nowTime(),
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          if (_isLoading) _buildTypingIndicator(),
          if (_messages.length <= 2) _buildSuggestedChips(),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.onSurface),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary.withValues(alpha: 0.2), AppTheme.secondary.withValues(alpha: 0.2)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_rounded, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TranslatedText('AI Agronomist',
                    style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.onSurface),
                    overflow: TextOverflow.ellipsis),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6, height: 6,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                    ),
                    Flexible(
                      child: TranslatedText('RAG-powered',
                          style: GoogleFonts.inter(fontSize: 10, color: AppTheme.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Language picker
        PopupMenuButton<String>(
          tooltip: 'Response language',
          icon: Icon(Icons.translate_rounded,
              color: _selectedLanguage != 'auto' ? AppTheme.primary : AppTheme.onSurfaceVariant),
          onSelected: (val) => setState(() => _selectedLanguage = val),
          itemBuilder: (_) => _languages.map((lang) => PopupMenuItem<String>(
            value: lang['code'],
            child: Row(
              children: [
                if (_selectedLanguage == lang['code'])
                  const Icon(Icons.check, size: 16, color: AppTheme.primary)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                TranslatedText(lang['label']!,
                    style: GoogleFonts.inter(
                        fontWeight: _selectedLanguage == lang['code'] ? FontWeight.bold : FontWeight.normal)),
              ],
            ),
          )).toList(),
        ),
        IconButton(
          tooltip: 'Clear chat',
          icon: const Icon(Icons.restart_alt_rounded, color: AppTheme.onSurfaceVariant),
          onPressed: _clearChat,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isUser = msg['sender'] == 'user';
        return _buildMessageBubble(msg, isUser);
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isUser) {
    final sources = (msg['sources'] as List<String>?) ?? [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32, height: 32,
              margin: const EdgeInsets.only(right: 8, bottom: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppTheme.primary.withValues(alpha: 0.2), AppTheme.secondary.withValues(alpha: 0.15)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded, color: AppTheme.primary, size: 16),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Bubble
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? AppTheme.primary : AppTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(20).copyWith(
                      bottomRight: isUser ? const Radius.circular(4) : null,
                      bottomLeft: !isUser ? const Radius.circular(4) : null,
                    ),
                    border: isUser ? null : Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: isUser
                      ? SelectableText(
                          msg['text'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            height: 1.55,
                            color: Colors.white,
                          ),
                        )
                      : MarkdownBody(
                          data: msg['text'] as String,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: GoogleFonts.inter(fontSize: 14, height: 1.55, color: AppTheme.onSurface),
                            strong: GoogleFonts.inter(fontSize: 14, height: 1.55, color: AppTheme.onSurface, fontWeight: FontWeight.bold),
                            em: GoogleFonts.inter(fontSize: 14, height: 1.55, color: AppTheme.onSurface, fontStyle: FontStyle.italic),
                            listBullet: GoogleFonts.inter(fontSize: 14, height: 1.55, color: AppTheme.onSurface),
                            h1: GoogleFonts.manrope(fontSize: 20, color: AppTheme.onSurface, fontWeight: FontWeight.bold),
                            h2: GoogleFonts.manrope(fontSize: 18, color: AppTheme.onSurface, fontWeight: FontWeight.bold),
                            h3: GoogleFonts.manrope(fontSize: 16, color: AppTheme.onSurface, fontWeight: FontWeight.bold),
                          ),
                        ),
                ),

                const SizedBox(height: 4),

                // Timestamp + copy button row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isUser)
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: msg['text'] as String));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: TranslatedText('Copied to clipboard'), duration: Duration(seconds: 1)),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(Icons.copy_rounded, size: 12, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6)),
                        ),
                      ),
                    TranslatedText(
                      msg['time'] as String? ?? '',
                      style: GoogleFonts.inter(fontSize: 10, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5)),
                    ),
                  ],
                ),

                // Source chips
                if (!isUser && sources.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: sources.map((s) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.book_rounded, size: 10, color: AppTheme.secondary.withValues(alpha: 0.8)),
                          const SizedBox(width: 4),
                          TranslatedText(s,
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: AppTheme.onSurface.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
          if (isUser) ...[
            Container(
              width: 32, height: 32,
              margin: const EdgeInsets.only(left: 8, bottom: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded, color: AppTheme.primary, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.primary.withValues(alpha: 0.2), AppTheme.secondary.withValues(alpha: 0.15)]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_rounded, color: AppTheme.primary, size: 16),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20).copyWith(bottomLeft: const Radius.circular(4)),
              border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: AnimatedBuilder(
              animation: _dotController,
              builder: (_, __) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final delay = i / 3;
                    final opacity = (((_dotController.value - delay) % 1.0 + 1.0) % 1.0 < 0.5) ? 1.0 : 0.3;
                    return Container(
                      width: 7, height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: opacity),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedChips() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _suggestedQuestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => ActionChip(
          label: TranslatedText(_suggestedQuestions[i],
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w500)),
          backgroundColor: AppTheme.surfaceContainerLowest,
          side: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onPressed: () => _sendMessage(_suggestedQuestions[i]),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : 24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.25))),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _messageController,
                focusNode: _inputFocusNode,
                maxLines: 5,
                minLines: 1,
                style: GoogleFonts.inter(color: AppTheme.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ask about crops, diseases, pests...',
                  hintStyle: GoogleFonts.inter(color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _isLoading ? AppTheme.primary.withValues(alpha: 0.4) : AppTheme.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(_isLoading ? Icons.hourglass_top_rounded : Icons.send_rounded,
                  color: Colors.white, size: 18),
              onPressed: _isLoading ? null : () => _sendMessage(),
            ),
          ),
        ],
      ),
    );
  }
}
