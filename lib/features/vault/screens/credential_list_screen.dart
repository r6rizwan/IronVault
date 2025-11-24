// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/features/settings/screens/settings_screen.dart';

import 'package:ironvault/core/providers.dart';
import '../../auth/screens/login_screen.dart';
import 'add_credential_screen.dart';
import 'view_credential_screen.dart';

import 'package:ironvault/features/vault/providers/search_provider.dart';
import 'package:ironvault/core/widgets/search_bar.dart';

enum SortOption { favoritesFirst, aToZ, zToA, recentAdded, recentUpdated }

class CredentialListScreen extends ConsumerStatefulWidget {
  const CredentialListScreen({super.key});

  @override
  ConsumerState<CredentialListScreen> createState() =>
      _CredentialListScreenState();
}

class _CredentialListScreenState extends ConsumerState<CredentialListScreen> {
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];

  SortOption _sortBy = SortOption.favoritesFirst;

  final searchController = TextEditingController();

  /// ⭐ GLOBAL KEY to control the search bar (expand/collapse)
  final GlobalKey<IronSearchBarState> _searchBarKey =
      GlobalKey<IronSearchBarState>();

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCredentials() async {
    setState(() => _loading = true);

    final repo = ref.read(credentialRepoProvider);
    final data = await repo.getAllDecrypted();

    _items = data;
    _applySorting();

    setState(() => _loading = false);
  }

  void _applySorting() {
    switch (_sortBy) {
      case SortOption.favoritesFirst:
        _items.sort((a, b) {
          final favA = a["isFavorite"] == true;
          final favB = b["isFavorite"] == true;
          if (favA && !favB) return -1;
          if (!favA && favB) return 1;
          return a["title"].toLowerCase().compareTo(b["title"].toLowerCase());
        });
        break;

      case SortOption.aToZ:
        _items.sort(
          (a, b) =>
              a["title"].toLowerCase().compareTo(b["title"].toLowerCase()),
        );
        break;

      case SortOption.zToA:
        _items.sort(
          (a, b) =>
              b["title"].toLowerCase().compareTo(a["title"].toLowerCase()),
        );
        break;

      case SortOption.recentAdded:
        _items.sort((a, b) => b["createdAt"].compareTo(a["createdAt"]));
        break;

      case SortOption.recentUpdated:
        _items.sort((a, b) => b["updatedAt"].compareTo(a["updatedAt"]));
        break;
    }
  }

  Future<void> _toggleFavorite(Map<String, dynamic> item) async {
    final repo = ref.read(credentialRepoProvider);
    final newState = !(item["isFavorite"] == true);

    await repo.toggleFavorite(item["id"], newState);
    await _loadCredentials();
  }

  Future<void> _logout() async {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _openSortSheet() {
    _searchBarKey.currentState
        ?.collapse(); // also collapse search when opening sheet

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 14),
              _buildSortTile(
                ctx,
                "Favorites First",
                SortOption.favoritesFirst,
                Icons.star,
                Colors.amber,
              ),
              _buildSortTile(
                ctx,
                "A → Z",
                SortOption.aToZ,
                Icons.sort_by_alpha,
                Colors.blue,
              ),
              _buildSortTile(
                ctx,
                "Z → A",
                SortOption.zToA,
                Icons.sort_by_alpha,
                Colors.blue,
              ),
              _buildSortTile(
                ctx,
                "Recently Added",
                SortOption.recentAdded,
                Icons.fiber_new,
                Colors.green,
              ),
              _buildSortTile(
                ctx,
                "Recently Updated",
                SortOption.recentUpdated,
                Icons.update,
                Colors.green,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  ListTile _buildSortTile(
    BuildContext ctx,
    String text,
    SortOption option,
    IconData icon,
    Color highlight,
  ) {
    return ListTile(
      title: Text(text),
      leading: Icon(icon, color: _sortBy == option ? highlight : null),
      onTap: () {
        setState(() {
          _sortBy = option;
          _applySorting();
        });
        Navigator.pop(ctx);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);

    final filteredItems = _items.where((item) {
      final q = query.toLowerCase();

      return (item["title"]?.toLowerCase().contains(q) ?? false) ||
          (item["username"]?.toLowerCase().contains(q) ?? false) ||
          (item["email"]?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          "Passwords",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        shape: const CircleBorder(),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddCredentialScreen()),
          );
          await _loadCredentials();
        },
        child: const Icon(Icons.add, size: 28),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              /// collapse search when tapping outside
              onTap: () {
                FocusScope.of(context).unfocus();
                _searchBarKey.currentState?.collapse();
              },
              behavior: HitTestBehavior.translucent,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    /// 🔍 SEARCH BAR + SORT CHIP
                    Row(
                      children: [
                        Expanded(
                          child: IronSearchBar(
                            key: _searchBarKey,
                            controller: searchController,
                            onChanged: (value) {
                              ref.read(searchQueryProvider.notifier).state =
                                  value.trim().toLowerCase();
                            },
                            onSortPressed: _openSortSheet,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    /// empty state
                    if (filteredItems.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text(
                            "No passwords found.",
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: filteredItems.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, index) {
                            final item = filteredItems[index];
                            final isFav = item["isFavorite"] == true;

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).cardColor.withOpacity(0.95),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                    color: Colors.black12.withOpacity(0.05),
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () async {
                                  final _ = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ViewCredentialScreen(item: item),
                                    ),
                                  );
                                  if (mounted) await _loadCredentials();
                                },
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.blueAccent,
                                      child: const Icon(
                                        Icons.lock,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item["title"],
                                                  style: const TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              if (isFav)
                                                const Icon(
                                                  Icons.star,
                                                  color: Colors.amber,
                                                  size: 18,
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item["username"],
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    IconButton(
                                      onPressed: () => _toggleFavorite(item),
                                      icon: Icon(
                                        isFav
                                            ? Icons.star_rounded
                                            : Icons.star_border_rounded,
                                        color: isFav
                                            ? Colors.amber
                                            : Colors.grey,
                                        size: 26,
                                      ),
                                    ),

                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  // ignore: unused_element
  String _sortLabel() {
    switch (_sortBy) {
      case SortOption.favoritesFirst:
        return "Favorites";
      case SortOption.aToZ:
        return "A → Z";
      case SortOption.zToA:
        return "Z → A";
      case SortOption.recentAdded:
        return "Recent";
      case SortOption.recentUpdated:
        return "Updated";
    }
  }
}
