import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morkva_crm/app/app.dart';

void main() {
  test('a mouse never drag-scrolls; touch, stylus and trackpad still do', () {
    // Owner (2026-11-12): on desktop/web, scrolling is by wheel or trackpad;
    // dragging with the mouse selects text and drags cards instead.
    final devices = const AppScrollBehavior().dragDevices;

    expect(devices, isNot(contains(PointerDeviceKind.mouse)));
    expect(
      devices,
      containsAll({
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      }),
    );
  });
}
