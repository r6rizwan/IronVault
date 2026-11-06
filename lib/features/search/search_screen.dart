// SPDX-FileCopyrightText: 2025-2026 Rizwan Mulla
// SPDX-License-Identifier: GPL-3.0-only
// ignore_for_file: deprecated_member_use

import 'dart:convert';

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
  late final ProviderSubscription<int> _refreshSub;

  @override
  void initState() {
    super.initState();
    _categoryFilter = widget.categoryFilter;
    _load();
    _refreshSub = ref.listenManual<int>(
      vaultRefreshProvider,
      (_, __) => _load(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _refreshSub.close();
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

  String _subtitleForItem(Map<String, dynamic> item) {
    final fields = (item['fields'] as Map?)?.cast<String, dynamic>() ?? {};
    if (item['type'] == 'password') {
      return (fields['username'] ?? item['username'] ?? '').toString();
    }
    if (item['type'] == 'card') {
      final number = (fields['number'] ?? '').toString().replaceAll(' ', '');
      if (number.isEmpty) return 'Card ••••';
      final last4 = number.length >= 4
          ? number.substring(number.length - 4)
          : number;
      return 'Card •••• $last4';
    }
    if (item['type'] == 'bank') {
      final acct = (fields['account_number'] ?? '').toString().replaceAll(
        ' ',
        '',
      );
      if (acct.isEmpty) return 'Bank account';
      final last4 = acct.length >= 4 ? acct.substring(acct.length - 4) : acct;
      return 'A/C •••• $last4';
    }
    if (item['type'] == 'document') {
      final documentId = (fields['document_id'] ?? '').toString().trim();
      if (documentId.isNotEmpty) {
        return 'ID: $documentId';
      }

      final notes = (fields['notes'] ?? '').toString().trim();
      if (notes.isNotEmpty) {
        return notes;
      }

      final rawScans = (fields['scans'] ?? '').toString().trim();
      if (rawScans.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawScans);
          if (decoded is List) {
            final count = decoded.length;
            if (count > 0) {
              return count == 1 ? '1 scanned page' : '$count scanned pages';
            }
          }
        } catch (_) {}
      }

      return 'Saved document';
    }
    for (final v in fields.values) {
      final text = v?.toString() ?? '';
      if (text.trim().isNotEmpty) return text;
    }
    return '';
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
    final hasActiveFilters =
        _typeFilter != null || _categoryFilter != null || _favoritesOnly;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: widget.showAppBar
          ? AppBar(title: const Text("Search"), elevation: 0)
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
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
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = "");
                          },
                        ),
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
                  onPressed: () =>
                      _openFilterSheet(context, filteredCategories),
                  icon: const Icon(Icons.tune),
                  label: const Text('Filters'),
                ),
                const SizedBox(width: 8),
                if (hasActiveFilters)
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

            if (hasActiveFilters) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (_typeFilter != null)
                    InputChip(
                      label: Text('Type: ${typeByKey(_typeFilter!).label}'),
                      onDeleted: () => setState(() => _typeFilter = null),
                    ),
                  if (_categoryFilter != null)
                    InputChip(
                      label: Text('Category: $_categoryFilter'),
                      onDeleted: () => setState(() => _categoryFilter = null),
                    ),
                  if (_favoritesOnly)
                    InputChip(
                      avatar: Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                      label: const Text('Favorites'),
                      onDeleted: () => setState(() => _favoritesOnly = false),
                    ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            if (_loading)
              const _SearchLoadingState()
            else if (_query.isEmpty &&
                _typeFilter == null &&
                _categoryFilter == null &&
                !_favoritesOnly)
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
      title: "Search your vault",
      subtitle: "Type a name, username, note, or document detail to begin.",
    );
  }

  Widget _buildSearchResults(bool isDark, List<Map<String, dynamic>> results) {
    final textMuted = AppThemeColors.textMuted(context);
    if (results.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: "No results found",
        subtitle: "Try a different keyword or clear your filters.",
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
          borderRadius: BorderRadius.circular(20),
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
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).dividerColor),
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
                    typeByKey(item['type'] ?? 'password').icon,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item["title"] ?? "Untitled",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (_subtitleForItem(item).trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _subtitleForItem(item),
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                      ],
                    ],
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
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          void updateFilters(VoidCallback update) {
            setState(update);
            setSheetState(() {});
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.78,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).dividerColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Filter results',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Item type',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ChoiceChip(
                            label: const Text('All'),
                            selected: _typeFilter == null,
                            onSelected: (_) =>
                                updateFilters(() => _typeFilter = null),
                          ),
                          ...itemTypes.map(
                            (type) => ChoiceChip(
                              label: Text(type.label),
                              selected: _typeFilter == type.key,
                              onSelected: (_) =>
                                  updateFilters(() => _typeFilter = type.key),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Category',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ChoiceChip(
                            label: const Text('All'),
                            selected: _categoryFilter == null,
                            onSelected: (_) =>
                                updateFilters(() => _categoryFilter = null),
                          ),
                          ...categories.map(
                            (category) => ChoiceChip(
                              label: Text(category.name),
                              selected: _categoryFilter == category.name,
                              onSelected: (_) => updateFilters(
                                () => _categoryFilter = category.name,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Favorites only'),
                        value: _favoritesOnly,
                        onChanged: (value) =>
                            updateFilters(() => _favoritesOnly = value),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('Done'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SearchLoadingState extends StatelessWidget {
  const _SearchLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (_, __) => const _SearchResultSkeleton(),
    );
  }
}

class _SearchResultSkeleton extends StatelessWidget {
  const _SearchResultSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
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
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 16,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}
