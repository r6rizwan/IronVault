// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/features/vault/screens/view_credential_screen.dart';
import 'package:ironvault/core/theme/app_tokens.dart';
import 'package:ironvault/core/widgets/empty_state.dart';
import 'package:ironvault/core/constants/item_types.dart';
import 'package:ironvault/features/categories/providers/category_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  final String? categoryFilter;

  const SearchScreen({super.key, this.showAppBar = true, this.categoryFilter});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = "";
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];
  String? _typeFilter;
  String? _categoryFilter;
  bool _favoritesOnly = false;

  @override
  void initState() {
    super.initState();
    _categoryFilter = widget.categoryFilter;
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = ref.read(credentialRepoProvider);
    final data = await repo.getAllDecrypted();
    if (!mounted) return;
    setState(() {
      _items = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = ref.watch(categoryListProvider);
    final filteredCategories = categories.where((c) {
      final name = c.name.toLowerCase();
      const blocked = [
        'bank accounts',
        'bank account',
        'bank cards',
        'bank card',
        'secure notes',
        'secure note',
        'id documents',
        'id document',
        'documents',
        'document',
        'cards',
        'card',
      ];
      return !blocked.contains(name);
    }).toList();
    final q = _query.toLowerCase();
    final results = _items.where((item) {
      if (_favoritesOnly && item['isFavorite'] != true) return false;
      if (_typeFilter != null &&
          (item['type'] ?? '').toString() != _typeFilter) {
        return false;
      }
      if (_categoryFilter != null &&
          (item['category'] ?? '').toString().toLowerCase() !=
              _categoryFilter!.toLowerCase()) {
        return false;
      }
      if (item["title"]?.toLowerCase().contains(q) ?? false) return true;
      final fields = (item["fields"] as Map?)?.cast<String, dynamic>() ?? {};
      for (final v in fields.values) {
        if (v?.toString().toLowerCase().contains(q) ?? false) return true;
      }
      return false;
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: widget.showAppBar
          ? AppBar(title: const Text("Search"), elevation: 0)
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          children: [
            const SizedBox(height: 6),

            // Search Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: TextField(
                controller: _controller,
                onChanged: (text) => setState(() => _query = text.trim()),
                decoration: InputDecoration(
                  hintText: "Search passwords, notes, cards, documents…",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: isDark ? Colors.white10 : const Color(0xFFF1F5FB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _openFilterSheet(context, filteredCategories),
                  icon: const Icon(Icons.tune),
                  label: const Text('Filters'),
                ),
                const SizedBox(width: 8),
                if (_typeFilter != null ||
                    _categoryFilter != null ||
                    _favoritesOnly)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _typeFilter = null;
                        _categoryFilter = null;
                        _favoritesOnly = false;
                      });
                    },
                    child: const Text('Clear'),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_query.isEmpty)
              _buildEmptyState()
            else
              _buildSearchResults(isDark, results),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const EmptyState(
      icon: Icons.search,
      title: "Start typing to search your vault",
      subtitle: "Results will appear instantly",
    );
  }

  Widget _buildSearchResults(bool isDark, List<Map<String, dynamic>> results) {
    final textMuted = AppThemeColors.textMuted(context);
    if (results.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: "No results found",
        subtitle: "Try another keyword",
      );
    }

    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (_, i) {
        final item = results[i];
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ViewCredentialScreen(item: item),
              ),
            );
          },
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
                  radius: 22,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),

                Expanded(
                  child: Text(
                    item["title"] ?? "Untitled",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),

                Icon(Icons.arrow_forward_ios, size: 16, color: textMuted),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openFilterSheet(BuildContext context, List<dynamic> categories) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text('Type'),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _typeFilter == null,
                      onSelected: (_) => setState(() => _typeFilter = null),
                    ),
                    ...itemTypes.map(
                      (t) => ChoiceChip(
                        label: Text(t.label),
                        selected: _typeFilter == t.key,
                        onSelected: (_) => setState(() => _typeFilter = t.key),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Category'),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _categoryFilter == null,
                      onSelected: (_) => setState(() => _categoryFilter = null),
                    ),
                    ...categories.map(
                      (c) => ChoiceChip(
                        label: Text(c.name),
                        selected: _categoryFilter == c.name,
                        onSelected: (_) =>
                            setState(() => _categoryFilter = c.name),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Favorites only'),
                  value: _favoritesOnly,
                  onChanged: (v) => setState(() => _favoritesOnly = v),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
