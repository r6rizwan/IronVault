import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironvault/features/onboarding/screens/intro_carousel_screen.dart';

void main() {
  testWidgets('onboarding carousel renders first slide', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: IntroCarouselScreen(),
        ),
      ),
    );

    expect(find.text('Private by Default'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });
}
