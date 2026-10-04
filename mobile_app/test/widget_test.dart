import 'package:flutter_test/flutter_test.dart';
import 'package:designbora/main.dart';

void main() {
  testWidgets('App inaanza bila kuvunjika', (WidgetTester tester) async {
    await tester.pumpWidget(const DesignBoraApp());
    expect(find.text('DesignBora'), findsWidgets);
  });
}
