import 'package:flutter_test/flutter_test.dart';
import 'package:cantdecide/main.dart';

void main() {
  testWidgets('App renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const CantDecideApp());
    expect(find.text('Place your fingers'), findsOneWidget);
  });
}
