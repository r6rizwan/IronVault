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
import 'package:ironvault/core/utils/attachment_utils.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
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

  String _displayTitle() {
    final fields = (item['fields'] as Map?)?.cast<String, dynamic>() ?? {};
    if (item['type'] == 'bank') {
      final bankName = (fields['bank_name'] ?? '').toString().trim();
      if (bankName.isNotEmpty) return bankName;
    }
    return (item['title'] ?? '').toString();
  }

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
        (await storage.readValue('disable_clipboard_copy') ?? 'false') ==
        'true';
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
                final path = pages[i];
                if (isImageAttachment(path)) {
                  return InteractiveViewer(
                    child: Image.file(
                      File(path),
                      fit: BoxFit.contain,
                      cacheWidth: 1440,
                    ),
                  );
                }
                if (isPdfAttachment(path)) {
                  return PDFView(
                    filePath: path,
                    fitEachPage: true,
                    enableSwipe: true,
                    swipeHorizontal: false,
                    autoSpacing: true,
                    pageFling: false,
                    onError: (_) {},
                    onPageError: (_, __) {},
                  );
                }
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.insert_drive_file,
                          size: 64,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${getFileExtension(path).toUpperCase()} attachment\n${path.split(Platform.pathSeparator).last}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
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
    final fields = (item['fields'] as Map?)?.cast<String, dynamic>() ?? {};
    final rawNames = (fields['scan_names'] ?? '').toString().trim();
    List<String> mutableNames = [];
    if (rawNames.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawNames);
        if (decoded is List) {
          mutableNames = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    while (mutableNames.length < mutable.length) {
      mutableNames.add(
        mutable[mutableNames.length].split(Platform.pathSeparator).last,
      );
    }
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
                        final name = mutableNames.removeAt(oldIndex);
                        mutable.insert(newIndex, item);
                        mutableNames.insert(newIndex, name);
                      });
                    },
                    itemBuilder: (context, index) {
                      final path = mutable[index];
                      final displayName = mutableNames[index];
                      return Padding(
                        key: ValueKey(path),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: isImageAttachment(path)
                                ? Image.file(
                                    File(path),
                                    width: 48,
                                    height: 64,
                                    fit: BoxFit.cover,
                                    cacheWidth: 200,
                                    cacheHeight: 260,
                                  )
                                : Container(
                                    width: 48,
                                    height: 64,
                                    color: Colors.grey.shade200,
                                    child: Icon(
                                      isPdfAttachment(path)
                                          ? Icons.picture_as_pdf
                                          : Icons.insert_drive_file,
                                    ),
                                  ),
                          ),
                          title: Text(displayName),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              setState(() {
                                mutable.removeAt(index);
                                mutableNames.removeAt(index);
                              });
                            },
                          ),
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
                      fields['scan_names'] = jsonEncode(mutableNames);
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
    ref.read(vaultRefreshProvider.notifier).state++;

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
        (item["fields"] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

    final entries = <_ShareEntry>[
      _ShareEntry(label: 'Title', value: _displayTitle()),
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
            final scanFiles = decoded
                .map((e) => e.toString())
                .where((path) => path.trim().isNotEmpty)
                .map((path) => XFile(path))
                .toList();
            entries.add(
              _ShareEntry(
                label: 'Scanned Pages',
                value: '${decoded.length}',
                files: scanFiles,
              ),
            );
          }
        } catch (_) {}
        continue;
      }

      final value = (fields[field.key] ?? '').toString().trim();
      if (value.isEmpty) continue;
      entries.add(
        _ShareEntry(label: field.label, value: value, selected: !field.obscure),
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

  List<XFile> _buildShareFilesFromEntries(List<_ShareEntry> entries) {
    return entries
        .where((entry) => entry.selected)
        .expand((entry) => entry.files)
        .toList();
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
    final shareFiles = _buildShareFilesFromEntries(entries);
    if (shareText.trim().isEmpty && shareFiles.isEmpty) {
      showAppToast(context, 'Select at least one field to share');
      return;
    }

    final autoLock = ref.read(autoLockProvider.notifier);
    autoLock.suspendAutoLock();
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: shareText.trim().isEmpty ? null : shareText,
          subject: _displayTitle().isEmpty ? "Credential" : _displayTitle(),
          files: shareFiles,
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

  String _formatDate(DateTime? value) {
    if (value == null) return '';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  Set<String> _heroFieldKeys(String typeKey) {
    switch (typeKey) {
      case 'password':
        return {'username', 'password'};
      case 'card':
        return {'cardholder_name', 'number', 'expiry', 'issuer'};
      case 'bank':
        return {
          'bank_name',
          'account_type',
          'account_number',
          'ifsc_code',
          'branch_name',
        };
      case 'document':
        return {'scans', 'document_id'};
      case 'note':
        return {'note'};
      default:
        return {};
    }
  }

  Widget _summaryPill({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tint),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(ItemTypeDefinition typeDef) {
    final category = (item["category"] ?? "").toString().trim();
    final createdAt = item['createdAt'] as DateTime?;
    final updatedAt = item['updatedAt'] as DateTime?;
    final dateLabel = _formatDate(updatedAt ?? createdAt);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 8),
            color: Colors.black.withValues(alpha: 0.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                child: Icon(
                  typeDef.icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayTitle(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      typeDef.label,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppThemeColors.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (item["isFavorite"] == true)
                const Icon(Icons.star_rounded, color: Colors.amber),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryPill(icon: typeDef.icon, label: typeDef.label),
              if (category.isNotEmpty)
                _summaryPill(
                  icon: Icons.folder_open_rounded,
                  label: category,
                  color: Colors.teal,
                ),
              if (dateLabel.isNotEmpty)
                _summaryPill(
                  icon: Icons.schedule_rounded,
                  label: dateLabel,
                  color: Colors.indigo,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppThemeColors.textMuted(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroValueCard({
    required String label,
    required String value,
    bool obscure = false,
    String? copyKey,
  }) {
    final isObscure = obscure;
    final obscureState = copyKey != null
        ? (_obscureFields[copyKey] ?? true)
        : false;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 6),
            color: Colors.black.withValues(alpha: 0.05),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppThemeColors.textMuted(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isObscure && obscureState ? '•' * 12 : value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (copyKey != null && isObscure)
            IconButton(
              icon: Icon(
                obscureState ? Icons.visibility : Icons.visibility_off,
                size: 22,
              ),
              onPressed: () {
                setState(() {
                  _obscureFields[copyKey] = !obscureState;
                });
              },
            ),
          if (copyKey != null)
            IconButton(
              icon: Icon(
                _copiedKey == copyKey
                    ? Icons.check
                    : _clipboardDisabled
                    ? Icons.lock_outline
                    : Icons.copy,
                color: _copiedKey == copyKey
                    ? Colors.green
                    : (_clipboardDisabled ? Colors.grey : null),
              ),
              onPressed: _copiedKey == copyKey || _clipboardDisabled
                  ? null
                  : () => _copyValue(copyKey, value),
            ),
        ],
      ),
    );
  }

  Widget _documentHero(Map<String, dynamic> fields) {
    final raw = (fields['scans'] ?? '').toString().trim();
    final docId = (fields['document_id'] ?? '').toString().trim();
    List<String> pages = [];
    List<String> names = [];
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          pages = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    final rawNames = (fields['scan_names'] ?? '').toString().trim();
    if (rawNames.isNotEmpty) {
      try {
        final decodedNames = jsonDecode(rawNames);
        if (decodedNames is List) {
          names = decodedNames.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    while (names.length < pages.length) {
      names.add(pages[names.length].split(Platform.pathSeparator).last);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pages.isNotEmpty) ...[
          _sectionTitle('Attachments'),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: pages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final path = pages[i];
                final displayName = names[i];
                return GestureDetector(
                  onTap: () => _openScanPreview(context, pages, i),
                  child: Container(
                    width: 112,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                          color: Colors.black.withValues(alpha: 0.05),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isImageAttachment(path))
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(path),
                                width: double.infinity,
                                fit: BoxFit.cover,
                                cacheWidth: 280,
                                cacheHeight: 280,
                              ),
                            ),
                          )
                        else ...[
                          Icon(
                            isPdfAttachment(path)
                                ? Icons.picture_as_pdf
                                : Icons.insert_drive_file,
                            size: 32,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            _heroStat('Files', pages.length.toString()),
            const SizedBox(width: 12),
            _heroStat('Document ID', docId.isEmpty ? 'Not added' : docId),
          ],
        ),
      ],
    );
  }

  Widget _passwordHero(Map<String, dynamic> fields) {
    final username = (fields['username'] ?? '').toString().trim();
    final password = (fields['password'] ?? '').toString().trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (username.isNotEmpty) ...[
          _sectionTitle('Account'),
          _heroValueCard(
            label: 'Username / Email',
            value: username,
            copyKey: 'username',
          ),
          const SizedBox(height: 12),
        ],
        if (password.isNotEmpty) ...[
          _sectionTitle('Password'),
          _heroValueCard(
            label: 'Password',
            value: password,
            obscure: true,
            copyKey: 'password',
          ),
        ],
      ],
    );
  }

  Widget _cardHero(Map<String, dynamic> fields) {
    final number = (fields['number'] ?? '').toString().trim();
    final cardholder = (fields['cardholder_name'] ?? '').toString().trim();
    final expiry = (fields['expiry'] ?? '').toString().trim();
    final issuer = (fields['issuer'] ?? '').toString().trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (number.isNotEmpty) ...[
          _sectionTitle('Card'),
          _heroValueCard(
            label: 'Card Number',
            value: number,
            obscure: true,
            copyKey: 'number',
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            _heroStat(
              'Cardholder',
              cardholder.isEmpty ? 'Not added' : cardholder,
            ),
            const SizedBox(width: 12),
            _heroStat('Expiry', expiry.isEmpty ? 'Not added' : expiry),
          ],
        ),
        if (issuer.isNotEmpty) ...[
          const SizedBox(height: 12),
          _heroStat('Issuer / Bank', issuer),
        ],
      ],
    );
  }

  Widget _bankHero(Map<String, dynamic> fields) {
    final bankName = (fields['bank_name'] ?? '').toString().trim();
    final accountType = (fields['account_type'] ?? '').toString().trim();
    final accountNumber = (fields['account_number'] ?? '').toString().trim();
    final ifsc = (fields['ifsc_code'] ?? '').toString().trim();
    final branch = (fields['branch_name'] ?? '').toString().trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _heroStat('Bank', bankName.isEmpty ? 'Not added' : bankName),
            const SizedBox(width: 12),
            _heroStat('Branch', branch.isEmpty ? 'Not added' : branch),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _heroStat(
              'Account Type',
              accountType.isEmpty ? 'Not added' : accountType,
            ),
            const SizedBox(width: 12),
            _heroStat('IFSC Code', ifsc.isEmpty ? 'Not added' : ifsc),
          ],
        ),
        const SizedBox(height: 12),
        if (accountNumber.isNotEmpty)
          _heroValueCard(
            label: 'Account Number',
            value: accountNumber,
            copyKey: 'account_number',
          ),
      ],
    );
  }

  Widget _noteHero(Map<String, dynamic> fields) {
    final note = (fields['note'] ?? '').toString().trim();
    if (note.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Note'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                blurRadius: 12,
                offset: const Offset(0, 6),
                color: Colors.black.withValues(alpha: 0.05),
              ),
            ],
          ),
          child: Text(
            note,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroSection(String typeKey, Map<String, dynamic> fields) {
    switch (typeKey) {
      case 'password':
        return _passwordHero(fields);
      case 'card':
        return _cardHero(fields);
      case 'bank':
        return _bankHero(fields);
      case 'document':
        return _documentHero(fields);
      case 'note':
        return _noteHero(fields);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFav = (item["isFavorite"] == true);
    final typeKey = (item["type"] ?? "password").toString();
    final typeDef = typeByKey(typeKey);
    final fields =
        (item["fields"] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _displayTitle(),
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: "More options",
            onSelected: (val) async {
              if (val == 'share') {
                _shareCredential();
              } else if (val == 'delete') {
                final confirm = await showDialog<bool>(
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
                  ref.read(vaultRefreshProvider.notifier).state++;

                  if (mounted) Navigator.pop(context);
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem<String>(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Share'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    SizedBox(width: 12),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summaryCard(typeDef),
            const SizedBox(height: 18),
            _buildHeroSection(typeKey, fields),

            ...typeDef.fields.map((field) {
              if (_heroFieldKeys(typeKey).contains(field.key)) {
                return const SizedBox.shrink();
              }
              if (field.key == 'scans') {
                final raw = (fields['scans'] ?? '').toString();
                if (raw.trim().isEmpty) return const SizedBox.shrink();
                int count = 0;
                List<String> pages = [];
                List<String> names = [];
                try {
                  final decoded = jsonDecode(raw);
                  if (decoded is List) {
                    pages = decoded.map((e) => e.toString()).toList();
                    count = pages.length;
                  }
                  final rawNames = (fields['scan_names'] ?? '')
                      .toString()
                      .trim();
                  if (rawNames.isNotEmpty) {
                    final decodedNames = jsonDecode(rawNames);
                    if (decodedNames is List) {
                      names = decodedNames.map((e) => e.toString()).toList();
                    }
                  }
                } catch (_) {}
                if (count == 0) return const SizedBox.shrink();
                while (names.length < pages.length) {
                  names.add(
                    pages[names.length].split(Platform.pathSeparator).last,
                  );
                }
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
                          final displayName = names[i];
                          return GestureDetector(
                            onTap: () => _openScanPreview(context, pages, i),
                            child: Container(
                              width: 70,
                              height: 90,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Theme.of(context).cardColor,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: isImageAttachment(path)
                                    ? Image.file(
                                        File(path),
                                        fit: BoxFit.cover,
                                        cacheWidth: 240,
                                        cacheHeight: 320,
                                      )
                                    : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            isPdfAttachment(path)
                                                ? Icons.picture_as_pdf
                                                : Icons.insert_drive_file,
                                            size: 28,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                          const SizedBox(height: 6),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                            child: Text(
                                              displayName,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: AppThemeColors.textMuted(
                                                  context,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
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
                            color: _copiedKey == field.key
                                ? Colors.green
                                : (_clipboardDisabled ? Colors.grey : null),
                            size: 22,
                          ),
                          onPressed:
                              _copiedKey == field.key || _clipboardDisabled
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
    this.files = const [],
  });

  final String label;
  final String value;
  bool selected;
  final List<XFile> files;
}
