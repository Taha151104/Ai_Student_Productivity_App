import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/routes.dart';
import '../core/theme.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _institutionController = TextEditingController();
  final _educationController = TextEditingController();
  final _bioController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _email;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _institutionController.dispose();
    _educationController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _email = user.email;
    _nameController.text = user.displayName ?? '';
    try {
      final snapshot = await _firestore.collection('users').doc(user.uid).get();
      final data = snapshot.data() ?? <String, dynamic>{};
      if (_nameController.text.trim().isEmpty) {
        _nameController.text =
            (data['fullName'] ?? data['username'] ?? data['name'] ?? '')
                .toString();
      }
      _institutionController.text = (data['institution'] ?? '').toString();
      _educationController.text = (data['education_level'] ?? '').toString();
      _bioController.text = (data['bio'] ?? '').toString();
    } catch (error) {
      debugPrint('Failed to load account profile: $error');
      if (mounted) {
        _showMessage('Could not load saved profile details: $error',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final user = _auth.currentUser;
    if (user == null) {
      _showMessage('Please log in again to update your profile.',
          isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final name = _nameController.text.trim();
      await user.updateDisplayName(name);
      await _firestore.collection('users').doc(user.uid).set({
        'name': name,
        'fullName': name,
        'username': name,
        'email': user.email,
        'institution': _institutionController.text.trim(),
        'education_level': _educationController.text.trim(),
        'bio': _bioController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) _showMessage('Profile updated successfully.');
    } catch (error) {
      if (mounted) {
        _showMessage('Could not save your profile: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
      }
    } catch (error) {
      if (mounted) _showMessage('Could not sign out: $error', isError: true);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently removes your sign-in account and profile. '
          'Study files and activity saved in other records are not automatically '
          'erased by this action.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep account'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    final profileRef = _firestore.collection('users').doc(user.uid);
    Map<String, dynamic>? previousProfile;
    var profileWasDeleted = false;
    try {
      final profile = await profileRef.get();
      previousProfile = profile.data();
      if (profile.exists) {
        await profileRef.delete();
        profileWasDeleted = true;
      }
      await user.delete();
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
      }
    } on FirebaseAuthException catch (error) {
      if (profileWasDeleted && previousProfile != null) {
        try {
          await profileRef.set(previousProfile);
        } catch (restoreError) {
          if (mounted) {
            _showMessage(
              'Account deletion needs a recent sign-in. Profile restoration '
              'also failed: $restoreError',
              isError: true,
            );
          }
        }
      }
      if (mounted && error.code == 'requires-recent-login') {
        _showMessage(
          'For security, sign out and sign back in before deleting your account.',
          isError: true,
        );
      } else if (mounted) {
        _showMessage('Could not delete your account: ${error.message}',
            isError: true);
      }
    } catch (error) {
      if (profileWasDeleted && previousProfile != null) {
        try {
          await profileRef.set(previousProfile);
        } catch (restoreError) {
          if (mounted) {
            _showMessage(
              'Account deletion failed, and profile restoration also failed: '
              '$restoreError',
              isError: true,
            );
          }
        }
      }
      if (mounted)
        _showMessage('Could not delete your account: $error', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : AppTheme.textDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _profileField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final name = _nameController.text.trim();
    final avatarLetter = name.isNotEmpty
        ? name[0].toUpperCase()
        : (_email?.isNotEmpty == true ? _email![0].toUpperCase() : '?');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account & Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.14),
                      child: Text(
                        avatarLetter,
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _email ?? 'Signed-in account',
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Personal information',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _profileField(
                          controller: _nameController,
                          label: 'Full name',
                          icon: Icons.person_outline_rounded,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Enter your name'
                                  : null,
                        ),
                        _profileField(
                          controller: _institutionController,
                          label: 'College / university',
                          icon: Icons.school_outlined,
                        ),
                        _profileField(
                          controller: _educationController,
                          label: 'Degree / education level',
                          icon: Icons.workspace_premium_outlined,
                        ),
                        _profileField(
                          controller: _bioController,
                          label: 'Study goal / bio',
                          icon: Icons.notes_rounded,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 4),
                        FilledButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save changes'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.logout_rounded),
                      title: const Text('Sign out'),
                      onTap: _signOut,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.delete_outline_rounded,
                          color: Colors.red),
                      title: const Text(
                        'Delete account',
                        style: TextStyle(color: Colors.red),
                      ),
                      onTap: _deleteAccount,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
