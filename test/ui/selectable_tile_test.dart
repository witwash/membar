import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:membar/ui/ui.dart';

import '../helpers/helpers.dart';

void main() {
  group('SelectableTile', () {
    late List<String> presses;

    setUp(() => presses = []);

    SelectableTile tile(
      String title, {
      String? subtitle,
      String? badge,
      bool selected = false,
    }) => SelectableTile(
      title: title,
      subtitle: subtitle,
      badge: badge,
      selected: selected,
      onPress: () => presses.add(title),
    );

    // As on the catalog page: a stretched column gives the tile the width
    // and lets it size its own height.
    Future<void> pumpTile(WidgetTester tester, SelectableTile tile) =>
        tester.pumpApp(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [tile],
          ),
        );

    Future<void> pumpGroup(WidgetTester tester) => tester.pumpApp(
      Column(
        children: [
          Expanded(
            child: FTileGroup.builder(
              count: 2,
              tileBuilder: (context, index) =>
                  tile(index == 0 ? 'Negroni' : 'Daiquiri', subtitle: 'Gin'),
            ),
          ),
        ],
      ),
    );

    Finder checkboxOf(String title) => find.descendant(
      of: find.ancestor(of: find.text(title), matching: find.byType(FTile)),
      matching: find.byType(FCheckbox),
    );

    Future<void> tapCenter(WidgetTester tester, Finder finder) async {
      await tester.tapAt(tester.getCenter(finder));
      await tester.pumpAndSettle();
    }

    String? focusedTitle() => FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<SelectableTile>()
        ?.title;

    bool focusInCheckbox() =>
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<FCheckbox>() !=
        null;

    testWidgets(
      'inside a tile group, a checkbox tap presses only its own tile, once',
      (tester) async {
        await pumpGroup(tester);
        // The group's own press routing is what used to swallow the tap.
        expect(find.byType(FTappableGroup), findsOneWidget);

        await tapCenter(tester, checkboxOf('Daiquiri'));

        expect(presses, ['Daiquiri']);
      },
    );

    testWidgets('outside any group, a checkbox tap presses the tile once', (
      tester,
    ) async {
      await pumpTile(tester, tile('Select all'));

      await tapCenter(tester, find.byType(FCheckbox));

      expect(presses, ['Select all']);
    });

    testWidgets('presses from its title, subtitle and blank right edge', (
      tester,
    ) async {
      await pumpTile(tester, tile('Negroni', subtitle: 'Gin'));

      await tapCenter(tester, find.text('Negroni'));
      await tapCenter(tester, find.text('Gin'));
      final rect = tester.getRect(find.byType(FTile));
      await tester.tapAt(Offset(rect.right - 2, rect.center.dy));
      await tester.pumpAndSettle();

      expect(presses, ['Negroni', 'Negroni', 'Negroni']);
    });

    testWidgets(
      'inside a tile group, Tab moves tile to tile without stopping on a '
      'checkbox, and Enter presses the focused tile',
      (tester) async {
        await pumpGroup(tester);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(focusedTitle(), 'Negroni');
        expect(focusInCheckbox(), isFalse);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(focusedTitle(), 'Daiquiri');
        expect(focusInCheckbox(), isFalse);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(presses, ['Daiquiri']);
      },
    );

    testWidgets('reads as one label and reports its selected state', (
      tester,
    ) async {
      await pumpTile(
        tester,
        tile('Negroni', subtitle: 'Gin', badge: 'In library', selected: true),
      );

      expect(
        tester.getSemantics(find.text('Negroni')),
        isSemantics(label: 'Negroni, Gin, In library', isSelected: true),
      );
    });

    testWidgets('leaves a null subtitle and badge out of its label', (
      tester,
    ) async {
      await pumpTile(tester, tile('Negroni'));

      expect(
        tester.getSemantics(find.text('Negroni')),
        isSemantics(label: 'Negroni', isSelected: false),
      );
    });

    testWidgets('neither renders nor reads an empty subtitle', (tester) async {
      await pumpTile(tester, tile('Negroni', subtitle: ''));

      expect(tester.getSemantics(find.text('Negroni')).label, 'Negroni');
      expect(
        find.descendant(of: find.byType(FTile), matching: find.byType(Text)),
        findsOneWidget,
      );
    });

    testWidgets('ticks its checkbox when selected', (tester) async {
      await pumpTile(tester, tile('Negroni', selected: true));
      expect(tester.widget<FCheckbox>(find.byType(FCheckbox)).value, isTrue);

      await pumpTile(tester, tile('Negroni'));
      expect(tester.widget<FCheckbox>(find.byType(FCheckbox)).value, isFalse);
    });
  });
}
