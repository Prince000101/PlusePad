import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pulsepad/models/control_slot.dart';
import 'package:pulsepad/services/layout_store.dart';

ControlSlot s(String id, String action) => ControlSlot(
    id: id,
    kind: 'button',
    x: 0.5,
    y: 0.5,
    w: 0.1,
    h: 0.1,
    label: id,
    action: action);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SlotAction', () {
    test('round-trips namespaced wire values', () {
      final pad = SlotAction.parse('pad:A');
      expect(pad.type, SlotActionType.pad);
      expect(pad.name, 'A');
      expect(pad.wire, 'pad:A');

      expect(SlotAction.parse('key:SPACE').type, SlotActionType.key);
      expect(SlotAction.parse('key:SPACE').name, 'SPACE');
      expect(SlotAction.parse('mouse:RMB').type, SlotActionType.mouse);
      expect(SlotAction.parse('mouse:RMB').name, 'RMB');
    });

    test('classifies legacy plain actions', () {
      expect(SlotAction.parse('A').type, SlotActionType.pad);
      expect(SlotAction.parse('A').name, 'A');
      expect(SlotAction.parse('W').type, SlotActionType.key);
      expect(SlotAction.parse('W').name, 'W');
      expect(SlotAction.parse('LMB').type, SlotActionType.mouse);
      expect(SlotAction.parse('LMB').name, 'LMB');
    });

    test('maps legacy trigger/bumper aliases to protocol names', () {
      expect(SlotAction.parse('LT').wire, 'pad:L2');
      expect(SlotAction.parse('LB').wire, 'pad:L1');
      expect(SlotAction.parse('RT').wire, 'pad:R2');
      expect(SlotAction.parse('RB').wire, 'pad:R1');
    });

    test('face A stays a pad action, hyphen-free keys stay keys', () {
      expect(SlotAction.parse('A').wire, 'pad:A');
      expect(SlotAction.parse('B').wire, 'pad:B');
      expect(SlotAction.parse('W').wire, 'key:W');
      expect(SlotAction.parse('S').wire, 'key:S');
      expect(SlotAction.parse('D').wire, 'key:D');
      expect(SlotAction.parse('SPACE').wire, 'key:SPACE');
      expect(SlotAction.parse('DPAD_UP').wire, 'pad:DPAD_UP');
    });
  });

  group('LayoutStore v2', () {
    test('migrates a legacy v1 blob and normalises actions', () async {
      final v1 = jsonEncode({
        'name': 'My Custom',
        'slots': [
          s('k', 'W').toJson(),
          s('m', 'LMB').toJson(),
          s('g', 'LT').toJson(),
          s('p', 'A').toJson(),
        ],
      });
      SharedPreferences.setMockInitialValues({'pulsepad.custom_layout.v1': v1});

      final store = LayoutStore();
      await store.load();

      expect(store.hasCustom, isTrue);
      expect(store.layouts, hasLength(1));
      expect(store.active!.name, 'My Custom');

      final actions = store.active!.slots.map((x) => x.action).toList();
      expect(actions, ['key:W', 'mouse:LMB', 'pad:L2', 'pad:A']);
    });

    test('CRUD + activate keep state consistent', () async {
      SharedPreferences.setMockInitialValues({});
      final store = LayoutStore();
      await store.load();
      expect(store.hasCustom, isFalse);

      final a = CustomLayout(id: CustomLayout.newId(), name: 'A', slots: [s('a', 'pad:A')]);
      final b = CustomLayout(id: CustomLayout.newId(), name: 'B', slots: [s('b', 'key:W')]);

      await store.save(a);
      await store.save(b);
      expect(store.layouts, hasLength(2));
      expect(store.active!.id, b.id);

      await store.duplicate(a.id);
      expect(store.layouts, hasLength(3));
      for (final l in store.layouts) {
        expect(
          l.slots.map((x) => x.id).toSet().length,
          l.slots.length,
          reason: 'slot ids must stay unique after duplication',
        );
      }

      await store.rename(a.id, 'Renamed');
      expect(store.layouts.firstWhere((l) => l.id == a.id).name, 'Renamed');

      await store.activate(a.id);
      expect(store.active!.id, a.id);

      await store.remove(a.id);
      expect(store.hasCustom, isTrue, reason: 'remaining layout stays active');
      expect(store.layouts.any((l) => l.id == a.id), isFalse);

      await store.remove(b.id);
      // One copied layout remains.
      expect(store.hasCustom, isTrue);
    });
  });
}