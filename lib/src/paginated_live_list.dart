import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'pagination_controller.dart';
import 'helpers/stream_widgets.dart';
import 'widget_aware_pagination.dart';

import 'app_lifecycle_listener.dart';
import 'widget_lifecycle_listener.dart';

class PaginatedLiveList<T> extends StatefulWidget {
  final PaginationController<T> controller;
  final bool kickStart;
  final Widget Function(BuildContext, ListState<T>, int) itemBuilder;
  final void Function(BuildContext context, Object? error)? onError;
  final Widget Function(BuildContext context)? progressBuilder;
  final Widget? noItemsWidget;
  final Axis scrollDirection;
  final bool reverse;
  final ScrollController? scrollController;
  final bool? primary;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsetsGeometry? padding;
  final double? itemExtent;
  final Widget? prototypeItem;
  final bool addAutomaticKeepAlives;
  final bool addRepaintBoundaries;
  final bool addSemanticIndexes;
  final double? cacheExtent;
  final int? semanticChildCount;
  final DragStartBehavior dragStartBehavior;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final String? restorationId;
  final Clip clipBehavior;

  const PaginatedLiveList({
    Key? key,
    required this.controller,
    this.kickStart = true,
    required this.itemBuilder,
    this.noItemsWidget,
    this.progressBuilder,
    this.onError,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.scrollController,
    this.primary,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
    this.itemExtent,
    this.prototypeItem,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.cacheExtent,
    this.semanticChildCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
  }) : super(key: key);

  @override
  _PaginatedLiveListState<T> createState() => _PaginatedLiveListState<T>();
}

class _PaginatedLiveListState<T> extends State<PaginatedLiveList<T>> {
  late final ScrollController scrollController;
  late final WidgetAwarePagesSubscriptionsHandler _subsHandler;

  @override
  void initState() {
    super.initState();
    scrollController = widget.scrollController ?? ScrollController();
    _subsHandler = WidgetAwarePagesSubscriptionsHandler(widget.controller);
    scrollController.addListener(() {
      if (_shouldLoadMore()) {
        _loadMore();
      }
    });
    if (widget.kickStart &&
        widget.controller.current.status == ListStatus.initial) {
      widget.controller.loadNextPage();
    }
  }

  @override
  void dispose() {
    widget.controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  bool _shouldLoadMore() {
    if (scrollController.position.extentAfter < 128) {
      return _canLoadMoreByScrolling();
    }
    return false;
  }

  bool _canLoadMoreByScrolling() {
    final status = widget.controller.current.status;
    return status != ListStatus.loading &&
        status != ListStatus.reloading &&
        status != ListStatus.end &&
        status != ListStatus.error;
  }

  void _loadMore() {
    widget.controller.loadNextPage();
  }

  @override
  Widget build(BuildContext context) {
    return AppLifecycleListener(
      listener: (context, state) {
        _subsHandler.onAppLifecycleChanged(state);
      },
      child: BehaviorStreamListener<ListState<T>>(
        stream: widget.controller,
        listener: (context, state) {
          // controller's listener is called only when the scolling changes.
          // This creates a problem if the loaded page is smaller than screen
          // size, since the listener will not be called and hence next page
          // won't be loaded.
          // To solve this, we add a listener to the list bloc state that is the
          // same as scoll controller's listener.
          Future(() {
            if (_shouldLoadMore()) {
              _loadMore();
            }
          });
        },
        child: BehaviorStreamConsumer<ListState<T>>(
          stream: widget.controller,
          notifyWhen: (prevState, nextState) {
            return prevState.status != nextState.status;
          },
          listener: (context, state) {
            if (state.status == ListStatus.error) {
              widget.onError?.call(context, state.error);
            }
          },
          builder: (context, state) {
            return ListView.builder(
              controller: scrollController,
              itemCount: state.items.length + 1,
              itemBuilder: (context, i) {
                if (i == state.items.length) {
                  if (state.status == ListStatus.loading) {
                    return Center(
                        child: widget.progressBuilder?.call(context) ??
                            Container());
                  } else if (state.status == ListStatus.end && i == 0) {
                    return widget.noItemsWidget ?? Container();
                  } else {
                    return Container();
                  }
                }

                return WidgetLifecycleListener(
                  onInitialized: () {
                    _subsHandler.onItemInitialized(i);
                  },
                  onDisposed: () {
                    _subsHandler.onItemDisposed(i);
                  },
                  child: widget.itemBuilder(context, state, i),
                );
              },
              addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
              addRepaintBoundaries: widget.addRepaintBoundaries,
              addSemanticIndexes: widget.addSemanticIndexes,
              cacheExtent: widget.cacheExtent,
              clipBehavior: widget.clipBehavior,
              dragStartBehavior: widget.dragStartBehavior,
              itemExtent: widget.itemExtent,
              keyboardDismissBehavior: widget.keyboardDismissBehavior,
              padding: widget.padding,
              physics: widget.physics,
              primary: widget.primary,
              prototypeItem: widget.prototypeItem,
              restorationId: widget.restorationId,
              reverse: widget.reverse,
              scrollDirection: widget.scrollDirection,
              semanticChildCount: widget.semanticChildCount,
              shrinkWrap: widget.shrinkWrap,
            );
          },
        ),
      ),
    );
  }
}
