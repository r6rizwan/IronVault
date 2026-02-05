import 'dart:convert';
import 'dart:io';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/constants/item_types.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/core/widgets/common_text_field.dart';
import 'package:ironvault/features/categories/providers/category_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ironvault/core/theme/app_tokens.dart';
import 'package:ironvault/core/autolock/auto_lock_provider.dart';

class AddItemScreen extends ConsumerStatefulWidget {
  final String? initialType;
  final Map<String, dynamic>? existingItem;

  const AddItemScreen({super.key, this.initialType, this.existingItem});

  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _obscure = {};
  final List<String> _scanPaths = [];

  String _typeKey = 'password';
  String? _selectedCategory;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _typeKey = widget.initialType ?? widget.existingItem?['type'] ?? 'password';
    _selectedCategory = widget.existingItem?['category'] as String?;

    _titleController.text = widget.existingItem?['title'] ?? '';
    _initControllersForType(_typeKey);
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initControllersForType(String typeKey) {
    final type = typeByKey(typeKey);
    final existingFields = (widget.existingItem?['fields'] as Map?)
        ?.cast<String, dynamic>();

    final existingScans = existingFields?['scans'];
    if (_scanPaths.isEmpty &&
        existingScans is String &&
        existingScans.isNotEmpty) {
      try {
        final decoded = jsonDecode(existingScans);
        if (decoded is List) {
          _scanPaths.addAll(decoded.map((e) => e.toString()));
        }
      } catch (_) {}
    }

    for (final field in type.fields) {
      _controllers.putIfAbsent(
        field.key,
        () => TextEditingController(
          text: existingFields?[field.key]?.toString() ?? '',
        ),
      );
      if (field.obscure) {
        _obscure[field.key] = true;
      }
    }
  }

  void _onTypeChanged(String? value) {
    if (value == null) return;
    setState(() {
      _typeKey = value;
      _initControllersForType(value);
    });
  }

  Map<String, String> _collectFields() {
    final type = typeByKey(_typeKey);
    final Map<String, String> fields = {};
    for (final field in type.fields) {
      if (field.key == 'scans') {
        fields[field.key] = jsonEncode(_scanPaths);
        continue;
      }
      fields[field.key] = _controllers[field.key]?.text.trim() ?? '';
    }
    return fields;
  }

  bool _validateFields() {
    final type = typeByKey(_typeKey);
    final title = _titleController.text.trim();
    if (title.isEmpty) return false;

    for (final field in type.fields) {
      if (!field.required) continue;
      if (field.key == 'scans') continue;
      final value = _controllers[field.key]?.text.trim() ?? '';
      if (value.isEmpty) return false;
    }
    return true;
  }

  Future<void> _scanDocuments() async {
    ref.read(autoLockProvider.notifier).suspendAutoLock();
    List<String>? pages;
    try {
      pages = await CunningDocumentScanner.getPictures();
    } catch (_) {
      pages = null;
    }
    ref.read(autoLockProvider.notifier).resumeAutoLock();
    if (pages == null || pages.isEmpty) return;

    final dir = await getApplicationDocumentsDirectory();
    for (final path in pages) {
      final compressed = await _compressAndMove(path, dir.path);
      if (compressed != null) {
        _scanPaths.add(compressed);
      }
    }

    if (mounted) setState(() {});
  }

  Future<String?> _compressAndMove(String inputPath, String dirPath) async {
    final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final targetPath = '$dirPath/$fileName';
    try {
      final result = await FlutterImageCompress.compressAndGetFile(
        inputPath,
        targetPath,
        quality: 70,
        minWidth: 1280,
        minHeight: 1280,
      );
      if (result != null) {
        try {
          final original = File(inputPath);
          if (await original.exists()) {
            await original.delete();
          }
        } catch (_) {}
        return result.path;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _save() async {
    if (!_validateFields()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(credentialRepoProvider);
    final fields = _collectFields();

    try {
      if (widget.existingItem == null) {
        await repo.addItem(
          type: _typeKey,
          title: _titleController.text.trim(),
          fields: fields,
          category: _selectedCategory,
        );
      } else {
        await repo.updateItem(
          id: widget.existingItem!['id'],
          type: _typeKey,
          title: _titleController.text.trim(),
          fields: fields,
          category: _selectedCategory,
        );
      }

      TextInput.finishAutofillContext(shouldSave: true);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _scanSection(BuildContext context) {
    final textMuted = AppThemeColors.textMuted(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.document_scanner, size: 18),
              SizedBox(width: 8),
              Text(
                'Scan Document',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _scanPaths.isEmpty
                ? 'No pages scanned yet'
                : '${_scanPaths.length} page(s) scanned',
            style: TextStyle(color: textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _scanDocuments,
                icon: const Icon(Icons.document_scanner),
                label: const Text('Scan Pages'),
              ),
              const SizedBox(width: 10),
              if (_scanPaths.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() => _scanPaths.clear());
                  },
                  child: const Text('Clear'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = typeByKey(_typeKey);
    final categories = ref.watch(categoryListProvider);
    final isDocument = _typeKey == 'document';
    final textMuted = AppThemeColors.textMuted(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingItem == null ? 'Add Item' : 'Edit Item'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.12),
                          child: Icon(
                            type.icon,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.existingItem == null
                                    ? 'Create new item'
                                    : 'Edit item',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                type.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: _typeKey,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: itemTypes
                        .map(
                          (t) => DropdownMenuItem(
                            value: t.key,
                            child: Text(t.label),
                          ),
                        )
                        .toList(),
                    onChanged: _onTypeChanged,
                  ),
                  const SizedBox(height: 16),

                  CommonTextField(label: 'Title', controller: _titleController),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String?>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category (optional)',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('None'),
                      ),
                      ...categories.map(
                        (c) => DropdownMenuItem<String?>(
                          value: c.name,
                          child: Text(c.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedCategory = value);
                    },
                  ),

                  const SizedBox(height: 18),

                  if (isDocument) ...[
                    _scanSection(context),
                    const SizedBox(height: 12),
                  ],

                  ...type.fields.map((field) {
                    if (field.key == 'scans') {
                      return const SizedBox.shrink();
                    }
                    final controller = _controllers[field.key]!;
                    final obscure = _obscure[field.key] ?? false;
                    final suffix = field.obscure
                        ? IconButton(
                            icon: Icon(
                              obscure ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscure[field.key] = !obscure;
                              });
                            },
                          )
                        : null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: CommonTextField(
                        label: field.label,
                        controller: controller,
                        obscure: field.obscure ? obscure : false,
                        keyboardType: field.keyboardType,
                        maxLines: field.maxLines,
                        suffix: suffix,
                      ),
                    );
                  }),

                  const SizedBox(height: 6),

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
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
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
                          : Text(
                              widget.existingItem == null
                                  ? 'Save Item'
                                  : 'Save Changes',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
