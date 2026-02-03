// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/features/categories/providers/category_provider.dart';
import 'package:ironvault/core/constants/category_presets.dart';
import 'package:ironvault/features/categories/add_category_screen.dart';
import 'package:ironvault/features/vault/screens/credential_list_screen.dart';
import 'package:ironvault/core/theme/app_tokens.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // final textColor = AppThemeColors.text(context);
    final textMuted = AppThemeColors.textMuted(context);
    final categories = ref.watch(categoryListProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("Categories"), elevation: 0),
      floatingActionButton: FloatingActionButton(
        heroTag: 'categories_fab',
        backgroundColor: Theme.of(context).colorScheme.primary,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddCategoryScreen()),
          );
        },
        child: const Icon(Icons.add, size: 28),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: categories.isEmpty
            ? Center(
                child: Text(
                  "No categories yet",
                  style: TextStyle(fontSize: 16, color: textMuted),
                ),
              )
            : ListView.separated(
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final c = categories[i];
                  return _CategoryTile(
                    name: c.name,
                    icon: iconForKey(c.iconKey),
                    color: c.color,
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CredentialListScreen(categoryFilter: c.name),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.name,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppThemeColors.text(context);
    final textMuted = AppThemeColors.textMuted(context);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 18, color: textMuted),
          ],
        ),
      ),
    );
  }
}
