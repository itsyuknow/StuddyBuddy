import 'package:flutter/material.dart';

/// Wrapper widget that handles keyboard dismissal on back button press
/// Use this to wrap screens that have text input fields
class KeyboardDismissibleScreen extends StatelessWidget {
  final Widget child;
  final bool dismissKeyboardOnPop;

  const KeyboardDismissibleScreen({
    super.key,
    required this.child,
    this.dismissKeyboardOnPop = true,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        if (dismissKeyboardOnPop) {
          // Dismiss keyboard before popping
          final currentFocus = FocusManager.instance.primaryFocus;
          if (currentFocus != null && currentFocus.hasFocus) {
            currentFocus.unfocus();

            // Small delay to let keyboard animation complete
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }
      },
      child: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside input fields
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: child,
      ),
    );
  }
}

/// Extension to easily dismiss keyboard from anywhere
extension KeyboardDismiss on BuildContext {
  void dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }
}