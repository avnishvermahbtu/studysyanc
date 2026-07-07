import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/tts_service.dart';

class CoachMessage {
  final String text;
  final bool isUser;
  final Uint8List? imageBytes;
  final DateTime timestamp;

  CoachMessage({
    required this.text,
    required this.isUser,
    this.imageBytes,
    required this.timestamp,
  });
}

class AICoachMessageCard extends StatelessWidget {
  final CoachMessage message;
  const AICoachMessageCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Align(
        alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: message.isUser
                ? const Color(0xff6366f1).withOpacity(0.15)
                : Colors.white.withOpacity(0.04),
            border: Border.all(
              color: message.isUser
                  ? const Color(0xff6366f1).withOpacity(0.3)
                  : Colors.white10,
              width: 1,
            ),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(message.isUser ? 20 : 4),
              bottomRight: Radius.circular(message.isUser ? 4 : 20),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image Attachment Preview (if any)
                  if (message.imageBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: Image.memory(
                          message.imageBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // Message Text
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Bottom Metadata Row (Speaker icon for AI, Copy button, timestamp)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: const TextStyle(
                          color: Colors.white30,
                          fontSize: 9,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.white30),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: message.text));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Copied to clipboard"),
                                  duration: Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                          if (!message.isUser) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                TTSService().isSpeakingText(message.text)
                                    ? Icons.volume_off_rounded
                                    : Icons.volume_up_rounded,
                                size: 14,
                                color: TTSService().isSpeakingText(message.text)
                                    ? const Color(0xff10b981)
                                    : Colors.white30,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                TTSService().toggleSpeak(message.text);
                              },
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }
}
