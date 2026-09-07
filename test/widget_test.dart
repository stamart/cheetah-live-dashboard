import 'package:flutter_test/flutter_test.dart';

import 'package:cheetah_live_dashboard/main.dart';

void main() {
  testWidgets('App builds and shows the setup screen', (WidgetTester tester) async {
    await tester.pumpWidget(const CheetahLiveDashboardApp());
    await tester.pump();

    expect(find.text('Cheetah Live Dashboard'), findsOneWidget);
    expect(find.text('Połącz'), findsOneWidget);
  });
}
