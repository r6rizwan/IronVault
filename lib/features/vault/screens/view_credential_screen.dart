// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/constants.dart';
import 'package:ironvault/core/constants/item_types.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/core/autolock/auto_lock_provider.dart';
import 'package:ironvault/core/widgets/app_toast.dart';
import 'package:ironvault/features/add/screens/add_item_screen.dart';
import 'package:ironvault/core/theme/app_tokens.dart';
import 'package:share_plus/share_plus.dart';

class ViewCredentialScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> item;

  const ViewCredentialScreen({super.key, required this.item});

  @override
  ConsumerState<ViewCredentialScreen> createState() =>
      _ViewCredentialScreenState();
}

class _ViewCredentialScreenState extends ConsumerState<ViewCredentialScreen> {
  late Map<String, dynamic> item;

  String? _copiedKey;
  Timer? _clipboardClearTimer;
  String? _lastCopiedValue;
  final Map<String, bool> _obscureFields = {};
  bool _clipboardDisabled = false;

  @override
  void initState() {
    super.initState();
    item = Map<String, dynamic>.from(widget.item); // local copy so UI updates
    _initObscureStates();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final storage = ref.read(secureStorageProvider);
    _clipboardDisabled =
        (await storage.readValue('disable_clipboard_copy') ?? 'false') == 'true';
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _clipboardClearTimer?.cancel();
    super.dispose();
  }

  void _initObscureStates() {
    final type = (item['type'] ?? 'password').toString();
    final def = typeByKey(type);
    for (final field in def.fields) {
      if (field.obscure) {
        _obscureFields[field.key] = true;
      }
    }
  }

  Future<void> _scheduleClipboardClear(String value) async {
    _clipboardClearTimer?.cancel();
    _lastCopiedValue = value;

    _clipboardClearTimer = Timer(
      const Duration(seconds: AppConstants.clipboardClearSeconds),
      () async {
        try {
          final data = await Clipboard.getData('text/plain');
          if (data?.text == _lastCopiedValue) {
            await Clipboard.setData(const ClipboardData(text: ""));
          }
        } catch (_) {}

        if (mounted) {
          setState(() => _copiedKey = null);
        }
      },
    );
  }

  Future<void> _copyValue(String key, String value) async {
    if (_clipboardDisabled) return;
    await Clipboard.setData(ClipboardData(text: value));
    setState(() => _copiedKey = key);
    await _scheduleClipboardClear(value);
  }

