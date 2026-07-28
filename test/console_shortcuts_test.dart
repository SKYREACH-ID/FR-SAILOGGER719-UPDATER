import 'package:flutter_test/flutter_test.dart';
import 'package:sailogger719/screens/console_shortcuts.dart';

void main() {
  group('console shortcut state', () {
    test('starts with no active modifiers', () {
      final state = ConsoleShortcutState();

      expect(state.ctrlLatched, isFalse);
      expect(state.altLatched, isFalse);
    });

    test('toggles ctrl latch on and off', () {
      final state = ConsoleShortcutState();

      state.toggleCtrl();
      expect(state.ctrlLatched, isTrue);

      state.toggleCtrl();
      expect(state.ctrlLatched, isFalse);
    });

    test('toggles alt latch on and off', () {
      final state = ConsoleShortcutState();

      state.toggleAlt();
      expect(state.altLatched, isTrue);

      state.toggleAlt();
      expect(state.altLatched, isFalse);
    });

    test('exposes current sticky modifiers without clearing them', () {
      final state = ConsoleShortcutState();
      state.toggleCtrl();
      state.toggleAlt();

      final modifiers = state.modifiers;

      expect(modifiers.ctrl, isTrue);
      expect(modifiers.alt, isTrue);
      expect(state.ctrlLatched, isTrue);
      expect(state.altLatched, isTrue);
    });

    test('clears modifiers explicitly', () {
      final state = ConsoleShortcutState();
      state.toggleCtrl();
      state.toggleAlt();

      state.clear();

      expect(state.ctrlLatched, isFalse);
      expect(state.altLatched, isFalse);
    });

    test('applies ctrl modifier to typed lowercase letter', () {
      final state = ConsoleShortcutState();
      state.toggleCtrl();

      expect(
        applyLatchedModifiersToTerminalOutput(
          raw: 'c',
          modifiers: state.modifiers,
        ),
        String.fromCharCode(3),
      );
      expect(state.ctrlLatched, isTrue);
    });

    test('applies ctrl modifier to typed uppercase letter', () {
      final state = ConsoleShortcutState();
      state.toggleCtrl();

      expect(
        applyLatchedModifiersToTerminalOutput(
          raw: 'C',
          modifiers: state.modifiers,
        ),
        String.fromCharCode(3),
      );
      expect(state.ctrlLatched, isTrue);
    });

    test('applies alt modifier as escape prefix', () {
      final state = ConsoleShortcutState();
      state.toggleAlt();

      expect(
        applyLatchedModifiersToTerminalOutput(
          raw: 'x',
          modifiers: state.modifiers,
        ),
        '\u001bx',
      );
      expect(state.altLatched, isTrue);
    });
  });

  group('console shortcut catalog', () {
    test('uses a single compact primary row', () {
      expect(
        primaryConsoleShortcutLabels(),
        const ['Ctrl', 'Alt', 'Esc', 'Tab', 'Enter', 'More'],
      );
    });

    test('overflow menu includes advanced terminal actions', () {
      final sections = buildConsoleOverflowSections();
      final labels = sections
          .expand((section) => section.items)
          .map((item) => item.label)
          .toList();

      expect(labels, containsAll(const [
        'Select All',
        'Copy',
        '^C',
        '^U',
        '^W',
        '^X',
        '^O',
        '^K',
        'Ctrl+C',
        'Ctrl+D',
        'Ctrl+L',
        'Backspace',
        'Home',
        'End',
        'PgUp',
        'PgDn',
        'Insert',
        'Delete',
        'F1',
        'F12',
        '|',
        '~',
      ]));
    });
  });
}
