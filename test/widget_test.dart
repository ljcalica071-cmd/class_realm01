import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/main.dart';

void main() {
  testWidgets('ClassRealm smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ClassRealmApp());
    expect(find.byType(ClassRealmApp), findsOneWidget);
  });
}