  void _openScanPreview(
    BuildContext context,
    List<String> pages,
    int initialIndex,
  ) {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            color: Colors.black,
            height: MediaQuery.of(context).size.height * 0.7,
            child: PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: pages.length,
              itemBuilder: (_, i) {
                return InteractiveViewer(
                  child: Image.file(
                    File(pages[i]),
                    fit: BoxFit.contain,
                    cacheWidth: 1440,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _openScanManager(BuildContext context, List<String> pages) {
    final mutable = List<String>.from(pages);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Manage scanned pages',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 320,
                  child: ReorderableListView.builder(
                    itemCount: mutable.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = mutable.removeAt(oldIndex);
                        mutable.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final path = mutable[index];
                      return ListTile(
                        key: ValueKey(path),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(path),
                            width: 48,
                            height: 64,
                            fit: BoxFit.cover,
                            cacheWidth: 200,
                            cacheHeight: 260,
                          ),
                        ),
                        title: Text('Page ${index + 1}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            setState(() => mutable.removeAt(index));
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final repo = ref.read(credentialRepoProvider);
                      final fields = Map<String, String>.from(
                        (item['fields'] as Map).cast<String, String>(),
                      );
                      fields['scans'] = jsonEncode(mutable);
                      await repo.updateItem(
                        id: item['id'],
                        type: item['type'],
                        title: item['title'],
                        fields: fields,
                        category: item['category'],
                      );
                      setState(() {
                        item['fields'] = fields;
                      });
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Save changes'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleFavorite() async {
    final repo = ref.read(credentialRepoProvider);
    final newState = !(item["isFavorite"] == true);

    await repo.toggleFavorite(item["id"], newState);

    setState(() {
      item["isFavorite"] = newState;
    });
  }

  Future<void> _reloadCurrentItem() async {
    final repo = ref.read(credentialRepoProvider);
    final all = await repo.getAllDecrypted();
    final currentId = item["id"];
    final match = all.where((e) => e["id"] == currentId).toList();
    if (match.isEmpty || !mounted) return;
    setState(() {
      item = Map<String, dynamic>.from(match.first);
      _obscureFields.clear();
      _initObscureStates();
    });
  }

  List<_ShareEntry> _buildShareEntries() {
    final typeKey = (item["type"] ?? "password").toString();
    final typeDef = typeByKey(typeKey);
    final fields =
        (item["fields"] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    final entries = <_ShareEntry>[
      _ShareEntry(label: 'Title', value: (item["title"] ?? "").toString()),
      _ShareEntry(label: 'Type', value: typeDef.label),
    ];

    final category = (item["category"] ?? "").toString().trim();
    if (category.isNotEmpty) {
      entries.add(_ShareEntry(label: 'Category', value: category));
    }

    for (final field in typeDef.fields) {
      if (field.key == 'scans') {
        final raw = (fields['scans'] ?? '').toString().trim();
        if (raw.isEmpty) continue;
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List && decoded.isNotEmpty) {
            entries.add(
              _ShareEntry(label: 'Scanned Pages', value: '${decoded.length}'),
            );
          }
        } catch (_) {}
        continue;
      }

      final value = (fields[field.key] ?? '').toString().trim();
      if (value.isEmpty) continue;
      entries.add(
        _ShareEntry(
          label: field.label,
          value: value,
          selected: !field.obscure,
        ),
      );
    }

    return entries;
  }

  String _buildShareTextFromEntries(List<_ShareEntry> entries) {
    final buffer = StringBuffer();
    buffer.writeln('IronVault Credential');
    for (final entry in entries) {
      if (!entry.selected) continue;
      buffer.writeln('${entry.label}: ${entry.value}');
    }
    return buffer.toString().trim();
  }

  Future<void> _shareCredential() async {
    final entries = _buildShareEntries();
    if (entries.isEmpty) {
      showAppToast(context, 'Nothing to share');
      return;
    }

    final shouldShare = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            final hasSelection = entries.any((e) => e.selected);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Share Credential',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Select fields to include.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppThemeColors.textMuted(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 320,
                      child: ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (_, i) {
                          final e = entries[i];
                          return SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(e.label),
                            subtitle: Text(
                              e.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            value: e.selected,
                            onChanged: (v) => setLocal(() => e.selected = v),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: hasSelection
                              ? () => Navigator.pop(ctx, true)
                              : null,
                          child: const Text('Share'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (shouldShare != true) return;
    final shareText = _buildShareTextFromEntries(entries);
    if (shareText.trim().isEmpty) {
      showAppToast(context, 'Select at least one field to share');
      return;
    }

    final autoLock = ref.read(autoLockProvider.notifier);
    autoLock.suspendAutoLock();
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          subject: (item["title"] ?? "Credential").toString(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, 'Share failed: $e');
    } finally {
      autoLock.resumeAutoLock();
    }
  }

  Widget _sectionTitle(String title) {
    final textMuted = AppThemeColors.textMuted(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 16),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          color: textMuted,
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 6),
            color: Colors.black.withValues(alpha: 0.06),
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
    final typeKey = (item["type"] ?? "password").toString();
    final typeDef = typeByKey(typeKey);
    final fields =
        (item["fields"] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    return Scaffold(
      appBar: AppBar(
        title: Text(
          item["title"],
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: isFav ? "Unpin" : "Mark as Favorite",
            icon: Icon(
              isFav ? Icons.star : Icons.star_border,
              color: isFav ? Colors.amber : Colors.grey,
              size: 26,
            ),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: "Edit",
            onPressed: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => AddItemScreen(existingItem: item),
                ),
              );
              if (updated == true) {
                await _reloadCurrentItem();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: "Share",
            onPressed: _shareCredential,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: "Delete",
            onPressed: () async {
              final confirm = await showDialog(
                context: context,
                builder: (_) {
                  return AlertDialog(
                    title: const Text("Delete Item"),
                    content: const Text(
                      "Are you sure you want to permanently delete this item?",
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle("Type"),
            _infoTile(value: typeDef.label),

            ...typeDef.fields.map((field) {
              if (field.key == 'scans') {
                final raw = (fields['scans'] ?? '').toString();
                if (raw.trim().isEmpty) return const SizedBox.shrink();
                int count = 0;
                List<String> pages = [];
                try {
                  final decoded = jsonDecode(raw);
                  if (decoded is List) {
                    pages = decoded.map((e) => e.toString()).toList();
                    count = pages.length;
                  }
                } catch (_) {}
                if (count == 0) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Scanned Pages'),
                    _infoTile(value: '$count page(s)'),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: pages.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) {
                          final path = pages[i];
                          return GestureDetector(
                            onTap: () => _openScanPreview(context, pages, i),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(path),
                                width: 70,
                                height: 90,
                                fit: BoxFit.cover,
                                cacheWidth: 240,
                                cacheHeight: 320,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _openScanManager(context, pages),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Manage pages'),
                      ),
                    ),
                  ],
                );
              }

              final value = (fields[field.key] ?? '').toString();
              if (value.trim().isEmpty) return const SizedBox.shrink();

              final isObscure = field.obscure;
              final obscureState = _obscureFields[field.key] ?? true;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(field.label),
                  _infoTile(
                    value: value,
                    obscure: isObscure ? obscureState : false,
                    action: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isObscure)
                          IconButton(
                            icon: Icon(
                              obscureState
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              size: 22,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureFields[field.key] = !obscureState;
                              });
                            },
                          ),
                        IconButton(
                          icon: Icon(
                            _copiedKey == field.key
                                ? Icons.check
                                : _clipboardDisabled
                                    ? Icons.lock_outline
                                    : Icons.copy,
                            color:
                                _copiedKey == field.key
                                    ? Colors.green
                                    : (_clipboardDisabled
                                        ? Colors.grey
                                        : null),
                            size: 22,
                          ),
                          onPressed: _copiedKey == field.key ||
                                  _clipboardDisabled
                              ? null
                              : () => _copyValue(field.key, value),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),

            if (item["category"] != null &&
                item["category"].toString().trim().isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Category"),
                  _infoTile(value: item["category"]),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ShareEntry {
  _ShareEntry({
    required this.label,
    required this.value,
    this.selected = true,
  });

  final String label;
  final String value;
  bool selected;
}
