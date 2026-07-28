class ConsoleShortcutModifiers {
  const ConsoleShortcutModifiers({
    required this.ctrl,
    required this.alt,
  });

  final bool ctrl;
  final bool alt;
}

class ConsoleShortcutCatalogItem {
  const ConsoleShortcutCatalogItem(this.label);

  final String label;
}

class ConsoleShortcutCatalogSection {
  const ConsoleShortcutCatalogSection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<ConsoleShortcutCatalogItem> items;
}

List<String> primaryConsoleShortcutLabels() {
  return const ['Ctrl', 'Alt', 'Esc', 'Tab', 'Enter', 'More'];
}

List<ConsoleShortcutCatalogSection> buildConsoleOverflowSections() {
  return const [
    ConsoleShortcutCatalogSection(
      title: 'Navigation',
      items: [
        ConsoleShortcutCatalogItem('←'),
        ConsoleShortcutCatalogItem('↑'),
        ConsoleShortcutCatalogItem('↓'),
        ConsoleShortcutCatalogItem('→'),
        ConsoleShortcutCatalogItem('Home'),
        ConsoleShortcutCatalogItem('End'),
        ConsoleShortcutCatalogItem('PgUp'),
        ConsoleShortcutCatalogItem('PgDn'),
      ],
    ),
    ConsoleShortcutCatalogSection(
      title: 'Control',
      items: [
        ConsoleShortcutCatalogItem('Select All'),
        ConsoleShortcutCatalogItem('Copy'),
        ConsoleShortcutCatalogItem('Backspace'),
        ConsoleShortcutCatalogItem('^C'),
        ConsoleShortcutCatalogItem('^U'),
        ConsoleShortcutCatalogItem('^W'),
        ConsoleShortcutCatalogItem('^X'),
        ConsoleShortcutCatalogItem('^O'),
        ConsoleShortcutCatalogItem('^K'),
        ConsoleShortcutCatalogItem('Ctrl+C'),
        ConsoleShortcutCatalogItem('Ctrl+D'),
        ConsoleShortcutCatalogItem('Ctrl+L'),
        ConsoleShortcutCatalogItem('Insert'),
        ConsoleShortcutCatalogItem('Delete'),
      ],
    ),
    ConsoleShortcutCatalogSection(
      title: 'Function Keys',
      items: [
        ConsoleShortcutCatalogItem('F1'),
        ConsoleShortcutCatalogItem('F2'),
        ConsoleShortcutCatalogItem('F3'),
        ConsoleShortcutCatalogItem('F4'),
        ConsoleShortcutCatalogItem('F5'),
        ConsoleShortcutCatalogItem('F6'),
        ConsoleShortcutCatalogItem('F7'),
        ConsoleShortcutCatalogItem('F8'),
        ConsoleShortcutCatalogItem('F9'),
        ConsoleShortcutCatalogItem('F10'),
        ConsoleShortcutCatalogItem('F11'),
        ConsoleShortcutCatalogItem('F12'),
      ],
    ),
    ConsoleShortcutCatalogSection(
      title: 'Symbols',
      items: [
        ConsoleShortcutCatalogItem('|'),
        ConsoleShortcutCatalogItem('\\'),
        ConsoleShortcutCatalogItem('/'),
        ConsoleShortcutCatalogItem('~'),
        ConsoleShortcutCatalogItem('^'),
        ConsoleShortcutCatalogItem('{'),
        ConsoleShortcutCatalogItem('}'),
        ConsoleShortcutCatalogItem('['),
        ConsoleShortcutCatalogItem(']'),
        ConsoleShortcutCatalogItem('<'),
        ConsoleShortcutCatalogItem('>'),
      ],
    ),
  ];
}

String applyLatchedModifiersToTerminalOutput({
  required String raw,
  required ConsoleShortcutModifiers modifiers,
}) {
  if (raw.isEmpty) return raw;

  var output = raw;

  if (modifiers.ctrl) {
    final first = output.codeUnitAt(0);
    if ((first >= 65 && first <= 90) || (first >= 97 && first <= 122)) {
      final normalized = (first >= 97 && first <= 122) ? first - 96 : first - 64;
      final rest = output.substring(1);
      output = String.fromCharCode(normalized) + rest;
    }
  }

  if (modifiers.alt) {
    output = '\u001b$output';
  }

  return output;
}

class ConsoleShortcutState {
  bool _ctrlLatched = false;
  bool _altLatched = false;

  bool get ctrlLatched => _ctrlLatched;
  bool get altLatched => _altLatched;
  ConsoleShortcutModifiers get modifiers => ConsoleShortcutModifiers(
        ctrl: _ctrlLatched,
        alt: _altLatched,
      );

  void toggleCtrl() {
    _ctrlLatched = !_ctrlLatched;
  }

  void toggleAlt() {
    _altLatched = !_altLatched;
  }

  ConsoleShortcutModifiers consumeModifiers() {
    final modifiers = this.modifiers;
    clear();
    return modifiers;
  }

  void clear() {
    _ctrlLatched = false;
    _altLatched = false;
  }
}
