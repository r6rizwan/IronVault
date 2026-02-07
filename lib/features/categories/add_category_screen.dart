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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = Theme.of(context).textTheme.bodySmall?.color;
    return Scaffold(
      appBar: AppBar(title: const Text("Add Category")),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _sectionCard(
            context,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _selectedColor.withValues(alpha: 0.18),
                  child: Icon(
                    iconForKey(_selectedIcon),
                    color: _selectedColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nameCtrl.text.isEmpty
                            ? 'New Category'
                            : _nameCtrl.text,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Preview',
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          _sectionTitle('Name'),
          _sectionCard(
            context,
            child: TextField(
              controller: _nameCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: "Category name",
                hintText: "e.g. Social, Banking",
              ),
            ),
          ),

          const SizedBox(height: 16),
          _sectionTitle('Icon'),
          _sectionCard(
            context,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: presetIcons.keys.map((k) {
                final icon = iconForKey(k);
                final selected = k == _selectedIcon;
                final chipBg = selected
                    ? Theme.of(context).colorScheme.primary
                    : (isDark ? Colors.white10 : Colors.black12);
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedIcon = k),
                  label: Icon(
                    icon,
                    color: selected ? Colors.white : Colors.white70,
                  ),
                  backgroundColor:
                      isDark ? Colors.white10 : Colors.grey.shade200,
                  selectedColor: chipBg,
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),
          _sectionTitle('Color'),
          _sectionCard(
            context,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presetColors.map((c) {
                final sel = c == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c),
                  child: Container(
                    width: sel ? 44 : 36,
                    height: sel ? 44 : 36,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: sel
                            ? (isDark ? Colors.white70 : Colors.black26)
                            : Colors.transparent,
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child: sel
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 20),
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
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _sectionCard(BuildContext context, {required Widget child}) {
    return Container(
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
      child: child,
    );
  }
}
