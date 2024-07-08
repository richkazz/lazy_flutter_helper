import 'package:flutter/material.dart';

class AppCheckBox extends StatefulWidget {
  const AppCheckBox({required this.value, required this.onChanged, super.key});
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  State<AppCheckBox> createState() => _AppCheckBoxState();
}

class _AppCheckBoxState extends State<AppCheckBox> {
  bool _value = false;
  void toggleValue() {
    setState(() {
      _value = !_value;
    });
    widget.onChanged(_value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: toggleValue,
      child: Container(
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        margin: const EdgeInsets.only(right: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.background,
          border: _value
              ? null
              : Border.all(
                  color: Theme.of(context).colorScheme.brightness ==
                          Brightness.light
                      ? Colors.black
                      : Colors.white,
                ),
          boxShadow: switch (_value) {
            true => null,
            false => [
                BoxShadow(
                  color: Theme.of(context).colorScheme.brightness ==
                          Brightness.light
                      ? const Color.fromRGBO(0, 0, 0, 0.25)
                      : const Color.fromRGBO(255, 255, 255, 0.75),
                  blurRadius: 2,
                  offset: const Offset(2, 2),
                ),
              ],
          },
        ),
        child: switch (_value) {
          true => Icon(
              Icons.check_box,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          false => const SizedBox.shrink()
        },
      ),
    );
  }
}
