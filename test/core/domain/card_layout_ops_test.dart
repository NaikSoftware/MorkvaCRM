import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/domain/domain.dart';

CardLayout twoFieldRow() => CardLayout(sections: [
      LayoutSection(id: 's1', rows: [
        LayoutRow(id: 'r1', cells: [
          LayoutCell(fieldId: 'a', span: 6),
          LayoutCell(fieldId: 'b', span: 6),
        ]),
      ]),
    ]);

void main() {
  group('setCellSpan', () {
    test('growing one cell shrinks its row neighbour to keep sum ≤ 12', () {
      final out = twoFieldRow().setCellSpan('r1', 'a', 9);
      final cells = out.sections.single.rows.single.cells;
      expect(cells[0].span, 9);
      expect(cells[1].span, 3); // donor shrank from 6 → 3
    });

    test('a 2-cell row caps the target at 11 (other keeps ≥ 1)', () {
      final out = twoFieldRow().setCellSpan('r1', 'a', 12);
      final cells = out.sections.single.rows.single.cells;
      expect(cells[0].span, 11);
      expect(cells[1].span, 1);
    });

    test('shrinking leaves leftover empty space (sum < 12 allowed)', () {
      final out = twoFieldRow().setCellSpan('r1', 'a', 2);
      final cells = out.sections.single.rows.single.cells;
      expect(cells[0].span, 2);
      expect(cells[1].span, 6); // untouched
    });
  });

  group('moveCellToRow / moveCellToNewRow', () {
    test('moveCellToNewRow detaches into its own full-width row', () {
      final out = twoFieldRow().moveCellToNewRow('b', 's1', 0, 'rNew');
      final rows = out.sections.single.rows;
      expect(rows.first.id, 'rNew');
      expect(rows.first.cells.single.fieldId, 'b');
      expect(rows.first.cells.single.span, 12);
      // 'a' alone in the old row
      expect(rows.last.cells.map((c) => c.fieldId), ['a']);
      expect(out.fieldIds.toSet(), {'a', 'b'});
    });

    test('moveCellToRow normalizes the target row to ≤ 12', () {
      final layout = CardLayout(sections: [
        LayoutSection(id: 's1', rows: [
          LayoutRow(id: 'r1', cells: [LayoutCell(fieldId: 'a', span: 12)]),
          LayoutRow(id: 'r2', cells: [LayoutCell(fieldId: 'b', span: 12)]),
        ]),
      ]);
      final out = layout.moveCellToRow('b', 'r1', 1);
      final r1 = out.sections.single.rows.firstWhere((r) => r.id == 'r1');
      expect(r1.cells.map((c) => c.fieldId), ['a', 'b']);
      expect(r1.cells.fold<int>(0, (s, c) => s + c.span) <= 12, isTrue);
      // r2 emptied → pruned
      expect(out.sections.single.rows.length, 1);
    });
  });

  group('sections', () {
    test('addSection appends an empty section', () {
      final out = twoFieldRow().addSection('s2', title: 'More');
      expect(out.sections.map((s) => s.id), ['s1', 's2']);
      expect(out.sections.last.title, 'More');
      expect(out.sections.last.rows, isEmpty);
    });

    test('renameSection blanks to null', () {
      final out = twoFieldRow().addSection('s2', title: 'X').renameSection('s2', '  ');
      expect(out.sections.last.title, isNull);
    });

    test('toggleSectionCollapsed flips the flag', () {
      final out = twoFieldRow().toggleSectionCollapsed('s1');
      expect(out.sections.single.collapsed, isTrue);
    });

    test('deleteSection re-homes rows into the previous section', () {
      final layout = twoFieldRow().addSection('s2').moveRowToSection('r1', 's2', 0);
      // r1 now lives in s2; deleting s2 sends it back to s1
      final out = layout.deleteSection('s2');
      expect(out.sections.map((s) => s.id), ['s1']);
      expect(out.fieldIds.toSet(), {'a', 'b'});
    });

    test('deleteSection is a no-op when only one section remains', () {
      final out = twoFieldRow().deleteSection('s1');
      expect(out.sections.length, 1);
    });
  });
}
