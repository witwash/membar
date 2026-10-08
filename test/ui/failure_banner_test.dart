import 'package:flutter_test/flutter_test.dart';
import 'package:membar/ui/ui.dart';

import '../helpers/helpers.dart';

void main() {
  group('FailureBanner', () {
    testWidgets('renders the message it was given', (tester) async {
      await tester.pumpApp(const FailureBanner('Nope.'));

      expect(find.text('Nope.'), findsOneWidget);
    });
  });
}
