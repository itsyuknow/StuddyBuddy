import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class MobileWrapper extends StatelessWidget {
  final Widget child;

  // Mobile device dimensions
  static const double mobileWidth = 450.0;
  static const double mobileHeight = 950.0;

  const MobileWrapper({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      // On mobile platforms, just return the child
      return child;
    }

    // On web, force mobile container view
    return Material(
      color: Colors.black,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Center(
          child: Container(
            width: mobileWidth,
            height: mobileHeight,
            decoration: BoxDecoration(
              color: Colors.black,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: ClipRect(
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: const Size(mobileWidth - 8, mobileHeight - 8),
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}