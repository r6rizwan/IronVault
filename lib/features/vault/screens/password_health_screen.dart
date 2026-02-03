import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/core/theme/app_tokens.dart';

class PasswordHealthScreen extends ConsumerStatefulWidget {
  const PasswordHealthScreen({super.key});

  @override
  ConsumerState<PasswordHealthScreen> createState() =>
      _PasswordHealthScreenState();
}

class _PasswordHealthScreenState extends ConsumerState<PasswordHealthScreen> {
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];

  static const int _minLength = 10;
  static const int _oldDays = 180;

  @override
  void initState() {
    super.initState();
    _load();
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

  bool _isWeak(String password) {
    if (password.length < _minLength) return true;

    var categories = 0;
    if (RegExp(r'[a-z]').hasMatch(password)) categories++;
    if (RegExp(r'[A-Z]').hasMatch(password)) categories++;
    if (RegExp(r'[0-9]').hasMatch(password)) categories++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) categories++;

    return categories < 3;
  }

  bool _isOld(DateTime? updatedAt, DateTime? createdAt) {
    final timestamp = updatedAt ?? createdAt;
    if (timestamp == null) return false;
    final cutoff = DateTime.now().subtract(const Duration(days: _oldDays));
    return timestamp.isBefore(cutoff);
  }

  Map<String, List<Map<String, dynamic>>> _reusedGroups() {
    final Map<String, List<Map<String, dynamic>>> map = {};
    for (final item in _items) {
      if ((item['type'] ?? 'password') != 'password') continue;
      final pwd = (item['password'] ?? '').toString();
      if (pwd.isEmpty) continue;
      map.putIfAbsent(pwd, () => []).add(item);
    }
    map.removeWhere((_, list) => list.length < 2);
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final passwordItems =
        _items.where((i) => (i['type'] ?? 'password') == 'password').toList();
    final reused = _reusedGroups();
    final weak = passwordItems.where(
      (i) => _isWeak((i['password'] ?? '').toString()),
    );
    final old = passwordItems.where(
      (i) => _isOld(i['updatedAt'] as DateTime?, i['createdAt'] as DateTime?),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Password Health')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _summaryCard(
                    context,
                    total: passwordItems.length,
                    weak: weak.length,
                    reused: reused.length,
                    old: old.length,
                  ),
                  const SizedBox(height: 16),
                  _sectionTitle('Weak Passwords'),
                  _buildList(
                    weak.toList(),
                    emptyText: 'No weak passwords found.',
                  ),
                  const SizedBox(height: 16),
                  _sectionTitle('Reused Passwords'),
                  _buildReused(reused),
                  const SizedBox(height: 16),
                  _sectionTitle('Old Passwords'),
                  _buildList(
                    old.toList(),
                    emptyText: 'No old passwords found.',
                  ),
                ],
              ),
            ),
    );
  }

  Widget _summaryCard(
    BuildContext context, {
    required int total,
    required int weak,
    required int reused,
    required int old,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            color: Colors.black12.withValues(alpha: 0.04),
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.health_and_safety, size: 18),
              SizedBox(width: 8),
              Text(
                'Overview',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statTile('Total', total.toString()),
              _statTile('Weak', weak.toString(), color: Colors.orange),
              _statTile('Reused', reused.toString(), color: Colors.redAccent),
              _statTile('Old', old.toString(), color: Colors.amber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color ?? Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppThemeColors.textMuted(context),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items,
      {required String emptyText}) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          emptyText,
          style: TextStyle(color: AppThemeColors.textMuted(context)),
        ),
      );
    }

    return Column(
      children: items.map((item) {
        final title = item['title'] ?? 'Untitled';
        final username = item['username'] ?? '';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                child: Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (username.toString().trim().isNotEmpty)
                      Text(
                        username,
                        style:
                            TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReused(Map<String, List<Map<String, dynamic>>> groups) {
    if (groups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          'No reused passwords found.',
          style: TextStyle(color: AppThemeColors.textMuted(context)),
        ),
      );
    }

    return Column(
      children: groups.entries.map((entry) {
        final items = entry.value;
        return ExpansionTile(
          tilePadding: EdgeInsets.zero,
          leading:
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
          title: Text('Used in ${items.length} items'),
          children: items.map((item) {
            final title = item['title'] ?? 'Untitled';
            final username = item['username'] ?? '';
            return ListTile(
              title: Text(title),
              subtitle: Text(username),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
