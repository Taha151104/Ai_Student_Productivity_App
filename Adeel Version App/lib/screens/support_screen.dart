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
    const primary = Color(0xFF6546F5);
    const textDark = Color(0xFF29233F);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FF),
      appBar: AppBar(
        title: const Text('Technical Support'),
        backgroundColor: Colors.transparent,
        foregroundColor: textDark,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.support_agent_rounded,
                          size: 42, color: primary),
                      SizedBox(height: 12),
                      Text(
                        'How can we help?',
                        style: TextStyle(
                          color: textDark,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Describe your issue. Your message will be logged to our database and drafted in your email app.',
                        style: TextStyle(color: Colors.black54, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _messageController,
                  minLines: 6,
                  maxLines: 10,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    labelText: 'Your message',
                    hintText: 'Explain your issue here...',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
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
                const SizedBox(height: 16),
                ElevatedButton.icon(
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
                      : const Icon(Icons.email_outlined),
                  label: Text(
                    _isSending ? 'Opening Email...' : 'Send Support Request',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Contact / InfoDesk',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _contactCard(name: 'Taha', number: tahaNumber),
                const SizedBox(height: 10),
                _contactCard(name: 'Adeel', number: adeelNumber),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _contactCard({required String name, required String number}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFEDE9FE),
            foregroundColor: Color(0xFF6546F5),
            child: Icon(Icons.phone_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(number, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
