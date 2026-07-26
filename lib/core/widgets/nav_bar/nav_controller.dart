import 'package:flutter/foundation.dart';

class NavController extends ValueNotifier<int> {
  NavController(super.initialIndex);

  void select(int index) {
    if (index != value) {
      value = index;
    }
  }
}
