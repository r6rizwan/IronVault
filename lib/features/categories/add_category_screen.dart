// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/features/categories/providers/category_provider.dart';
import '../../../core/constants/category_presets.dart';
import '../../../domain/entities/vault_category.dart';

class AddCategoryScreen extends ConsumerStatefulWidget {
  const AddCategoryScreen({super.key});

  @override
  ConsumerState<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends ConsumerState<AddCategoryScreen> {
  final _nameCtrl = TextEditingController();
  String _selectedIcon = presetIcons.keys.first;
  Color _selectedColor = presetColors.first;
  bool _saving = false;

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);

    final category = VaultCategory(
      name: name,
      iconKey: _selectedIcon,
      colorValue: _selectedColor.value,
    );

    await ref.read(categoryListProvider.notifier).addCategory(category);

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Category")),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
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
              child: TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: "Category name"),
              ),
            ),
            const SizedBox(height: 16),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Icon",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: presetIcons.keys.map((k) {
                final icon = iconForKey(k);
                final selected = k == _selectedIcon;
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedIcon = k),
                  label: Icon(
                    icon,
                    color: selected ? Colors.white : Colors.black87,
                  ),
                  selectedColor: Theme.of(context).colorScheme.primary,
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Color",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: presetColors.map((c) {
                final sel = c == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    width: sel ? 44 : 36,
                    height: sel ? 44 : 36,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: sel
                          ? Border.all(color: Colors.black12, width: 2)
                          : null,
                    ),
                    child: sel
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const CircularProgressIndicator()
                    : const Text("Save Category"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
