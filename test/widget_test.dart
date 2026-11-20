import 'package:flutter_test/flutter_test.dart';
import 'package:linkpc/app.dart';

void main() {
  testWidgets('LinkpcApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LinkpcApp());
    expect(find.byType(LinkpcApp), findsOneWidget);
  });
}
