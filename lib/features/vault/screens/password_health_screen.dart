import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/core/theme/app_tokens.dart';
import 'package:ironvault/features/vault/screens/credential_list_screen.dart';

class PasswordHealthScreen extends ConsumerStatefulWidget {
  const PasswordHealthScreen({super.key});

  @override
  ConsumerState<PasswordHealthScreen> createState() =>
      _PasswordHealthScreenState();
}

class _PasswordHealthScreenState extends ConsumerState<PasswordHealthScreen> {
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];
  late final ProviderSubscription<int> _refreshSub;

  static const int _minLength = 10;
  static const int _oldDays = 180;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshSub = ref.listenManual<int>(
      vaultRefreshProvider,
      (_, __) => _load(),
    );
  }

  @override
  void dispose() {
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

  Map<String, List<Map<String, dynamic>>> _reusedGroups(
    List<Map<String, dynamic>> passwordItems,
  ) {
    final Map<String, List<Map<String, dynamic>>> map = {};
    for (final item in passwordItems) {
      final pwd = (item['password'] ?? '').toString();
      if (pwd.isEmpty) continue;
      map.putIfAbsent(pwd, () => []).add(item);
    }
    map.removeWhere((_, list) => list.length < 2);
    return map;
  }

  void _openAffectedItems({
    required String title,
    required List<Map<String, dynamic>> items,
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CredentialListScreen(
          titleOverride: title,
          itemIdFilter: items.map((item) => (item['id'] ?? '').toString()).toSet(),
          emptyTitle: emptyTitle,
          emptySubtitle: emptySubtitle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final passwordItems =
        _items.where((i) => (i['type'] ?? 'password') == 'password').toList();
    final reusedGroups = _reusedGroups(passwordItems);
    final weakItems = passwordItems
        .where((i) => _isWeak((i['password'] ?? '').toString()))
        .toList();
    final oldItems = passwordItems
        .where(
          (i) => _isOld(i['updatedAt'] as DateTime?, i['createdAt'] as DateTime?),
        )
        .toList();
    final reusedItems = reusedGroups.values.expand((group) => group).toList();
    final total = passwordItems.length;
    final hasPasswords = total > 0;
    final score = total == 0
        ? 0
        : (100 -
                ((weakItems.length / total) * 40) -
                ((reusedItems.length / total) * 35) -
                ((oldItems.length / total) * 25))
            .round()
            .clamp(0, 100);
    final scoreColor = score >= 80
        ? const Color(0xFF10B981)
        : score >= 60
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    final issueCards = [
      _HealthIssueData(
        title: 'Weak Passwords',
        description: 'Passwords that are short or easy to guess.',
        count: weakItems.length,
        color: Colors.orange,
        icon: Icons.password_rounded,
        items: weakItems,
        actionLabel: 'Review ${weakItems.length} item${weakItems.length == 1 ? '' : 's'}',
        emptyTitle: 'No weak passwords',
        emptySubtitle: 'Your saved passwords are meeting the current strength rules.',
      ),
      _HealthIssueData(
        title: 'Reused Passwords',
        description: 'The same password appears in multiple saved items.',
        count: reusedItems.length,
        color: Colors.redAccent,
        icon: Icons.content_copy_rounded,
        items: reusedItems,
        actionLabel: 'Review ${reusedItems.length} item${reusedItems.length == 1 ? '' : 's'}',
        emptyTitle: 'No reused passwords',
        emptySubtitle: 'Each saved password currently appears unique.',
      ),
      _HealthIssueData(
        title: 'Old Passwords',
        description: 'Passwords older than $_oldDays days that may need rotation.',
        count: oldItems.length,
        color: Colors.amber.shade700,
        icon: Icons.history_toggle_off_rounded,
        items: oldItems,
        actionLabel: 'Review ${oldItems.length} item${oldItems.length == 1 ? '' : 's'}',
        emptyTitle: 'No old passwords',
        emptySubtitle: 'No saved passwords are currently flagged as aging.',
      ),
    ];

    final topPriority = issueCards
        .where((issue) => issue.count > 0)
        .fold<_HealthIssueData?>(null, (best, current) {
      if (best == null) return current;
      return current.count > best.count ? current : best;
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Password Health')),
      body: _loading
          ? const _PasswordHealthLoadingState()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _scoreCard(
                    context,
                    score: score,
                    scoreColor: scoreColor,
                    total: total,
                    hasPasswords: hasPasswords,
                    weak: weakItems.length,
                    reused: reusedItems.length,
                    old: oldItems.length,
                  ),
                  const SizedBox(height: 16),
                  if (!hasPasswords) ...[
                    _noPasswordsStateCard(),
                    const SizedBox(height: 16),
                  ] else if (topPriority != null) ...[
                    _priorityCard(topPriority),
                    const SizedBox(height: 16),
                  ] else ...[
                    _healthyStateCard(),
                    const SizedBox(height: 16),
                  ],
                  for (final issue in issueCards) ...[
                    _issueCard(issue),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _scoreCard(
    BuildContext context, {
    required int score,
    required Color scoreColor,
    required int total,
    required bool hasPasswords,
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
                'Security Score',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Text(
                      hasPasswords ? score.toString() : '--',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: scoreColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Score',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppThemeColors.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  !hasPasswords
                      ? 'Add passwords to see your score.'
                      : 'Review weak, reused, and old passwords from one place.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppThemeColors.textMuted(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metricChip('Total', total.toString()),
              _metricChip('Weak', weak.toString(), color: Colors.orange),
              _metricChip('Reused', reused.toString(), color: Colors.redAccent),
              _metricChip('Old', old.toString(), color: Colors.amber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String label, String value, {Color? color}) {
    final textColor = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppThemeColors.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priorityCard(_HealthIssueData issue) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: issue.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: issue.color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Priority',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: issue.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            issue.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '${issue.count} affected item${issue.count == 1 ? '' : 's'} need attention first.',
            style: TextStyle(color: AppThemeColors.textMuted(context)),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _openAffectedItems(
              title: issue.title,
              items: issue.items,
              emptyTitle: issue.emptyTitle,
              emptySubtitle: issue.emptySubtitle,
            ),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Fix this first'),
          ),
        ],
      ),
    );
  }

  Widget _healthyStateCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your passwords look healthy',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'No weak, reused, or aging passwords need attention right now.',
                  style: TextStyle(color: AppThemeColors.textMuted(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _noPasswordsStateCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add passwords to see health',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Password Health becomes available after you store password items in your vault.',
                  style: TextStyle(color: AppThemeColors.textMuted(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _issueCard(_HealthIssueData issue) {
    final previewItems = issue.items.take(3).toList();
    final hasIssues = issue.count > 0;

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
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: issue.color.withValues(alpha: 0.12),
                child: Icon(issue.icon, color: issue.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      issue.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      issue.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppThemeColors.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              _metricChip('Items', issue.count.toString(), color: issue.color),
            ],
          ),
          if (hasIssues) ...[
            const SizedBox(height: 14),
            for (final item in previewItems) ...[
              _previewRow(item),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _openAffectedItems(
                  title: issue.title,
                  items: issue.items,
                  emptyTitle: issue.emptyTitle,
                  emptySubtitle: issue.emptySubtitle,
                ),
                child: Text(issue.actionLabel),
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Text(
              issue.emptySubtitle,
              style: TextStyle(color: AppThemeColors.textMuted(context)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _previewRow(Map<String, dynamic> item) {
    final title = (item['title'] ?? 'Untitled').toString();
    final username = (item['username'] ?? '').toString().trim();
    return Row(
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (username.isNotEmpty)
                Text(
                  username,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppThemeColors.textMuted(context),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HealthIssueData {
  final String title;
  final String description;
  final int count;
  final Color color;
  final IconData icon;
  final List<Map<String, dynamic>> items;
  final String actionLabel;
  final String emptyTitle;
  final String emptySubtitle;

  const _HealthIssueData({
    required this.title,
    required this.description,
    required this.count,
    required this.color,
    required this.icon,
    required this.items,
    required this.actionLabel,
    required this.emptyTitle,
    required this.emptySubtitle,
  });
}

class _PasswordHealthLoadingState extends StatelessWidget {
  const _PasswordHealthLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: const [
        _PasswordHealthScoreSkeleton(),
        SizedBox(height: 16),
        _PasswordHealthSectionSkeleton(),
        SizedBox(height: 16),
        _PasswordHealthSectionSkeleton(),
        SizedBox(height: 16),
        _PasswordHealthSectionSkeleton(),
      ],
    );
  }
}

class _PasswordHealthScoreSkeleton extends StatelessWidget {
  const _PasswordHealthScoreSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    Widget bar(double width, double height) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

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
          bar(130, 16),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 88,
                height: 42,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: bar(double.infinity, 12)),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(
              4,
              (_) => Container(
                width: 72,
                height: 30,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordHealthSectionSkeleton extends StatelessWidget {
  const _PasswordHealthSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

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
        children: List.generate(
          4,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index == 3 ? 0 : 12),
            child: Container(
              height: index == 0 ? 16 : 44,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
