import 'dart:async';

import 'package:flutter/material.dart';
import 'package:paginated_live_list/src/app_lifecycle_listener.dart';
import 'package:paginated_live_list/src/helpers/provider.dart';
import 'package:paginated_live_list/src/helpers/stream_widgets.dart';
import 'package:paginated_live_list/src/pagination_controller.dart';
import 'package:paginated_live_list/src/widget_aware_pagination.dart';

class PaginationBehavior<T> extends StatefulWidget {
  const PaginationBehavior({
    Key? key,
    required this.child,
    required this.scrollController,
    this.kickStart = true,
  }) : super(key: key);

  final Widget child;
  final bool kickStart;
  final ScrollController scrollController;

  @override
  _PaginationBehaviorState<T> createState() => _PaginationBehaviorState<T>();
}

class _PaginationBehaviorState<T> extends State<PaginationBehavior<T>> {
  late WidgetAwarePagesSubscriptionsHandler subscriptionsHandler;
  late PaginationController<T> controller;

  @override
  void initState() {
    super.initState();

    widget.scrollController.addListener(onScrollEvent);

    scheduleMicrotask(() {
      if (widget.kickStart && controller.current.status == ListStatus.initial) {
        controller.loadNextPage();
      }
    });
  }

  @override
  void didUpdateWidget(covariant PaginationBehavior<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollController != oldWidget.scrollController) {
      oldWidget.scrollController.removeListener(onScrollEvent);
      widget.scrollController.addListener(onScrollEvent);
    }
  }

  void onScrollEvent() {
    if (_shouldLoadMore()) {
      _loadMore();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller = Provider.of<PaginationController<T>>(context)!;
    subscriptionsHandler = WidgetAwarePagesSubscriptionsHandler(controller);
  }

  bool _shouldLoadMore() {
    final extentAfter = widget.scrollController.position.extentAfter;
    return extentAfter < 128 && _canLoadMoreByScrolling();
  }

  bool _canLoadMoreByScrolling() {
    final status = controller.current.status;
    return status != ListStatus.loading &&
        status != ListStatus.reloading &&
        status != ListStatus.end &&
        status != ListStatus.error;
  }

  void _loadMore() {
    controller.loadNextPage();
  }

  @override
  Widget build(BuildContext context) {
    return AppLifecycleListener(
      listener: (context, state) {
        subscriptionsHandler.onAppLifecycleChanged(state);
      },
      child: BehaviorStreamListener<ListState<T>>(
        stream: controller,
        listener: (context, state) {
          // the scroll listener is called only when the scolling changes.
          // This creates a problem if the loaded page is smaller than screen
          // size, since the listener will not be called and hence next page
          // won't be loaded.
          // To solve this, we add a listener to the list state that is the
          // same as the scroll listener.
          Future(onScrollEvent);
        },
        child: widget.child,
      ),
    );
  }
}
