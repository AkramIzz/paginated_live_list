import 'package:flutter/material.dart' hide Page;
import 'helpers/lru_set.dart';
import 'pagination_controller.dart';

class _WidgetAwarePagesSubscriptionsHandlerLruSetImpl<T>
    implements WidgetAwarePagesSubscriptionsHandler<T> {
  final PaginationController controller;

  _WidgetAwarePagesSubscriptionsHandlerLruSetImpl(
    this.controller, {
    int? maximumActiveSubscriptions,
  }) : _activeSubs = LruSet(maximumActiveSubscriptions ?? 5) {
    // if the controller already have active subscriptions we pause them all
    // since there's no way to tell which pages are visible.
    // instead of trying to guess, we rely on [onItemInitialized] calls to
    // resume the subscriptions to visible pages
    controller.subscriptions.forEach((sub) => sub.pause());
  }

  int get maximumActiveSubscriptions => _activeSubs.maximumSize;

  @override
  void onAppLifecycleChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      controller.subscriptions.forEach((s) => s.pause());
    } else if (state == AppLifecycleState.resumed) {
      _activeSubs.iterable().forEach((subIndex) {
        controller.subscriptions[subIndex].resume();
      });
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
      controller.subscriptions[subIndex].resume();
      final removedSub = _activeSubs.put(subIndex);
      if (removedSub != null) {
        controller.subscriptions[removedSub].pause();
      }
    }
  }

  int _resolvePageIndex(int index) {
    if (controller.hasFixedPageSize) {
      final pageSize = controller.current.pagesStates.first.page.items.length;
      return index ~/ pageSize;
    } else {
      final pagesCount = controller.current.pagesStates.length;
      int pageIndex = 0;
      for (; pageIndex < pagesCount; ++pageIndex) {
        final pageSize =
            controller.current.pagesStates[pageIndex].page.items.length;
        index -= pageSize;
        // the condition is put here to break before adding 1 to pageIndex
        if (index <= 0) break;
      }
      return pageIndex;
    }
  }

  final LruSet<int> _activeSubs;
}

abstract class WidgetAwarePagesSubscriptionsHandler<T> {
  factory WidgetAwarePagesSubscriptionsHandler(
    PaginationController controller, {
    int? maximumActiveSubscriptions,
  }) {
    return _WidgetAwarePagesSubscriptionsHandlerLruSetImpl(
      controller,
      maximumActiveSubscriptions: maximumActiveSubscriptions,
    );
  }

  void onAppLifecycleChanged(AppLifecycleState state);
  void onItemDisposed(int index);
  void onItemInitialized(int index);
}
