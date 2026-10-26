import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../palette.dart';
import '../notch_border.dart';
import '../type.dart';

/// Command field: a Volt `>` prompt, a mono placeholder and a solid Volt
/// block cursor on a `surface` notch. 48 high.
///
/// Without a [controller] it only reports taps (System's "find a setting").
/// With one it takes text: while empty it still shows the placeholder and the
/// block, as in the design; once there is text, the block becomes the caret.
class HaloCommandField extends StatefulWidget {
  const HaloCommandField({
    super.key,
    this.placeholder = 'find a setting',
    this.onTap,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
  });

  final String placeholder;
  final VoidCallback? onTap;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<HaloCommandField> createState() => _HaloCommandFieldState();
}

class _HaloCommandFieldState extends State<HaloCommandField> {
  FocusNode? _ownFocus;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  final _editable = GlobalKey<EditableTextState>();

  /// Focuses the field and shows the keyboard. The field keeps its focus
  /// when the user closes the keyboard, so asking for focus again would do
  /// nothing; this reopens the keyboard, as `TextField` does.
  void _showKeyboard() => _editable.currentState?.requestKeyboard();

  @override
  void dispose() {
    _ownFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final halo = context.halo;
    final controller = widget.controller;
    final placeholder = Row(
      children: [
        Flexible(
          child: Text(
            widget.placeholder,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: HaloType.command.copyWith(color: halo.muted),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 9,
          height: 18,
          child: ColoredBox(color: halo.signalLine),
        ),
      ],
    );

    final Widget field;
    if (controller == null) {
      field = placeholder;
    } else {
      field = ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => Stack(
          alignment: Alignment.centerLeft,
          children: [
            EditableText(
              key: _editable,
              controller: controller,
              // Taps go to the field's own handler, which reopens the
              // keyboard; the text renderer would swallow them.
              rendererIgnoresPointer: true,
              focusNode: _focus,
              autofocus: widget.autofocus,
              style: HaloType.command.copyWith(color: halo.text),
              cursorColor: halo.signalLine,
              backgroundCursorColor: halo.muted,
              cursorWidth: 9,
              cursorHeight: 18,
              showCursor: value.text.isNotEmpty,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.go,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
            ),
            if (value.text.isEmpty) IgnorePointer(child: placeholder),
          ],
        ),
      );
    }

    return Semantics(
      textField: true,
      label: widget.placeholder,
      onTap: widget.onTap ?? (controller == null ? null : _showKeyboard),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (controller != null) _showKeyboard();
          widget.onTap?.call();
        },
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: ShapeDecoration(
            color: halo.surface,
            shape: NotchBorder(
              radius: HaloRadii.notchField,
              side: BorderSide(color: halo.soft),
            ),
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Text(
                  '>',
                  style: HaloType.command.copyWith(color: halo.signalText),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: controller == null
                    ? ExcludeSemantics(child: field)
                    : field,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
