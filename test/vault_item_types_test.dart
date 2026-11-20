// SPDX-FileCopyrightText: 2025-2026 Rizwan Mulla
// SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter_test/flutter_test.dart';
import 'package:ironvault/core/constants/item_types.dart';
import 'package:ironvault/core/utils/item_display_utils.dart';

void main() {
  test('new credential secrets are marked for masking', () {
    final sensitiveFields = {
      'wifi': 'wifi_password',
      'api_key': 'api_key_value',
      'recovery': 'recovery_material',
      'license': 'license_key',
    };

    for (final entry in sensitiveFields.entries) {
      final field = typeByKey(
        entry.key,
      ).fields.firstWhere((field) => field.key == entry.value);
      expect(field.obscure, isTrue, reason: entry.key);
    }
  });

  test('sensitive values are omitted from list subtitles and search', () {
    const secret = 'do-not-display-this-value';
    final item = {
      'type': 'api_key',
      'title': 'Production service',
      'fields': {'api_service': 'Example service', 'api_key_value': secret},
    };

    expect(itemSubtitleFor(item), isNot(contains(secret)));
    expect(searchableItemFieldValues(item), isNot(contains(secret)));
    expect(searchableItemFieldValues(item), contains('Example service'));
  });

  test('secure note contents are not used as a list subtitle', () {
    const privateText = 'private recovery phrase';
    final item = {
      'type': 'note',
      'fields': {'note': privateText},
    };

    expect(itemSubtitleFor(item), 'Secure note');
    expect(itemSubtitleFor(item), isNot(contains(privateText)));
  });
}
