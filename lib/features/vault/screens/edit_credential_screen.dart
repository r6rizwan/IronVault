// lib/features/vault/screens/edit_credential_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/widgets/common_text_field.dart';
import 'package:ironvault/core/providers.dart';

class EditCredentialScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> item;

  const EditCredentialScreen({super.key, required this.item});

  @override
  ConsumerState<EditCredentialScreen> createState() =>
      _EditCredentialScreenState();
}

class _EditCredentialScreenState extends ConsumerState<EditCredentialScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _notesController;

  bool _saving = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.item["title"] ?? "");
    _usernameController = TextEditingController(
      text: widget.item["username"] ?? "",
    );
    _passwordController = TextEditingController(
      text: widget.item["password"] ?? "",
    );
    _notesController = TextEditingController(text: widget.item["notes"] ?? "");
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final repo = ref.read(credentialRepoProvider);

    await repo.updateCredential(
      id: widget.item["id"],
      title: _titleController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
      notes: _notesController.text.trim(),
    );

    setState(() => _saving = false);

    if (!mounted) return;

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = const SizedBox(height: 20);

    return Scaffold(
      appBar: AppBar(title: const Text("Edit Credential"), elevation: 0),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // TITLE
              CommonTextField(label: "Title", controller: _titleController),
              spacing,

              // USERNAME
              CommonTextField(
                label: "Username / Email",
                controller: _usernameController,
              ),
              spacing,

              // PASSWORD WITH TOGGLE
              CommonTextField(
                label: "Password",
                controller: _passwordController,
                obscure: _obscurePassword,
                onToggle: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              spacing,

              // NOTES
              CommonTextField(label: "Notes", controller: _notesController),
              spacing,

              // SAVE BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text("Save Changes"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
