// test/core/domain/card_layout_reconcile_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

void main() {
  group('CardLayout.synthesize', () {
    test('empty fields → empty layout', () {
      expect(CardLayout.synthesize(const []), const CardLayout());
    });

    test('each field becomes a full-width row in one section', () {
      final layout = CardLayout.synthesize(['a', 'b']);
      expect(layout.sections.length, 1);
      final section = layout.sections.single;
      expect(section.rows.map((r) => r.cells.single.fieldId), ['a', 'b']);
      expect(section.rows.every((r) => r.cells.single.span == 12), isTrue);
      expect(layout.fieldIds.toList(), ['a', 'b']);
    });
  });

  group('CardLayout.reconcile', () {
    final base = CardLayout(
      sections: [
        LayoutSection(id: 's1', rows: [
          LayoutRow(id: 'r1', cells: [
            LayoutCell(fieldId: 'a', span: 4),
            LayoutCell(fieldId: 'b', span: 8),
          ]),
        ]),
      ],
    );

    test('drops cells for removed fields and prunes empty rows', () {
      final out = base.reconcile(['b']); // 'a' removed
      expect(out.fieldIds.toList(), ['b']);
      expect(out.sections.single.rows.length, 1);
      expect(out.sections.single.rows.single.cells.single.span, 8); // 'b' kept
    });

    test('drops a whole row when all its fields are gone', () {
      final out = base.reconcile(const []); // both removed
      expect(out.fieldIds, isEmpty);
      expect(out.sections.single.rows, isEmpty); // section kept, rows pruned
    });

    test('appends new fields as full-width rows in the last section', () {
      final out = base.reconcile(['a', 'b', 'c']);
      expect(out.fieldIds.toList(), ['a', 'b', 'c']);
      final newRow = out.sections.single.rows.last;
      expect(newRow.cells.single.fieldId, 'c');
      expect(newRow.cells.single.span, 12);
    });

    test('synthesizes when there are fields but no sections', () {
      final out = const CardLayout().reconcile(['a']);
      expect(out.sections.length, 1);
      expect(out.fieldIds.toList(), ['a']);
    });

    test('preserves an intentionally empty section', () {
      final withEmpty = CardLayout(sections: [
        const LayoutSection(id: 's1', rows: [
          LayoutRow(id: 'r1', cells: [LayoutCell(fieldId: 'a')]),
        ]),
        const LayoutSection(id: 's2'), // empty, user-created
      ]);
      final out = withEmpty.reconcile(['a']);
      expect(out.sections.length, 2);
      expect(out.sections[1].rows, isEmpty);
    });
  });
}
