import 'package:flutter_test/flutter_test.dart';
import 'package:ironvault/core/constants/item_types.dart';

void main() {
  test('bank items expose an account type field for display and editing', () {
    final bankType = typeByKey('bank');
    final accountTypeField = bankType.fields.firstWhere(
      (field) => field.key == 'account_type',
      orElse: () => const FieldDefinition(key: '', label: ''),
    );

    expect(accountTypeField.key, 'account_type');
    expect(accountTypeField.label, 'Account Type');
  });
}
