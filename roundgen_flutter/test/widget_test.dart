import 'package:flutter_test/flutter_test.dart';
import 'package:roundgen_flutter/src/app.dart';

void main() {
  testWidgets('ROUNDGEN login renders', (tester) async {
    await tester.pumpWidget(const RoundgenApp());

    expect(find.text('ROUNDGEN'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
