// test/core/domain/card_layout_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

void main() {
  group('LayoutCell', () {
    test('clamps span into 1..12', () {
      expect(LayoutCell(fieldId: 'f1', span: 0).span, 1);
      expect(LayoutCell(fieldId: 'f1', span: 99).span, 12);
      expect(LayoutCell(fieldId: 'f1', span: 5).span, 5);
      expect(LayoutCell(fieldId: 'f1').span, 12); // default full width
    });

    test('JSON round-trips', () {
      final cell = LayoutCell(fieldId: 'f1', span: 4);
      expect(LayoutCell.fromJson(cell.toJson()), cell);
    });

    test('fromJson defaults a missing span to full width', () {
      expect(LayoutCell.fromJson({'fieldId': 'f1'}).span, 12);
    });
  });

  group('CardLayout', () {
    final layout = const CardLayout(
      sections: [
        LayoutSection(
          id: 's1',
          title: 'Main',
          rows: [
            LayoutRow(id: 'r1', cells: [
              LayoutCell(fieldId: 'a', span: 2),
              LayoutCell(fieldId: 'b', span: 10),
            ]),
            LayoutRow(id: 'r2', cells: [LayoutCell(fieldId: 'c')]),
          ],
        ),
      ],
    );

    test('fieldIds yields every cell in document order', () {
      expect(layout.fieldIds.toList(), ['a', 'b', 'c']);
    });

    test('JSON round-trips the whole tree', () {
      expect(CardLayout.fromJson(layout.toJson()), layout);
    });

    test('section title can be cleared to null via copyWith', () {
      final s = const LayoutSection(id: 's1', title: 'X');
      expect(s.copyWith(title: null).title, isNull);
      expect(s.copyWith().title, 'X'); // omitted = preserved
    });
  });
}
