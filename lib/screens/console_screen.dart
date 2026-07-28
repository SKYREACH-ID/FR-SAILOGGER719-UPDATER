import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sailogger719/screens/console_shortcuts.dart';
import 'package:sailogger719/widgets/app_overlay_message.dart';
import 'package:xterm/xterm.dart';

const double minConsoleTerminalFontSize = 5;
const double maxConsoleTerminalFontSize = 13;

double clampConsoleTerminalFontSize(double value) {
  return value.clamp(
    minConsoleTerminalFontSize,
    maxConsoleTerminalFontSize,
  ).toDouble();
}

double scaleConsoleTerminalFontSize({
  required double baseFontSize,
  required double gestureScale,
}) {
  return clampConsoleTerminalFontSize(baseFontSize * gestureScale);
}

class ConsoleScreen extends StatefulWidget {
  const ConsoleScreen({
    super.key,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    this.autoConnect = true,
  });

  final String host;
  final int port;
  final String username;
  final String password;
  final bool autoConnect;

  @override
  State<ConsoleScreen> createState() => _ConsoleScreenState();
}

class _ConsoleScreenState extends State<ConsoleScreen> {
  final FocusNode _terminalFocusNode = FocusNode();
  final ValueNotifier<String> _status = ValueNotifier<String>('CONNECTING');
  final ConsoleShortcutState _shortcutState = ConsoleShortcutState();

  late Terminal _terminal;
  TerminalController? _terminalController;

  SSHClient? _client;
  SSHSession? _shell;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  bool _isClosing = false;
  double _terminalFontSize = minConsoleTerminalFontSize;
  double _gestureBaseFontSize = minConsoleTerminalFontSize;

  @override
  void initState() {
    super.initState();
    _resetTerminal();
    if (widget.autoConnect) {
      unawaited(_connectShell());
    }
  }

  void _resetTerminal() {
    if (_terminalController case final controller?) {
      controller.removeListener(_handleTerminalSelectionChanged);
    }
    _terminal = Terminal(
      maxLines: 5000,
      onBell: () {},
      onTitleChange: (title) {
        if (!mounted || title.trim().isEmpty) return;
        setState(() {});
      },
      onResize: (width, height, pixelWidth, pixelHeight) {
        _shell?.resizeTerminal(width, height, pixelWidth, pixelHeight);
      },
    );
    final controller = TerminalController();
    controller.addListener(_handleTerminalSelectionChanged);
    _terminalController = controller;
    _terminal.onOutput = (data) {
      final shell = _shell;
      if (shell == null) return;
      final latched = _shortcutState.modifiers;
      final transformed = applyLatchedModifiersToTerminalOutput(
        raw: data,
        modifiers: latched,
      );
      shell.write(Uint8List.fromList(utf8.encode(transformed)));
    };
  }

  void _handleTerminalSelectionChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _handleTerminalScaleStart(ScaleStartDetails details) {
    _gestureBaseFontSize = _terminalFontSize;
  }

