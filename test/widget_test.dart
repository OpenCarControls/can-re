import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:can_re/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: OpenCarControlsApp()));

    // Verify that the title is present
    expect(find.text('OpenCarControls CAN RE'), findsOneWidget);
  });
}
