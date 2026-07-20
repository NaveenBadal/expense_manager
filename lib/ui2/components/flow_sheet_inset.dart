import 'package:flutter/material.dart';

/// Lifts sheet content clear of an open keyboard.
///
/// A bottom sheet keeps whatever height it was given when the keyboard
/// appears, so anything anchored to its bottom edge — a composer, a save
/// button — ends up underneath it and you cannot see what you are typing.
/// This was a real defect in the chat sheet, which sat at a fixed fraction of
/// the screen and never insetted.
///
/// Named rather than inlined because three sheets already did this from
/// memory and the fourth forgot.
class FlowSheetInset extends StatelessWidget {
  const FlowSheetInset({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: child,
  );
}
