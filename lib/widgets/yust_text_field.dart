import 'package:flutter/material.dart';
import 'package:yust/yust.dart';

typedef StringCallback = void Function(String?);
typedef TapCallback = void Function();
typedef DeleteCallback = Future<void> Function();

class YustTextField extends StatefulWidget {
  final String? label;
  final String? value;
  final TextStyle? textStyle;
  final StringCallback? onChanged;

  /// if a validator is implemented, onEditingComplete gets only triggered, if validator is true (true = returns null)
  final StringCallback? onEditingComplete;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final TapCallback? onTap;
  final DeleteCallback? onDelete;
  final int? maxLines;
  final int? minLines;
  final bool readOnly;
  final bool enabled;
  final bool showSelected;
  final bool obscureText;
  final TextInputType? keyBoardType;
  final YustInputStyle? style;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextCapitalization textCapitalization;
  final AutovalidateMode? autovalidateMode;

  YustTextField(
      {Key? key,
      this.label,
      this.value,
      this.textStyle,
      this.onChanged,
      this.onEditingComplete,
      this.controller,
      this.validator,
      this.onTap,
      this.onDelete,
      this.maxLines,
      this.minLines,
      this.enabled = true,
      this.showSelected = true,
      this.readOnly = false,
      this.obscureText = false,
      this.keyBoardType,
      this.style,
      this.prefixIcon,
      this.suffixIcon,
      this.textCapitalization = TextCapitalization.sentences,
      this.autovalidateMode})
      : super(key: key);

  @override
  _YustTextFieldState createState() => _YustTextFieldState();
}

class _YustTextFieldState extends State<YustTextField> {
  late TextEditingController _controller;
  FocusNode _focusNode = FocusNode();
  late String _initValue;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null && widget.value != null) {
      widget.controller!.text = widget.value!;
    }
    _controller =
        widget.controller ?? TextEditingController(text: widget.value);
    _initValue = widget.value ?? '';
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && widget.onEditingComplete != null) {
        final textFieldText = _controller.value.text.trim();
        final textFieldValue = textFieldText == '' ? null : textFieldText;
        if (widget.validator == null) {
          widget.onEditingComplete!(textFieldValue);
        } else if (widget.validator!(textFieldValue) == null) {
          widget.onEditingComplete!(textFieldValue);
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.value != null &&
        widget.onChanged == null &&
        widget.value != _initValue &&
        widget.value != _controller.text) {
      _controller.text = widget.value!;
      _initValue = widget.value!;
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: widget.label,
                  labelStyle: widget.showSelected
                      ? null
                      : TextStyle(color: Colors.black54),
                  contentPadding: const EdgeInsets.all(20.0),
                  border: widget.style == YustInputStyle.outlineBorder
                      ? OutlineInputBorder()
                      : InputBorder.none,
                  prefixIcon: widget.prefixIcon,
                ),
                style: widget.textStyle,
                maxLines: widget.obscureText ? 1 : widget.maxLines,
                minLines: widget.minLines,
                controller: _controller,
                focusNode: _focusNode,
                keyboardType: widget.keyBoardType,
                textInputAction: widget.minLines != null
                    ? TextInputAction.newline
                    : TextInputAction.next,
                onChanged: widget.onChanged == null
                    ? null
                    : (value) =>
                        widget.onChanged!(value == '' ? null : value.trim()),
                onTap: widget.onTap,
                readOnly: widget.readOnly,
                enabled: widget.enabled,
                obscureText: widget.obscureText,
                textCapitalization: widget.textCapitalization,
                autovalidateMode: widget.autovalidateMode,
                validator: widget.validator == null
                    ? null
                    : (value) => widget.validator!(value!.trim()),
              ),
            ),
            if (widget.onDelete != null && widget.value != '')
              IconButton(
                  onPressed: widget.onDelete!,
                  icon: Icon(
                    Icons.delete,
                    color: Theme.of(context).primaryColor,
                  )),
            widget.suffixIcon ?? SizedBox(),
          ],
        ),
        if (widget.style == YustInputStyle.normal)
          Divider(height: 1.0, thickness: 1.0, color: Colors.grey),
      ],
    );
  }
}
