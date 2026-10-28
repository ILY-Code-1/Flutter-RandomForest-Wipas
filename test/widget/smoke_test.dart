import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  testWidgets('admin lands on Beranda with seeded data', (tester) async {
    await pumpApp(tester);
    expect(find.text('Hub Cakung (WH-CKG-01)'), findsOneWidget);
    expect(find.text('18.420'), findsWidgets);
    expect(find.text('Deviasi 15,8% melewati ambang 15%'), findsOneWidget);
  });
}
