// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ViewCredentialScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> item;

  const ViewCredentialScreen({super.key, required this.item});

  @override
  ConsumerState<ViewCredentialScreen> createState() =>
      _ViewCredentialScreenState();
}

class _ViewCredentialScreenState extends ConsumerState<ViewCredentialScreen> {
  bool _showPassword = false;
  bool _copied = false;

  Future<void> _copyPassword() async {
    final pwd = widget.item["password"] ?? "";
    await Clipboard.setData(ClipboardData(text: pwd));

    setState(() => _copied = true);

    // Auto clear clipboard
    Future.delayed(const Duration(seconds: 10), () async {
      await Clipboard.setData(const ClipboardData(text: ""));
      if (mounted) setState(() => _copied = false);
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
    final item = widget.item;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          item["title"],
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card with icon + title
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
                    child: const Icon(
                      Icons.lock,
                      color: Colors.white,
                      size: 28,
                    ),
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
            _infoTile(value: item["username"]),

            // Password section
            _sectionTitle("Password"),
            _infoTile(
              value: item["password"],
              obscure: !_showPassword,
              action: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // show/hide icon
                  IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                      size: 22,
                    ),
                    onPressed: () {
                      setState(() => _showPassword = !_showPassword);
                    },
                  ),

                  // copy icon
                  IconButton(
                    icon: Icon(
                      _copied ? Icons.check : Icons.copy,
                      color: _copied ? Colors.green : null,
                      size: 22,
                    ),
                    onPressed: _copied ? null : _copyPassword,
                  ),
                ],
              ),
            ),

            // Notes section
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
