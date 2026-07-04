import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:ironvault/core/providers.dart';
import 'package:ironvault/core/secure_storage.dart';
import 'package:ironvault/features/auth/screens/setup_master_pin_screen.dart';

@GenerateNiceMocks([MockSpec<SecureStorage>()])
import 'auth_screens_test.mocks.dart';

void main() {
  testWidgets('SetupMasterPinScreen renders title and input fields', (
    WidgetTester tester,
  ) async {
    final mockStorage = MockSecureStorage();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [secureStorageProvider.overrideWithValue(mockStorage)],
        child: const MaterialApp(home: SetupMasterPinScreen()),
      ),
    );

    expect(find.text('Create Master PIN'), findsOneWidget);
    expect(find.text('Enter PIN'), findsOneWidget);
    expect(find.text('Confirm PIN'), findsOneWidget);
  });
}
