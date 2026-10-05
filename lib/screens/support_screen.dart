import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();

  bool _isSending = false;

  static const String supportEmail = 'Taha_email@example.com';
  static const String adeelEmail = 'Adeel_email@example.com';

  static const String tahaNumber = '+92 XXX XXXXXXX';
  static const String adeelNumber = '+92 XXX XXXXXXX';

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  // RFC-compliant encoding for mailto queries (replaces spaces with %20 instead of +)
  String _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  Future<void> _sendSupportRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final message = _messageController.text.trim();

    setState(() {
      _isSending = true;
    });

    try {
      // 1. Save to Firestore with a 5-second timeout to prevent UI freezes
      try {
        await FirebaseFirestore.instance.collection('support_ticket').add({
          'message': message,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'new',
          'source': 'student_app',
        }).timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint(
            'Firestore write warning/timeout (continuing with email): $e');
      }

      // 2. Build mailto URI: primary to Taha, CC to Adeel
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: supportEmail,
        query: _encodeQueryParameters(<String, String>{
          'cc': adeelEmail,
          'subject': 'Support Request - Student App',
          'body': message,
        }),
      );

      // 3. Check if email app is available
      final canLaunch = await canLaunchUrl(emailUri);

      if (canLaunch) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);

        if (mounted) {
          _messageController.clear();
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Email Client Opened'),
              content: const Text(
                'Your ticket has been logged. Please press "Send" in your opened email app to complete sending the message.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        // Fallback if running on an emulator or device with no email app configured
        if (!mounted) return;
        _showNoEmailAppDialog(message);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open email app: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _showNoEmailAppDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('No Email App Found'),
        content: const Text(
          'Your support ticket has been recorded in the database, but this device does not have an active email app configured.\n\n'
          'Would you like to copy your message to your clipboard to send manually?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Message copied to clipboard!')),
              );
            },
            child: const Text('Copy Message'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF6C3CF7);
    const textDark = Color(0xFF1E1348);
    const textMuted = Color(0xFF64748B);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Technical Support'),
        backgroundColor: Colors.white,
        foregroundColor: textDark,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: textDark,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: -45,
            right: -55,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE9D5FF).withValues(alpha: 0.5),
              ),
            ),
          ),
          Positioned(
            top: 250,
            left: -80,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFBAE6FD).withValues(alpha: 0.35),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF8B5CF6),
                                Color(0xFF6C3CF7),
                                Color(0xFF4F46E5),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: primary.withValues(alpha: 0.2),
                                blurRadius: 16,
                                offset: const Offset(0, 7),
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              CircleAvatar(
                                radius: 27,
                                backgroundColor: Colors.white24,
                                child: Icon(
                                  Icons.support_agent_rounded,
                                  size: 30,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'How can we help?',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 21,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Tell us what’s going on and our team will point you in the right direction.',
                                      style: TextStyle(
                                        color: Colors.white,
                                        height: 1.4,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Send us a message',
                          style: TextStyle(
                            color: textDark,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFDDD6FE),
                              width: 1.2,
                            ),
                          ),
                          child: TextFormField(
                            controller: _messageController,
                            minLines: 6,
                            maxLines: 10,
                            textInputAction: TextInputAction.newline,
                            decoration: InputDecoration(
                              labelText: 'Your message',
                              hintText:
                                  'Describe the issue and what you were trying to do...',
                              alignLabelWithHint: true,
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(bottom: 94),
                                child: Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: primary,
                                  size: 20,
                                ),
                              ),
                              labelStyle: const TextStyle(color: primary),
                              hintStyle: const TextStyle(
                                color: textMuted,
                                fontSize: 13,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.all(16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: primary,
                                  width: 1.6,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your message.';
                              }
                              if (value.trim().length < 5) {
                                return 'Please provide a little more detail.';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF5B32E8)],
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: primary.withValues(alpha: 0.22),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _isSending ? null : _sendSupportRequest,
                            icon: _isSending
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                            label: Text(
                              _isSending
                                  ? 'Opening Email...'
                                  : 'Send Support Request',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.transparent,
                              disabledForegroundColor: Colors.white70,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        const Row(
                          children: [
                            Icon(
                              Icons.contact_support_rounded,
                              color: Color(0xFF059669),
                              size: 21,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Contact / InfoDesk',
                              style: TextStyle(
                                color: textDark,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _contactCard(
                          name: 'Taha',
                          number: tahaNumber,
                          color: const Color(0xFF7E22CE),
                          background: const Color(0xFFF3E8FF),
                        ),
                        const SizedBox(height: 10),
                        _contactCard(
                          name: 'Adeel',
                          number: adeelNumber,
                          color: const Color(0xFF0284C7),
                          background: const Color(0xFFE0F2FE),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactCard({
    required String name,
    required String number,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: background, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: background,
            foregroundColor: color,
            child: const Icon(Icons.phone_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFF1E1348),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  number,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 15, color: color),
        ],
      ),
    );
  }
}
