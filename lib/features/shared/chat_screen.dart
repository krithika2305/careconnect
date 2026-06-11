import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/theme.dart';
import '../../services/providers.dart';
import '../../services/alzheimers_model_service.dart';
import 'prediction_result_screen.dart';
import 'mri_result_card.dart';
import '../../services/notification_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String patientId;
  final String patientName;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    required this.patientId,
    required this.patientName,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
  final message = _messageController.text.trim();
  if (message.isEmpty) return;

  setState(() => _sending = true);
  try {
    final client = ref.read(supabaseClientProvider);
    final session = client.auth.currentSession;
    if (session == null) return;

    // Get the current user's own name (the sender)
    final myProfile = await ref.read(userProfileProvider.future);
    final myName = myProfile?['name'] as String? ?? 'Someone';

    // Insert message into database
    await client.from('chat_messages').insert({
      'sender_id': session.user.id,
      'receiver_id': widget.otherUserId,
      'patient_id': widget.patientId,
      'message': message,
    });

    // 🔔 Notify the RECEIVER only — using sender's (my) name
    await NotificationService.send(
      userId: widget.otherUserId,   // ✅ receiver's user_id
      title: 'New Message',
      body: 'From $myName: ${message.length > 50 ? '${message.substring(0, 50)}...' : message}',
      type: 'message',
      data: {
        'patient_id': widget.patientId,
        'sender_id': session.user.id,
      },
    );
    _messageController.clear();
    
    // Invalidate to refresh messages
    final key = ChatConversationKey(
      userId: session.user.id,
      otherUserId: widget.otherUserId,
      patientId: widget.patientId,
    );
    ref.invalidate(chatMessagesProvider(key));
    
    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: MedicalTheme.accentCoral,
        ),
      );
    }
  } finally {
    if (mounted) setState(() => _sending = false);
  }
}

  Future<void> _markAsRead(String messageId) async {
    try {
      final client = ref.read(supabaseClientProvider);
      await client
          .from('chat_messages')
          .update({'is_read': true})
          .eq('id', messageId);
    } catch (e) {
      debugPrint('Failed to mark as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    if (session == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final profileAsync = ref.watch(userProfileProvider);
    final isDoctor = profileAsync.valueOrNull?['role']?.toString().toLowerCase() == 'doctor';

    final conversationKey = ChatConversationKey(
      userId: session.user.id,
      otherUserId: widget.otherUserId,
      patientId: widget.patientId,
    );

    final messagesAsync = ref.watch(chatMessagesProvider(conversationKey));

    return Theme(
      data: CareTheme.lightTheme,
      child: Scaffold(
        backgroundColor: CareTheme.background,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.otherUserName,
                style: CareTheme.displaySerif.copyWith(fontSize: 18),
              ),
              Text(
                'Patient: ${widget.patientName}',
                style: CareTheme.bodySans.copyWith(
                  fontSize: 12,
                  color: CareTheme.textMuted,
                ),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: CareTheme.accentPink),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e', style: CareTheme.bodySans),
                ),
                data: (messages) {
                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: CareTheme.textMuted.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: CareTheme.bodySans.copyWith(
                              color: CareTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start the conversation',
                            style: CareTheme.bodySans.copyWith(
                              fontSize: 13,
                              color: CareTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Mark received messages as read
                  for (final msg in messages) {
                    if (msg['receiver_id'] == session.user.id && 
                        msg['is_read'] == false) {
                      _markAsRead(msg['id'].toString());
                    }
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg['sender_id'] == session.user.id;
                      final isRead = msg['is_read'] as bool? ?? false;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Builder(
                          builder: (context) {
                            if (msg['metadata'] != null) {
                              try {
                                final metadata = jsonDecode(msg['metadata'].toString());
                                if (metadata['type'] == 'mri_result') {
                                  final allClasses = Map<String, dynamic>.from(metadata['all_classes'] ?? {})
                                      .map((k, v) => MapEntry(k, (v as num).toDouble()));
                                  final analyzedAt = DateTime.tryParse(msg['created_at']?.toString() ?? '') ?? DateTime.now();
                                  return Row(
                                    mainAxisAlignment: isMe
                                        ? MainAxisAlignment.end
                                        : MainAxisAlignment.start,
                                    children: [
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                                        ),
                                        child: MriResultCard(
                                          prediction: metadata['prediction']?.toString() ?? 'Unknown',
                                          confidence: (metadata['confidence'] as num?)?.toDouble() ?? 0.0,
                                          allClasses: allClasses,
                                          analyzedAt: analyzedAt,
                                        ),
                                      ),
                                    ],
                                  );
                                }
                              } catch (e) {
                                debugPrint('Error parsing mri_result metadata: $e');
                              }
                            }

                            return Row(
                              mainAxisAlignment: isMe
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                              children: [
                                Container(
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? MedicalTheme.primaryTeal
                                        : CareTheme.surface,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        msg['message']?.toString() ?? '',
                                        style: CareTheme.bodySans.copyWith(
                                          color: isMe ? Colors.white : MedicalTheme.darkSlate,
                                        ),
                                      ),
                                      if (msg['metadata'] != null) ...[
                                        _buildMriAttachment(msg['metadata']?.toString(), isMe, isDoctor),
                                        _buildMriResultAttachment(msg['metadata']?.toString(), isMe),
                                      ],
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _formatTime(msg['created_at']?.toString()),
                                            style: CareTheme.bodySans.copyWith(
                                              fontSize: 10,
                                              color: isMe
                                                  ? Colors.white.withValues(alpha: 0.7)
                                                  : CareTheme.textMuted,
                                            ),
                                          ),
                                          if (isMe) ...[
                                            const SizedBox(width: 4),
                                            Icon(
                                              isRead ? Icons.done_all : Icons.done,
                                              size: 12,
                                              color: isRead
                                                  ? Colors.white.withValues(alpha: 0.7)
                                                  : Colors.white.withValues(alpha: 0.4),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CareTheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: CareTheme.bodySans.copyWith(
                          color: CareTheme.textMuted,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: CareTheme.background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _sending ? null : _sendMessage,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: MedicalTheme.primaryTeal,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: MedicalTheme.primaryTeal,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final date = DateTime.tryParse(iso);
  if (date == null) return '';

  final local = date.toLocal();
  final now = DateTime.now();

  final isToday = local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;

  if (isToday) {
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
  return '${local.day}/${local.month}/${local.year}';
}

  Widget _buildMriAttachment(String? metadataJson, bool isMe, bool isDoctor) {
    if (metadataJson == null) return const SizedBox.shrink();
    try {
      final metadata = jsonDecode(metadataJson);
      if (metadata['type'] != 'mri_request') return const SizedBox.shrink();
      final imageUrl = metadata['image_url'];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(imageUrl, height: 150, width: double.infinity, fit: BoxFit.cover),
          ),
          if (isDoctor) ...[
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _analyzeMri(imageUrl),
              style: ElevatedButton.styleFrom(
                backgroundColor: MedicalTheme.primaryTeal,
              ),
              child: const Text('Analyze MRI'),
            ),
          ],
        ],
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildMriResultAttachment(String? metadataJson, bool isMe) {
    if (metadataJson == null) return const SizedBox.shrink();
    try {
      final metadata = jsonDecode(metadataJson);
      if (metadata['type'] != 'mri_result') return const SizedBox.shrink();
      final pred = metadata['prediction']?.toString() ?? 'Unknown';
      final conf = (metadata['confidence'] as num?)?.toDouble() ?? 0.0;
      final stageColor = _getColorForPrediction(pred);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: stageColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: stageColor.withOpacity(0.4), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.psychology_outlined, color: stageColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  '$pred (${conf.toStringAsFixed(1)}%)',
                  style: TextStyle(
                    color: stageColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Color _getColorForPrediction(String prediction) {
    final lower = prediction.toLowerCase();
    if (lower.contains('non') || lower.contains('normal')) {
      return MedicalTheme.accentGreen;
    } else if (lower.contains('very mild') || lower.contains('mild')) {
      return MedicalTheme.accentOrange;
    } else {
      return MedicalTheme.accentCoral;
    }
  }

  String _formatProbabilitySummary(Map<String, double> allClasses) {
    final sorted = allClasses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topTwo = sorted.take(2).map((e) => '- ${e.key}: ${e.value.toStringAsFixed(1)}%').join('\n');
    return '\n**Top classes:**\n$topTwo';
  }

  Future<void> _analyzeMri(String imageUrl) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Downloading and analyzing MRI...')));
    try {
      // 1. Download image
      final response = await http.get(Uri.parse(imageUrl));
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/temp_mri_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(response.bodyBytes);

      // 2. Run prediction model
      final modelService = AlzheimersModelService();
      final result = await modelService.predict(file.path);
      if (result == null) throw Exception('AI model analysis failed.');

      // 3. Log to Supabase database (mri_predictions)
      final client = ref.read(supabaseClientProvider);
      final session = ref.read(authSessionProvider);
      if (session != null) {
        await client.from('mri_predictions').insert({
          'doctor_id': session.user.id,
          'patient_id': widget.patientId,
          'image_url': imageUrl,
          'prediction': result.label,
          'confidence': result.confidence,
        });
        
        // Refresh local history
        ref.invalidate(mriHistoryProvider);
        ref.invalidate(patientMriHistoryProvider(widget.patientId));

        // 4. Ask caregiver report confirmation dialog
        if (mounted) {
          final shouldSend = await showDialog<bool>(
            context: context,
            builder: (dialogCtx) => AlertDialog(
              backgroundColor: CareTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Send result to caregiver?'),
              content: Text(
                'Prediction: ${result.label}\n'
                'Confidence: ${result.confidence.toStringAsFixed(1)}%\n\n'
                'Would you like to send this diagnosis report back to the caregiver in this chat?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: Text('No', style: TextStyle(color: CareTheme.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MedicalTheme.primaryTeal,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Yes, Send'),
                ),
              ],
            ),
          ) ?? false;

          if (shouldSend) {
            final caregiverId = widget.otherUserId;
            final doctorId = session.user.id;

            await client.from('chat_messages').insert({
              'sender_id': doctorId,
              'receiver_id': caregiverId,
              'patient_id': widget.patientId,
              'message': '',
              'metadata': jsonEncode({
                'type': 'mri_result',
                'prediction': result.label,
                'confidence': result.confidence,
                'all_classes': result.allClasses,
              }),
              'is_read': false,
            });

            // Invalidate to refresh messages in the chat UI
            final conversationKey = ChatConversationKey(
              userId: doctorId,
              otherUserId: caregiverId,
              patientId: widget.patientId,
            );
            ref.invalidate(chatMessagesProvider(conversationKey));
            // 🔔 Notify the caregiver that MRI result is available
            await NotificationService.send(
              userId: widget.otherUserId,
              title: '🧠 MRI Analysis Result',
              body: '${result.label} (${result.confidence.toStringAsFixed(1)}%) - Tap to view.',
              type: 'mri_result',
              data: {
                'prediction': result.label,
                'confidence': result.confidence,
                'patient_id': widget.patientId,
              },
            );
          }
        }
      }

      // 5. Open results screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PredictionResultScreen(
              imagePath: file.path,
              prediction: result.label,
              confidence: result.confidence,
            ),
          ),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
