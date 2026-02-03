import 'package:flutter/material.dart';

const Map<String, IconData> presetIcons = {
  'lock': Icons.lock_rounded,
  'credit_card': Icons.credit_card_rounded,
  'note': Icons.note_alt_rounded,
  'id': Icons.badge_rounded,
  'bank': Icons.account_balance,
  'email': Icons.email_outlined,
  'web': Icons.language_rounded,
  'other': Icons.folder_rounded,
};

const List<Color> presetColors = [
  Color(0xFF3B82F6), // blue
  Color(0xFF8B5CF6), // purple
  Color(0xFFF97316), // orange
  Color(0xFF10B981), // green
  Color(0xFFEF4444), // red
  Color(0xFF06B6D4), // teal
];

IconData iconForKey(String key) => presetIcons[key] ?? Icons.folder_rounded;
