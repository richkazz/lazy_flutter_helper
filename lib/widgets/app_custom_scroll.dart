import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

class AppCustomScrollView extends StatelessWidget {
  const AppCustomScrollView(
      {required this.child, this.scrollDirection = Axis.vertical, super.key});
  final Widget child;
  final Axis scrollDirection;
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
        scrollDirection: scrollDirection,
        scrollBehavior: const ScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.stylus,
          },
        ),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: child,
          ),
        ]);
  }
}
