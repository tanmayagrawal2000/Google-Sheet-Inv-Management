import 'dart:async';

import 'package:flutter/foundation.dart';

/// Adapts one or more [Stream]s into a [Listenable] so GoRouter re-evaluates
/// its redirect whenever any of the streams emits.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream)
      : _subscriptions = [] {
    notifyListeners();
    _subscriptions.add(
        stream.asBroadcastStream().listen((_) => notifyListeners()));
  }

  GoRouterRefreshStream.multi(List<Stream<dynamic>> streams)
      : _subscriptions = [] {
    notifyListeners();
    for (final s in streams) {
      _subscriptions.add(
          s.asBroadcastStream().listen((_) => notifyListeners()));
    }
  }

  final List<StreamSubscription<dynamic>> _subscriptions;

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}
