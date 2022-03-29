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
    controller.subscriptions.values.forEach((sub) => sub.pause());
  }

  int get maximumActiveSubscriptions => _activeSubs.maximumSize;

  Timer? _pauseTimer;
  @override
  void onAppLifecycleChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pauseTimer = Timer(
        WidgetAwarePagesSubscriptionsHandler.durationToPauseAfterAppPaused,
        () => controller.subscriptions.values.forEach((s) => s.pause()),
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
        controller.subscriptions.values.forEach((s) => s.resume());
      }
    }
  }

  @override
  void onItemDisposed(int index) {}

  @override
  void onItemInitialized(int index) {
    final pageKey = _resolvePageKey(index);
    _activateSub(pageKey);
  }

  void _activateSub(PageKey key) {
    if (!_activeSubs.contains(key)) {
      _resumeSubIfPaused(key);
      final removedSub = _activeSubs.put(key);
      if (removedSub != null) {
        _scheduleSubPause(removedSub);
      }
    }
  }

  final _timers = <PageKey, Timer>{};
  void _scheduleSubPause(PageKey key) {
    _timers[key] = Timer(
        WidgetAwarePagesSubscriptionsHandler.durationToPauseAfterPageSwap, () {
      _timers.remove(key);
      controller.subscriptions[key]?.pause();
    });
  }

  void _resumeSubIfPaused(PageKey key) {
    if (_timers[key] != null) {
      // subscription haven't been paused yet
      _timers.remove(key)!.cancel();
    } else {
      // subscription was paused
      controller.subscriptions[key]?.resume();
    }
  }

  PageKey _resolvePageKey(int index) {
    final pagesStates = controller.current.pagesStates;
    int pageIndex = 0;
    for (; pageIndex < pagesStates.length; ++pageIndex) {
      final pageSize = pagesStates[pageIndex].page.items.length;
      index -= pageSize;
      // the condition is put here to break before adding 1 to pageIndex
      if (index <= 0) break;
    }
    return pagesStates[pageIndex].key;
  }

  @override
  void dispose() {
    _timers.values.forEach((timer) => timer.cancel());
    _pauseTimer?.cancel();
  }

  final LruSet<PageKey> _activeSubs;
}

abstract class WidgetAwarePagesSubscriptionsHandler<T> {
  factory WidgetAwarePagesSubscriptionsHandler(
      PaginationController<T> controller) {
    return _WidgetAwarePagesSubscriptionsHandlerLruSetImpl(controller);
  }

  void onAppLifecycleChanged(AppLifecycleState state);
  void onItemDisposed(int index);
  void onItemInitialized(int index);
  void dispose();

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
