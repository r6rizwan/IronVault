import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ironvault/core/widgets/empty_state.dart';

class MigrationLogScreen extends StatefulWidget {
  const MigrationLogScreen({super.key});

  @override
  State<MigrationLogScreen> createState() => _MigrationLogScreenState();
}

class _MigrationLogScreenState extends State<MigrationLogScreen> {
  String? _log;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLog();
  }

  Future<void> _loadLog() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/migration.log');
    if (await file.exists()) {
      _log = await file.readAsString();
    } else {
      _log = '';
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Migration Log')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_log == null || _log!.trim().isEmpty)
              ? const EmptyState(
                  icon: Icons.history,
                  title: 'No migrations yet',
                  subtitle: 'Nothing has been migrated on this device.',
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Text(
                      _log!,
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ),
    );
  }
}
