import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_student_productivity_app/main.dart';

void main() {
  // Gracefully handles native framework channel methods in test environments
  TestWidgetsFlutterBinding.ensureInitialized();

  group('App Bootstrapping Tests', () {
    testWidgets(
        'Should display Error Screen when Firebase fails initialization',
        (WidgetTester tester) async {
      // 1. Build the app with initialized state explicitly set to false
      await tester.pumpWidget(const MyApp(isFirebaseInitialized: false));

      // 2. Allow the frame layout to settle down
      await tester.pumpAndSettle();

      // 3. Verify that the network connection/error state UI is displayed
      expect(find.byKey(const Key('fb_init_error')), findsOneWidget);
      expect(find.text('Connection Error'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets(
        'Should render AuthGate loading state when Firebase initializes successfully',
        (WidgetTester tester) async {
      // 1. Build the app with initialization set to true
      await tester.pumpWidget(const MyApp(isFirebaseInitialized: true));

      // 2. Pump a frame to catch the initial state of the AuthGate StreamBuilder
      await tester.pump();

      // 3. Verify it shows the loading spinner inside AuthGate before stream resolves
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
