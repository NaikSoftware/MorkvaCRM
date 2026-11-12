import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/core/automation/run_queue.dart';

void main() {
  test('manual runs wait ahead of event runs, each kind in arrival order', () {
    final q = RunQueue<String>()
      ..add('e1', manual: false)
      ..add('e2', manual: false)
      ..add('b1', manual: true)
      ..add('b2', manual: true);
    expect(q.waiting, ['b1', 'b2', 'e1', 'e2']);
    expect(q.next(), 'b1');
    // An event caused by b1's commit lands at the tail (breadth-first).
    q.add('e3', manual: false);
    expect(q.waiting, ['b2', 'e1', 'e2', 'e3']);
  });

  test('one run holds the slot until it is released', () {
    final q = RunQueue<String>()
      ..add('a', manual: false)
      ..add('b', manual: false);
    expect(q.next(), 'a');
    expect(q.busy, isTrue);
    expect(q.next(), isNull, reason: 'serial');
    q.release('b'); // not the holder: nothing changes
    expect(q.current, 'a');
    q.release('a');
    expect(q.next(), 'b');
  });

  test('ahead counts the holder; remove, removeWhere and count', () {
    final q = RunQueue<String>()
      ..add('a', manual: false)
      ..add('b', manual: false)
      ..add('c', manual: false)
      ..add('d', manual: true);
    expect(q.ahead('b'), 2);
    q.next(); // d
    expect(q.ahead('a'), 1);
    expect(q.ahead('c'), 3);
    expect(q.ahead('d'), isNull, reason: 'running, not waiting');
    expect(q.remove('b'), isTrue);
    expect(q.remove('b'), isFalse);
    expect(q.count((r) => r != 'a'), 1);
    expect(q.removeWhere((r) => r == 'c'), ['c']);
    expect(q.length, 1);
    q.clear();
    expect(q.busy, isFalse);
    expect(q.waiting, isEmpty);
  });
}
