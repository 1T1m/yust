import 'package:flutter/material.dart';
import 'package:yust/widgets/yust_input_tile.dart';

class YustSwitch extends StatelessWidget {
  final String? label;
  final bool value;
  final Color? activeColor;
  final Widget? prefixIcon;
  final void Function(bool)? onChanged;
  final bool readOnly;
  //switchRepresentation could be: 'yesNo', 'checkbox', 'label',
  final String switchRepresentation;

  const YustSwitch({
    Key? key,
    this.label,
    required this.value,
    this.activeColor,
    this.prefixIcon,
    this.onChanged,
    this.readOnly = false,
    this.switchRepresentation = 'yesNo',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (switchRepresentation == 'checkbox') {
      return YustInputTile(
          child: Checkbox(
            checkColor: activeColor,
            value: value,
            onChanged: (bool? value) => readOnly ? null : value,
          ),
          label: label,
          prefixIcon: prefixIcon);
    } else {
      return YustInputTile(
          child: Switch(
            value: value,
            activeColor: activeColor,
            onChanged: readOnly ? null : onChanged,
          ),
          label: label,
          prefixIcon: prefixIcon);
    }
  }
}