  void _handleTerminalScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2) return;

    final nextFontSize = scaleConsoleTerminalFontSize(
      baseFontSize: _gestureBaseFontSize,
      gestureScale: details.scale,
    );
    if ((nextFontSize - _terminalFontSize).abs() < 0.05) return;

    setState(() {
      _terminalFontSize = nextFontSize;
    });
  }

  Future<void> _connectShell() async {
    try {
      _terminal.write('Connecting remote shell...\r\n');
      final client = SSHClient(
        await SSHSocket.connect(
          widget.host,
          widget.port,
          timeout: const Duration(seconds: 5),
        ),
        username: widget.username,
        onPasswordRequest: () => widget.password,
      );

      final shell = await client.shell(
        pty: SSHPtyConfig(
          width: _terminal.viewWidth,
          height: _terminal.viewHeight,
        ),
      );

      _client = client;
      _shell = shell;

      _terminal.buffer.clear();
      _terminal.buffer.setCursor(0, 0);

      _stdoutSubscription = shell.stdout
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(_terminal.write);
      _stderrSubscription = shell.stderr
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(_terminal.write);

      _status.value = 'CONNECTED';

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _terminalFocusNode.requestFocus();
        });
      }

      unawaited(
        shell.done.then((_) {
          if (_isClosing) return;
          _status.value = 'DISCONNECTED';
          _terminal.write('\r\n[session closed]\r\n');
        }),
      );
    } catch (e) {
      _status.value = 'FAILED';
      _terminal.write('[error] Failed to connect shell: $e\r\n');
    }
  }

  Future<void> _closeShell() async {
    _isClosing = true;
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _shell?.close();
    _client?.close();
    _stdoutSubscription = null;
    _stderrSubscription = null;
    _shell = null;
    _client = null;
  }

  Future<void> _reconnect() async {
    await _closeShell();
    _isClosing = false;
    _status.value = 'CONNECTING';
    _shortcutState.clear();
    setState(_resetTerminal);
    await _connectShell();
  }

  void _sendKey(TerminalKey key, {bool ctrl = false, bool alt = false}) {
    final latched = _shortcutState.modifiers;
    final effectiveCtrl = ctrl || latched.ctrl;
    final effectiveAlt = alt || latched.alt;
    _terminal.keyInput(key, ctrl: effectiveCtrl, alt: effectiveAlt);
    _terminalFocusNode.requestFocus();
  }

  void _toggleCtrlModifier() {
    setState(() {
      _shortcutState.toggleCtrl();
    });
    _terminalFocusNode.requestFocus();
  }

  void _toggleAltModifier() {
    setState(() {
      _shortcutState.toggleAlt();
    });
    _terminalFocusNode.requestFocus();
  }

  void _clearTerminal() {
    _terminal.buffer.clear();
    _terminal.buffer.setCursor(0, 0);
    _shortcutState.clear();
    if (mounted) {
      setState(() {});
    }
    _terminalFocusNode.requestFocus();
  }

  void _sendText(String text) {
    final shell = _shell;
    if (shell == null || text.isEmpty) return;
    final latched = _shortcutState.modifiers;
    final transformed = applyLatchedModifiersToTerminalOutput(
      raw: text,
      modifiers: latched,
    );
    shell.write(Uint8List.fromList(utf8.encode(transformed)));
    _terminalFocusNode.requestFocus();
  }

  void _selectAllTerminalText() {
    final controller = _terminalController;
    if (controller == null) return;
    final topRow = (_terminal.buffer.height - _terminal.viewHeight).clamp(
      0,
      _terminal.buffer.height - 1,
    );
    controller.setSelection(
      _terminal.buffer.createAnchor(
        0,
        topRow,
      ),
      _terminal.buffer.createAnchor(
        _terminal.viewWidth,
        _terminal.buffer.height - 1,
      ),
      mode: SelectionMode.line,
    );
    _terminalFocusNode.requestFocus();
  }

  Future<void> _copySelectedTerminalText() async {
    final controller = _terminalController;
    if (controller == null) return;
    final selection = controller.selection;
    if (selection == null) {
      AppOverlayMessage.show(context, message: 'Tidak ada teks yang dipilih.');
      return;
    }

    final text = _terminal.buffer.getText(selection);
    await Clipboard.setData(ClipboardData(text: text));
    AppOverlayMessage.show(
      context,
      message: 'Teks terminal berhasil disalin.',
    );
  }

  Widget _buildSelectionOverlay(BoxConstraints constraints) {
    final selection = _terminalController?.selection?.normalized;
    if (selection == null) {
      return const SizedBox.shrink();
    }

    const terminalTopInset = 24.0;
    const terminalPaddingLeft = 12.0;
    const terminalPaddingTop = 10.0;
    const terminalPaddingRight = 12.0;
    const terminalPaddingBottom = 12.0;
    const overlayWidth = 188.0;
    const overlayHeight = 48.0;
    const edgeGap = 10.0;

    final visibleTopRow = (_terminal.buffer.height - _terminal.viewHeight).clamp(
      0,
      _terminal.buffer.height - 1,
    );
    final visibleRow = (selection.begin.y - visibleTopRow).clamp(
      0,
      (_terminal.viewHeight - 1).clamp(0, _terminal.viewHeight),
    );
    final visibleColumn = selection.begin.x.clamp(
      0,
      (_terminal.viewWidth - 1).clamp(0, _terminal.viewWidth),
    );

    final contentWidth =
        constraints.maxWidth - terminalPaddingLeft - terminalPaddingRight;
    final contentHeight = constraints.maxHeight -
        terminalTopInset -
        terminalPaddingTop -
        terminalPaddingBottom;
    final cellWidth =
        _terminal.viewWidth > 0 ? contentWidth / _terminal.viewWidth : 0.0;
    final cellHeight =
        _terminal.viewHeight > 0 ? contentHeight / _terminal.viewHeight : 0.0;

    final rawLeft =
        terminalPaddingLeft + (visibleColumn * cellWidth) - (overlayWidth / 2);
    final rawTop =
        terminalTopInset + terminalPaddingTop + (visibleRow * cellHeight) - 56;

    final left = rawLeft.clamp(
      edgeGap,
      constraints.maxWidth - overlayWidth - edgeGap,
    );
    final top = rawTop.clamp(
      edgeGap,
      constraints.maxHeight - overlayHeight - edgeGap,
    );

    return Positioned(
      top: top,
      left: left,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xEE232239),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF47506B)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSelectionActionButton(
              icon: Icons.copy_all_outlined,
              label: 'Copy',
              onTap: () => unawaited(_copySelectedTerminalText()),
            ),
            const SizedBox(width: 6),
            _buildSelectionActionButton(
              icon: Icons.select_all,
              label: 'Select All',
              onTap: _selectAllTerminalText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF32314B),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleOverflowShortcut(String label) {
    switch (label) {
      case 'Select All':
        _selectAllTerminalText();
        return;
      case 'Copy':
        unawaited(_copySelectedTerminalText());
        return;
      case '←':
        _sendKey(TerminalKey.arrowLeft);
        return;
      case '↑':
        _sendKey(TerminalKey.arrowUp);
        return;
      case '↓':
        _sendKey(TerminalKey.arrowDown);
        return;
      case '→':
        _sendKey(TerminalKey.arrowRight);
        return;
      case 'Home':
        _sendKey(TerminalKey.home);
        return;
      case 'End':
        _sendKey(TerminalKey.end);
        return;
      case 'PgUp':
        _sendKey(TerminalKey.pageUp);
        return;
      case 'PgDn':
        _sendKey(TerminalKey.pageDown);
        return;
      case 'Backspace':
        _sendKey(TerminalKey.backspace);
        return;
      case '^C':
      case 'Ctrl+C':
        _sendKey(TerminalKey.keyC, ctrl: true);
        return;
      case '^U':
        _sendKey(TerminalKey.keyU, ctrl: true);
        return;
      case '^W':
        _sendKey(TerminalKey.keyW, ctrl: true);
        return;
      case '^X':
        _sendKey(TerminalKey.keyX, ctrl: true);
        return;
      case '^O':
        _sendKey(TerminalKey.keyO, ctrl: true);
        return;
      case '^K':
        _sendKey(TerminalKey.keyK, ctrl: true);
        return;
      case 'Ctrl+D':
        _sendKey(TerminalKey.keyD, ctrl: true);
        return;
      case 'Ctrl+L':
        _sendKey(TerminalKey.keyL, ctrl: true);
        return;
      case 'Insert':
        _sendKey(TerminalKey.insert);
        return;
      case 'Delete':
        _sendKey(TerminalKey.delete);
        return;
      case 'F1':
        _sendKey(TerminalKey.f1);
        return;
      case 'F2':
        _sendKey(TerminalKey.f2);
        return;
      case 'F3':
        _sendKey(TerminalKey.f3);
        return;
      case 'F4':
        _sendKey(TerminalKey.f4);
        return;
      case 'F5':
        _sendKey(TerminalKey.f5);
        return;
      case 'F6':
        _sendKey(TerminalKey.f6);
        return;
      case 'F7':
        _sendKey(TerminalKey.f7);
        return;
      case 'F8':
        _sendKey(TerminalKey.f8);
        return;
      case 'F9':
        _sendKey(TerminalKey.f9);
        return;
      case 'F10':
        _sendKey(TerminalKey.f10);
        return;
      case 'F11':
        _sendKey(TerminalKey.f11);
        return;
      case 'F12':
        _sendKey(TerminalKey.f12);
        return;
      default:
        _sendText(label);
    }
  }

  Future<void> _showMoreShortcuts() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF232239),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'More Shortcuts',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChipShortcut(
                      label: 'Keyboard',
                      icon: Icons.keyboard,
                      onTap: () {
                        Navigator.of(context).pop();
                        _terminalFocusNode.requestFocus();
                      },
                    ),
                    _buildChipShortcut(
                      label: 'Reconnect',
                      onTap: () {
                        Navigator.of(context).pop();
                        _reconnect();
                      },
                    ),
                    _buildChipShortcut(
                      label: 'Clear',
                      onTap: () {
                        Navigator.of(context).pop();
                        _clearTerminal();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...buildConsoleOverflowSections().map(
                  (section) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          style: const TextStyle(
                            color: Color(0xFF8AF5A4),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: section.items.map((item) {
                            return _buildChipShortcut(
                              label: item.label,
                              onTap: () {
                                Navigator.of(context).pop();
                                _handleOverflowShortcut(item.label);
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2940),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(icon, color: const Color(0xFFD6DAE8), size: 24),
      ),
    );
  }

  Widget _buildBottomKey({
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    bool highlighted = false,
    bool underlined = false,
    bool compact = false,
    String? longPressHint,
  }) {
    final color = highlighted ? const Color(0xFF8AF5A4) : Colors.white;
    final hasIcon = icon != null;
    final hasLabel = label.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        onLongPress: longPressHint == null
            ? null
            : () => AppOverlayMessage.show(context, message: longPressHint),
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          height: 46,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 8,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: highlighted
                ? const Color(0xFF435869)
                : const Color(0xFF32314B),
            borderRadius: BorderRadius.circular(10),
            border: highlighted
                ? Border.all(color: const Color(0xFF8AF5A4), width: 1.2)
                : null,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasIcon) ...[
                  Icon(icon, color: color, size: hasLabel ? 16 : 18),
                  if (hasLabel) const SizedBox(height: 2),
                ],
                if (hasLabel)
                  SizedBox(
                    height: 14,
                    child: Center(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: compact ? 11.5 : 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1,
                          decoration: underlined
                              ? TextDecoration.underline
                              : TextDecoration.none,
                          decorationColor: color,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChipShortcut({
    required String label,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF32314B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3F4560)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _isClosing = true;
    unawaited(_closeShell());
    _terminalController?.removeListener(_handleTerminalSelectionChanged);
    _terminalFocusNode.dispose();
    _status.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF18182B),
      body: SafeArea(
        child: Container(
          color: const Color(0xFF18182B),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Row(
                  children: [
                    _buildTopIconButton(
                      icon: Icons.chevron_left,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF104C3A),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.terminal_rounded,
                              color: Color(0xFF70E8A2),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Console',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF70E8A2),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF05080B),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF2E3550)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x55000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onScaleStart: _handleTerminalScaleStart,
                      onScaleUpdate: _handleTerminalScaleUpdate,
                      child: LayoutBuilder(
                        builder: (context, constraints) => Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 24),
                              child: TerminalView(
                                _terminal,
                                controller: _terminalController,
                                autofocus: true,
                                focusNode: _terminalFocusNode,
                                backgroundOpacity: 1,
                                deleteDetection: true,
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                                cursorType: TerminalCursorType.block,
                                theme: const TerminalTheme(
                                  cursor: Color(0xFF98F5BA),
                                  selection: Color(0x664F8F6B),
                                  foreground: Color(0xFF98F5BA),
                                  background: Color(0xFF05080B),
                                  black: Color(0xFF05080B),
                                  red: Color(0xFFFF6B6B),
                                  green: Color(0xFF98F5BA),
                                  yellow: Color(0xFFF6D365),
                                  blue: Color(0xFF8FC7FF),
                                  magenta: Color(0xFFD7A6FF),
                                  cyan: Color(0xFF7DE2D1),
                                  white: Color(0xFFE5F7EB),
                                  brightBlack: Color(0xFF51606F),
                                  brightRed: Color(0xFFFF9A9A),
                                  brightGreen: Color(0xFFB9FFD0),
                                  brightYellow: Color(0xFFFFE08A),
                                  brightBlue: Color(0xFFB5DCFF),
                                  brightMagenta: Color(0xFFE3BEFF),
                                  brightCyan: Color(0xFFA5F4E7),
                                  brightWhite: Color(0xFFFFFFFF),
                                  searchHitBackground: Color(0xFFFFFF2B),
                                  searchHitBackgroundCurrent: Color(0xFF31FF26),
                                  searchHitForeground: Color(0xFF000000),
                                ),
                                textStyle: TerminalStyle(
                                  fontFamily: 'monospace',
                                  fontSize: _terminalFontSize,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            if (_terminalController?.selection != null)
                              _buildSelectionOverlay(constraints),
                          // Positioned(
                        //   top: 10,
                        //   left: 14,
                        //   child: ValueListenableBuilder<String>(
                        //     valueListenable: _status,
                        //     builder: (context, status, _) => Text(
                        //       status == 'CONNECTED'
                        //           ? 'TERMINAL READY'
                        //           : 'TERMINAL $status',
                        //       style: const TextStyle(
                        //         color: Color(0xFF51606F),
                        //         fontSize: 10,
                        //         fontWeight: FontWeight.w700,
                        //         letterSpacing: 1.1,
                        //       ),
                        //     ),
                        //   ),
                            // ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(7, 7, 7, 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B2A42),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF2E3550)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildBottomKey(
                          label: 'Ctrl',
                          underlined: true,
                          highlighted: _shortcutState.ctrlLatched,
                          onPressed: _toggleCtrlModifier,
                          longPressHint: 'Toggle Ctrl modifier',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildBottomKey(
                          label: 'Alt',
                          underlined: true,
                          highlighted: _shortcutState.altLatched,
                          onPressed: _toggleAltModifier,
                          longPressHint: 'Toggle Alt modifier',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildBottomKey(
                          label: 'Esc',
                          onPressed: () => _sendKey(TerminalKey.escape),
                          longPressHint: 'Escape',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildBottomKey(
                          label: 'Tab',
                          underlined: true,
                          onPressed: () => _sendKey(TerminalKey.tab),
                          longPressHint: 'Tab completion',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildBottomKey(
                          label: '',
                          icon: Icons.more_horiz,
                          onPressed: _showMoreShortcuts,
                          longPressHint: 'More shortcuts',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
