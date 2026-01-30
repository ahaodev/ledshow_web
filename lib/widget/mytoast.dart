import 'package:flutter/material.dart';
enum ToastTip {
  ok,
  err,
  warn,
}
class MyToast extends StatelessWidget {
  final String tip;
  final bool ok;

  const MyToast({Key? key, required this.tip, required this.ok})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData iconData;
    if (ok) {
      color = Colors.green;
      iconData = Icons.check_circle_outline;
    } else {
      color = Colors.red;
      iconData = Icons.error_outline;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25.0),
        color: color,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconData,
            color: Colors.white,
          ),
          const SizedBox(
            width: 12.0,
          ),
          Flexible(
            child: Text(
              tip,
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }
}
