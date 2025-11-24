// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/providers.dart';
import 'edit_credential_screen.dart';

class ViewCredentialScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> item;

  const ViewCredentialScreen({super.key, required this.item});

  @override
  ConsumerState<ViewCredentialScreen> createState() =>
      _ViewCredentialScreenState();
}

class _ViewCredentialScreenState extends ConsumerState<ViewCredentialScreen> {
  late Map<String, dynamic> item;

  bool _showPassword = false;
  bool _copiedPassword = false;
  bool _copiedUsername = false;

  @override
  void initState() {
    super.initState();
    item = Map<String, dynamic>.from(widget.item); // local copy so UI updates
  }

  Future<void> _copyPassword() async {
    final pwd = item["password"] ?? "";
    await Clipboard.setData(ClipboardData(text: pwd));

    setState(() => _copiedPassword = true);

    Future.delayed(const Duration(seconds: 10), () async {
      await Clipboard.setData(const ClipboardData(text: ""));
      if (mounted) setState(() => _copiedPassword = false);
    });
  }

  Future<void> _copyUsername() async {
    final username = item["username"] ?? "";
    await Clipboard.setData(ClipboardData(text: username));

    setState(() => _copiedUsername = true);

    Future.delayed(const Duration(seconds: 10), () async {
      await Clipboard.setData(const ClipboardData(text: ""));
      if (mounted) setState(() => _copiedUsername = false);
    });
  }

  Future<void> _toggleFavorite() async {
    final repo = ref.read(credentialRepoProvider);
    final newState = !(item["isFavorite"] == true);

    await repo.toggleFavorite(item["id"], newState);

    setState(() {
      item["isFavorite"] = newState;
    });
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 16),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade600,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _infoTile({
    required String value,
    bool obscure = false,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            offset: const Offset(0, 3),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              obscure ? "•" * 10 : value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFav = (item["isFavorite"] == true);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          item["title"],
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          // ⭐ FAVORITE / PIN BUTTON
          IconButton(
            tooltip: isFav ? "Unpin" : "Mark as Favorite",
            icon: Icon(
              isFav ? Icons.star : Icons.star_border,
              color: isFav ? Colors.amber : Colors.grey,
              size: 26,
            ),
            onPressed: _toggleFavorite,
          ),

          // ✏ EDIT BUTTON
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: "Edit",
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditCredentialScreen(item: item),
                ),
              );

              if (mounted) Navigator.pop(context);
            },
          ),

          // 🗑 DELETE BUTTON
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: "Delete",
            onPressed: () async {
              final confirm = await showDialog(
                context: context,
                builder: (_) {
                  return AlertDialog(
                    title: const Text("Delete Credential"),
                    content: const Text(
                      "Are you sure you want to permanently delete this credential?",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          "Delete",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  );
                },
              );

              if (confirm == true) {
                final repo = ref.read(credentialRepoProvider);
                await repo.deleteCredential(item["id"]);

                if (mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    radius: 26,
                    child: const Icon(Icons.lock, color: Colors.white),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      item["title"],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Username
            _sectionTitle("Username / Email"),
            _infoTile(
              value: item["username"] ?? "",
              action: IconButton(
                icon: Icon(
                  _copiedUsername ? Icons.check : Icons.copy,
                  color: _copiedUsername ? Colors.green : null,
                  size: 22,
                ),
                onPressed: _copiedUsername ? null : _copyUsername,
              ),
            ),

            // Password
            _sectionTitle("Password"),
            _infoTile(
              value: item["password"] ?? "",
              obscure: !_showPassword,
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                      size: 22,
                    ),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                  IconButton(
                    icon: Icon(
                      _copiedPassword ? Icons.check : Icons.copy,
                      color: _copiedPassword ? Colors.green : null,
                      size: 22,
                    ),
                    onPressed: _copiedPassword ? null : _copyPassword,
                  ),
                ],
              ),
            ),

            // Notes
            if (item["notes"] != null &&
                item["notes"].toString().trim().isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Notes"),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                          color: Colors.black.withOpacity(0.05),
                        ),
                      ],
                    ),
                    child: Text(
                      item["notes"],
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
