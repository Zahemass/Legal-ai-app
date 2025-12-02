import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:arm_app/services/api_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Premium AI Agent Chat screen with sophisticated dark theme
class AiAgentScreen extends StatefulWidget {
  final String caseId;
  const AiAgentScreen({super. key, required this.caseId});

  @override
  State<AiAgentScreen> createState() => _AiAgentScreenState();
}

class _AiAgentScreenState extends State<AiAgentScreen>
    with TickerProviderStateMixin {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;
  bool isSending = false;
  bool showTypingIndicator = false;
  User? user;

  late final AnimationController _fadeController;
  late final AnimationController _headerController;
  late Animation<double> _headerFadeAnimation;

  String get _cacheKey => 'ai_chat_${widget.caseId}';

  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color cardDark = Color(0xFF334155);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color userGradientStart = Color(0xFF3B82F6);
  static const Color userGradientEnd = Color(0xFF2563EB);
  static const Color aiBubbleColor = Color(0xFF1E293B);
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color borderColor = Color(0xFF475569);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _headerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOut),
    );

    user = FirebaseAuth.instance.currentUser;

    _loadLocalHistory(). then((_) {
      loadChatHistory();
    });

    _headerController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _headerController.dispose();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
        final normalized = list.map<Map<String, dynamic>>((m) {
          return Map<String, dynamic>.from(m as Map);
        }).toList();
        setState(() {
          messages = normalized;
          isLoading = false;
        });
        scrollToBottom(delayMs: 150);
      }
    } catch (_) {
      // ignore cache errors silently
    }
  }

  Future<void> _saveLocalHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(messages));
    } catch (_) {
      // ignore
    }
  }

  Future<void> loadChatHistory() async {
    setState(() {
      isLoading = true;
    });

    try {
      final resp = await getAIChatHistory(widget.caseId);

      List<dynamic> history = [];

      if (resp is Map) {
        if (resp["data"] != null && resp["data"]["history"] != null) {
          history = resp["data"]["history"];
        } else if (resp["history"] != null) {
          history = resp["history"];
        } else {
          if (resp['messages'] != null) {
            history = resp['messages'];
          } else {
            if (resp['message'] != null || resp['reply'] != null) {
              final assistantText = resp['message'] ?? resp['reply'] ?? resp['data']?['message'];
              history = [
                {'role': 'assistant', 'message': assistantText}
              ];
            }
          }
        }
      } else if (resp is List) {
        history = resp;
      }

      final normalized = history.map<Map<String, dynamic>>((m) {
        if (m is Map) {
          final msgMap = Map<String, dynamic>.from(m);
          String role = (msgMap['role'] ??  '').toString().toLowerCase();
          String senderId = (msgMap['senderId'] ?? msgMap['userId'] ?? '').toString();

          // ✅ FIXED: Check if message is from current user
          if (senderId. isNotEmpty && user != null && senderId == user!.uid) {
            msgMap['role'] = 'user';
            msgMap['isCurrentUser'] = true;
          } else if (role == 'user' || role == 'client') {
            // Keep as user but mark it's not current user
            msgMap['isCurrentUser'] = false;
          } else {
            msgMap['role'] = 'assistant';
            msgMap['isCurrentUser'] = false;
          }

          return msgMap;
        }
        return {'role': 'assistant', 'message': m. toString(), 'isCurrentUser': false};
      }).toList();

      setState(() {
        messages = normalized;
        isLoading = false;
      });

      await _saveLocalHistory();
      scrollToBottom(delayMs: 200);
      _fadeController.forward();
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Failed to load chat: ${e.toString()}',
                      style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(12),
          ),
        );
      }
    }
  }

  void scrollToBottom({int delayMs = 300}) {
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (_scrollController.hasClients) {
        try {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves. easeOutCubic,
          );
        } catch (_) {
          // ignore if animation fails
        }
      }
    });
  }

  List<Map<String, dynamic>> _parseHistoryFromResponse(dynamic response) {
    List<dynamic> history = [];

    if (response == null) return [];

    if (response is Map) {
      if (response['data'] != null && response['data']['history'] != null) {
        history = response['data']['history'];
      } else if (response['history'] != null) {
        history = response['history'];
      } else if (response['messages'] != null) {
        history = response['messages'];
      } else if (response['message'] != null || response['reply'] != null) {
        final assistantText =
            response['message'] ?? response['reply'] ?? response['data']?['message'];
        history = [
          {'role': 'assistant', 'message': assistantText}
        ];
      } else {
        history = [
          {'role': response['role'] ?? 'assistant', 'message': response. toString()}
        ];
      }
    } else if (response is List) {
      history = response;
    } else {
      history = [
        {'role': 'assistant', 'message': response.toString()}
      ];
    }

    final normalized = history.map<Map<String, dynamic>>((m) {
      if (m is Map) {
        final msgMap = Map<String, dynamic>.from(m);
        String senderId = (msgMap['senderId'] ?? msgMap['userId'] ??  '').toString();

        // ✅ Mark if from current user
        if (senderId.isNotEmpty && user != null && senderId == user!.uid) {
          msgMap['role'] = 'user';
          msgMap['isCurrentUser'] = true;
        } else {
          msgMap['isCurrentUser'] = false;
        }

        return msgMap;
      }
      return {'role': 'assistant', 'message': m.toString(), 'isCurrentUser': false};
    }).toList();

    return normalized;
  }

  bool _looksLikeServerHistory(List<Map<String, dynamic>> parsed) {
    if (parsed. isEmpty) return false;

    final hasUserRole = parsed.any((m) =>
    (m['role'] ??  '').toString().toLowerCase() == 'user' ||
        (m['role'] ?? '').toString().toLowerCase() == 'client');

    if (hasUserRole) return true;
    if (parsed.length > (messages.length + 1)) return true;

    return false;
  }

  Future<void> sendMessage({String? text}) async {
    final msg = (text ?? _msgController.text). trim();
    if (msg. isEmpty || user == null) return;

    _msgController.clear();

    // ✅ FIXED: Mark user message explicitly
    final userMsg = {
      'role': 'user',
      'message': msg,
      'isCurrentUser': true,  // ✅ Critical flag
      'senderId': user!.uid,   // ✅ Store sender ID
      'localId': DateTime.now().millisecondsSinceEpoch.toString(),
      'createdAt': DateTime.now().toIso8601String(),
    };

    setState(() {
      messages = [... messages, userMsg];
      isSending = true;
      showTypingIndicator = true;
    });

    _saveLocalHistory();
    scrollToBottom(delayMs: 100);

    try {
      final response = await sendAIMessage(widget.caseId, user!.uid, msg);
      final parsed = _parseHistoryFromResponse(response);

      setState(() {
        if (parsed.isNotEmpty) {
          final looksLikeFull = _looksLikeServerHistory(parsed);

          if (looksLikeFull) {
            // ✅ Preserve user message flags when server returns full history
            final updatedMessages = parsed.map((m) {
              String senderId = (m['senderId'] ?? m['userId'] ?? '').toString();
              if (senderId.isNotEmpty && user != null && senderId == user!. uid) {
                m['isCurrentUser'] = true;
                m['role'] = 'user';
              }
              return m;
            }). toList();
            messages = updatedMessages;
          } else {
            final assistantOnly = parsed.where((m) {
              final role = (m['role'] ??  'assistant').toString().toLowerCase();
              return role == 'assistant' || role == 'system' || role == '';
            }).toList();

            if (assistantOnly.isNotEmpty) {
              String?  lastAssistant;
              for (var i = messages.length - 1; i >= 0; i--) {
                final m = messages[i];
                final role = (m['role'] ??  '').toString().toLowerCase();
                if (role == 'assistant' || role == 'system') {
                  lastAssistant = (m['message'] ?? m['content'])?.toString();
                  break;
                }
              }

              for (final a in assistantOnly) {
                final text = (a['message'] ?? a['content'] ?? '').toString();
                if (text.isEmpty) continue;
                if (text == lastAssistant) continue;

                messages.add({
                  'role': 'assistant',
                  'message': text,
                  'isCurrentUser': false,  // ✅ AI message
                  'createdAt': a['createdAt'] ?? DateTime.now().toIso8601String(),
                });
                lastAssistant = text;
              }
            } else {
              messages.add({
                'role': 'assistant',
                'message': parsed.map((e) => e.toString()).join('\n'),
                'isCurrentUser': false,
                'createdAt': DateTime. now().toIso8601String(),
              });
            }
          }
        } else {
          messages = [
            ... messages,
            {
              'role': 'assistant',
              'message': 'No response from AI.',
              'isCurrentUser': false,
            }
          ];
        }
      });

      await _saveLocalHistory();
    } catch (e) {
      setState(() {
        messages = [
          ...messages,
          {
            'role': 'assistant',
            'message': 'Failed to reach AI: $e',
            'isCurrentUser': false,
          }
        ];
      });

      await _saveLocalHistory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI failed: $e', style: const TextStyle(fontSize: 12)),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(12),
          ),
        );
      }
    } finally {
      setState(() {
        isSending = false;
        showTypingIndicator = false;
      });
      scrollToBottom(delayMs: 150);

      // ✅ Refresh to sync with server (but preserve local state)
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          loadChatHistory();
        }
      });
    }
  }

  Widget _messageBubble(Map<String, dynamic> msg, int index) {
    final role = (msg['role'] ?? 'assistant').toString().toLowerCase();
    final content = (msg['message'] ?? msg['content'] ?? '').toString();

    // ✅ FIXED: Determine if message is from current user
    final bool isUser = msg['isCurrentUser'] == true ||
        (msg['senderId'] != null &&
            user != null &&
            msg['senderId'] == user!. uid);

    final media = MediaQuery.of(context);
    final maxWidth = media.size.width * 0.75;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform. translate(
          offset: Offset(0, 15 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: isUser ? _userBubble(content, maxWidth) : _aiBubble(content, maxWidth),
    );
  }

  Widget _userBubble(String content, double maxWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [userGradientStart, userGradientEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(6),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentBlue.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SelectableText(
                  content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [accentBlue, Color(0xFF2563EB)],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: accentBlue. withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentBlue.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _aiBubble(String content, double maxWidth) {
    return Padding(
      padding: const EdgeInsets. symmetric(vertical: 6, horizontal: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [accentPurple, Color(0xFF7C3AED)],
              ),
              shape: BoxShape. circle,
              border: Border. all(
                color: accentPurple.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentPurple. withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth, minWidth: 48),
              child: Container(
                padding: const EdgeInsets. symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: aiBubbleColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  border: Border.all(
                    color: borderColor. withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SelectableText(
                  content,
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    height: 1.5,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [accentPurple, Color(0xFF7C3AED)],
              ),
              shape: BoxShape. circle,
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: aiBubbleColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor. withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                DotBubble(),
                SizedBox(width: 12),
                Text(
                  'AI is typing...',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return FadeTransition(
      opacity: _headerFadeAnimation,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [surfaceDark, backgroundDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border(
            bottom: BorderSide(
              color: borderColor.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors. white. withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: textPrimary,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [accentPurple, Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Legal Assistant',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Online',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => loadChatHistory(),
              icon: const Icon(Icons.refresh_rounded, color: textSecondary, size: 20),
              tooltip: 'Reload conversation',
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActionChips() {
    final chips = [
      {
        'label': 'Summarize',
        'icon': Icons.article_outlined,
        'prompt': 'Please summarize the evidence in this case in simple points.'
      },
      {
        'label': 'Legal Analysis',
        'icon': Icons.balance,
        'prompt': 'Provide a high level legal analysis of this case.'
      },
      {
        'label': 'Draft Brief',
        'icon': Icons. description_outlined,
        'prompt': 'Draft a short legal brief based on available case data.'
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: surfaceDark. withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: borderColor.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips.map((c) {
            return Padding(
              padding: const EdgeInsets.only(right:8.0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isSending ? null : () => sendMessage(text: c['prompt'] as String),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: borderColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          c['icon'] as IconData,
                          color: textSecondary,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          c['label'] as String,
                          style: const TextStyle(
                            color: textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _messageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 12, bottom: 20),
      itemCount: messages.length + (showTypingIndicator ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < messages.length) {
          return _messageBubble(messages[index], index);
        } else {
          return _typingIndicator();
        }
      },
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [accentPurple, Color(0xFF7C3AED)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accentPurple. withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.smart_toy_rounded, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask anything about your case or use\nquick actions below to get started',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      decoration: BoxDecoration(
        color: surfaceDark,
        border: Border(
          top: BorderSide(
            color: borderColor.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundDark,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: borderColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _msgController,
                  textInputAction: TextInputAction.newline,
                  minLines: 1,
                  maxLines: 5,
                  style: const TextStyle(color: textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Ask anything about your case...",
                    hintStyle: TextStyle(
                      color: textSecondary.withOpacity(0.6),
                      fontSize: 13,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: isSending ? null : sendMessage,
              child: Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [accentBlue, Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment. bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accentBlue.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: isSending
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            _quickActionChips(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: backgroundDark,
                ),
                child: isLoading
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surfaceDark,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(accentBlue),
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Loading conversation...',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
                    : messages.isEmpty
                    ? _emptyState()
                    : _messageList(),
              ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }
}

/// Animated three-dot typing indicator
class DotBubble extends StatefulWidget {
  const DotBubble({super. key});

  @override
  State<DotBubble> createState() => _DotBubbleState();
}

class _DotBubbleState extends State<DotBubble> with TickerProviderStateMixin {
  late final AnimationController _c1;
  late final AnimationController _c2;
  late final AnimationController _c3;

  @override
  void initState() {
    super.initState();
    _c1 = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _c2 = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _c3 = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    _c1.repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 150), () => _c2.repeat(reverse: true));
    Future.delayed(const Duration(milliseconds: 300), () => _c3.repeat(reverse: true));
  }

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    super.dispose();
  }

  Widget _dot(AnimationController c) {
    return ScaleTransition(
      scale: Tween(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 5,
        height: 5,
        decoration: const BoxDecoration(
          color: Color(0xFF94A3B8),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _dot(_c1),
        const SizedBox(width: 4),
        _dot(_c2),
        const SizedBox(width: 4),
        _dot(_c3),
      ],
    );
  }
}