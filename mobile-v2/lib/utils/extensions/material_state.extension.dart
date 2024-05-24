import 'package:flutter/material.dart';

extension MaterialStateHelpers on Iterable<MaterialState> {
  bool get isDisabled => contains(MaterialState.disabled);
  bool get isDragged => contains(MaterialState.dragged);
  bool get isError => contains(MaterialState.error);
  bool get isFocused => contains(MaterialState.focused);
  bool get isHovered => contains(MaterialState.hovered);
  bool get isPressed => contains(MaterialState.pressed);
  bool get isScrolledUnder => contains(MaterialState.scrolledUnder);
  bool get isSelected => contains(MaterialState.selected);
}
