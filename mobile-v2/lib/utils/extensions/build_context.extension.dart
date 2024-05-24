import 'package:flutter/material.dart';

extension BuildContextHelper on BuildContext {
  /// Get the current [ThemeData] used
  ThemeData get theme => Theme.of(this);

  /// Get the default [TextStyle]
  TextStyle get defaultTextStyle => DefaultTextStyle.of(this).style;

  /// Get the [Size] of [MediaQuery]
  Size get mediaQuerySize => MediaQuery.sizeOf(this);

  /// True if the current device is a Tablet
  bool get isTablet => (mediaQuerySize.width >= 600);
}
