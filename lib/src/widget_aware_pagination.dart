import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'helpers/lru_set.dart';
import 'pagination_controller.dart';

class _WidgetAwarePagesSubscriptionsHandlerLruSetImpl<T>
    implements WidgetAwarePagesSubscriptionsHandler<T> {
  final PaginationController controller;

  _WidgetAwarePagesSubscriptionsHandlerLruSetImpl(this.controller)
      : _activeSubs = LruSet(
            WidgetAwarePagesSubscriptionsHandler.maximumActiveSubscriptions) {
    // if the controller already have active subscriptions we pause them all
    // since there's no way to tell which pages are visible.
    // instead of trying to guess, we rely on [onItemInitialized] calls to
    // resume the subscriptions to visible pages
    controller.subscriptions.forEach((sub) => sub.pause());
  }

  int get maximumActiveSubscriptions => _activeSubs.maximumSize;

  Timer? _pauseTimer;
  @override
  void onAppLifecycleChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pauseTimer = Timer(
        WidgetAwarePagesSubscriptionsHandler.durationToPauseAfterAppPaused,
        () => controller.subscriptions.forEach((s) => s.pause()),
      );
    } else if (state == AppLifecycleState.resumed) {
      if (_pauseTimer == null) return;
      // if the subscriptions weren't paused.
      if (_pauseTimer!.isActive) {
        _pauseTimer!.cancel();
      } else {
        // This won't resume subs not in _activeSubs.
        // These are subs that were paused before, and the call to resume only
        // undoes one pause.
        controller.subscriptions.forEach((s) => s.resume());
      }
    }
  }

  @override
  void onItemDisposed(int index) {}

  @override
  void onItemInitialized(int index) {
    final pageIndex = _resolvePageIndex(index);
    _activateSub(pageIndex);
  }

  void _activateSub(int subIndex) {
    if (!_activeSubs.contains(subIndex)) {
      _resumeSubIfPaused(subIndex);
      final removedSub = _activeSubs.put(subIndex);
      if (removedSub != null) {
        _scheduleSubPause(removedSub);
      }
    }
  }

  final _timers = <int, Timer>{};
  void _scheduleSubPause(int subIndex) {
    _timers[subIndex] = Timer(
        WidgetAwarePagesSubscriptionsHandler.durationToPauseAfterPageSwap, () {
      _timers.remove(subIndex);
      controller.subscriptions[subIndex].pause();
    });
  }

  void _resumeSubIfPaused(int subIndex) {
    if (_timers[subIndex] != null) {
      // subscription haven't been paused yet
      _timers.remove(subIndex)!.cancel();
    } else {
      // subscription was paused
      controller.subscriptions[subIndex].resume();
    }
  }

  int _resolvePageIndex(int index) {
    final pagesStates = controller.current.pagesStates;
    int pageIndex = 0;
    for (; pageIndex < pagesStates.length; ++pageIndex) {
      final pageSize = pagesStates[pageIndex].page.items.length;
      index -= pageSize;
      // the condition is put here to break before adding 1 to pageIndex
      if (index <= 0) break;
    }
    return pageIndex;
  }

  final LruSet<int> _activeSubs;
}

abstract class WidgetAwarePagesSubscriptionsHandler<T> {
  factory WidgetAwarePagesSubscriptionsHandler(
      PaginationController<T> controller) {
    return _WidgetAwarePagesSubscriptionsHandlerLruSetImpl(controller);
  }

  void onAppLifecycleChanged(AppLifecycleState state);
  void onItemDisposed(int index);
  void onItemInitialized(int index);

  static var durationToPauseAfterAppPaused = const Duration(minutes: 5);
  static var durationToPauseAfterPageSwap = const Duration(seconds: 30);
  static var maximumActiveSubscriptions = 25;
  static var factory = defaultWidgetAwarePaginationSubscriptionsHandlerFactory;
}

WidgetAwarePagesSubscriptionsHandler<T>?
    defaultWidgetAwarePaginationSubscriptionsHandlerFactory<T>(
        PaginationController<T> controller) {
  return WidgetAwarePagesSubscriptionsHandler(controller);
}
