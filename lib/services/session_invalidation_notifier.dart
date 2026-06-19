import 'package:flutter/foundation.dart';

class SessionInvalidationNotifier extends ChangeNotifier {
  SessionInvalidationNotifier._();

  static final instance = SessionInvalidationNotifier._();

  void notifySessionInvalidated() {
    notifyListeners();
  }
}
