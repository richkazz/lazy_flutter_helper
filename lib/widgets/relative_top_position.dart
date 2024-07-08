import 'package:flutter/material.dart';

class RelativeTopPosition extends StatefulWidget {
  const RelativeTopPosition(
      {required this.child,
      required this.onTopPositionAvailable,
      this.boxSize,
      this.boxOffset,
      super.key});
  final Widget child;
  final ValueChanged<double> onTopPositionAvailable;
  final ValueChanged<Size>? boxSize;
  final ValueChanged<Offset>? boxOffset;
  @override
  State<RelativeTopPosition> createState() => _RelativeTopPositionState();
}

class _RelativeTopPositionState extends State<RelativeTopPosition> {
  double _topPosition = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_getPosition);
  }

  void _getPosition(Duration timeStamp) {
    if (mounted == false) {
      return;
    }
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }
    final offset = renderBox.localToGlobal(Offset.zero);
    setState(() {
      _topPosition = offset.dy;
      widget.onTopPositionAvailable(_topPosition);
      widget.boxSize?.call(renderBox.size);
      widget.boxOffset?.call(offset);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
      ],
    );
  }
}
