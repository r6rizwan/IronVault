import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ironvault/core/providers.dart';

class AddCredentialScreen extends ConsumerStatefulWidget {
  const AddCredentialScreen({super.key});

  @override
  ConsumerState<AddCredentialScreen> createState() =>
      _AddCredentialScreenState();
}

class _AddCredentialScreenState extends ConsumerState<AddCredentialScreen> {
  final _titleController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _notesController = TextEditingController();

  bool _saving = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _generatePassword({
    int length = 16,
    bool upper = true,
    bool lower = true,
    bool digits = true,
    bool symbols = true,
  }) {
    const uppers = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lowers = 'abcdefghijklmnopqrstuvwxyz';
    const nums = '0123456789';
    const syms = r'!@#\$%^&*()-_=+[]{};:,.<>?';

    final pool = StringBuffer();
    if (upper) pool.write(uppers);
    if (lower) pool.write(lowers);
    if (digits) pool.write(nums);
    if (symbols) pool.write(syms);

    final chars = pool.toString();
    if (chars.isEmpty) return '';

    final rnd = Random.secure();
    return List.generate(
      length,
      (_) => chars[rnd.nextInt(chars.length)],
    ).join();
  }

  Future<void> _onGeneratePressed() async {
    final pwd = _generatePassword(
      length: 16,
      upper: true,
      lower: true,
      digits: true,
      symbols: false,
    );
    _passwordController.text = pwd;
    setState(() => _obscurePassword = false);
    // keep it visible briefly to show the generated value
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _obscurePassword = true);
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final notes = _notesController.text.trim();

    if (title.isEmpty || username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill Title, Username and Password"),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final repo = ref.read(credentialRepoProvider);
      await repo.addCredential(
        title: title,
        username: username,
        password: password,
        notes: notes.isEmpty ? null : notes,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool obscure = false,
    Widget? suffix,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor:
            Theme.of(context).inputDecorationTheme.fillColor ??
            Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14.0,
          horizontal: 16.0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixIcon: suffix,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = const SizedBox(height: 14);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Credential',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(
                controller: _titleController,
                label: 'Title (e.g., Gmail)',
              ),
              spacing,
              _buildTextField(
                controller: _usernameController,
                label: 'Username / Email',
                hint: 'name@example.com',
              ),
              spacing,
              _buildTextField(
                controller: _passwordController,
                label: 'Password',
                obscure: _obscurePassword,
                suffix: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: _obscurePassword ? 'Show' : 'Hide',
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    IconButton(
                      tooltip: 'Generate',
                      icon: const Icon(Icons.auto_fix_high),
                      onPressed: _onGeneratePressed,
                    ),
                  ],
                ),
              ),
              spacing,
              _buildTextField(
                controller: _notesController,
                label: 'Notes (optional)',
                maxLines: 4,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Credential'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () {
                    _titleController.clear();
                    _usernameController.clear();
                    _passwordController.clear();
                    _notesController.clear();
                  },
                  child: const Text('Clear'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
