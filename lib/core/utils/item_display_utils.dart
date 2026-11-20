// SPDX-FileCopyrightText: 2025-2026 Rizwan Mulla
// SPDX-License-Identifier: GPL-3.0-only
import 'dart:convert';

import 'package:ironvault/core/constants/item_types.dart';

String itemSubtitleFor(Map<String, dynamic> item) {
  final fields = (item['fields'] as Map?)?.cast<String, dynamic>() ?? {};
  switch ((item['type'] ?? 'password').toString()) {
    case 'password':
      return (fields['username'] ?? item['username'] ?? '').toString();
    case 'card':
      final number = (fields['number'] ?? '').toString().replaceAll(' ', '');
      if (number.isEmpty) return 'Card ••••';
      final last4 = number.length >= 4
          ? number.substring(number.length - 4)
          : number;
      return 'Card •••• $last4';
    case 'bank':
      final account = (fields['account_number'] ?? '').toString().replaceAll(
        ' ',
        '',
      );
      if (account.isEmpty) return 'Bank account';
      final last4 = account.length >= 4
          ? account.substring(account.length - 4)
          : account;
      return 'A/C •••• $last4';
    case 'document':
      final rawScans = (fields['scans'] ?? '').toString().trim();
      if (rawScans.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawScans);
          if (decoded is List && decoded.isNotEmpty) {
            return decoded.length == 1
                ? '1 scanned page'
                : '${decoded.length} scanned pages';
          }
        } on FormatException {
          return 'Saved document';
        }
      }

      return 'Saved document';
    case 'note':
      return 'Secure note';
    case 'wifi':
      return 'Wi-Fi network';
    case 'api_key':
      return 'API credential';
    case 'recovery':
      return 'Recovery codes / key';
    case 'license':
      return 'Software license';
    default:
      return '';
  }
}

Iterable<String> searchableItemFieldValues(Map<String, dynamic> item) sync* {
  final fields = (item['fields'] as Map?)?.cast<String, dynamic>() ?? {};
  final type = typeByKey((item['type'] ?? 'password').toString());
  for (final field in type.fields.where((field) => !field.obscure)) {
    final value = fields[field.key]?.toString();
    if (value != null && value.isNotEmpty) yield value;
  }
}
