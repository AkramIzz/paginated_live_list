import 'package:flutter/widgets.dart';

import 'pagination_controller.dart';
import 'helpers/stream_widgets.dart';
import 'widget_aware_pagination.dart';

import 'app_lifecycle_listener.dart';
import 'widget_lifecycle_listener.dart';

class LivePaginatedList<T> extends StatefulWidget {
  final PaginationController<T> controller;
  final ScrollController scrollController;
  final Widget Function(BuildContext, ListState<T>, int) itemBuilder;
  final void Function(BuildContext context, Object error) onError;
  final Widget Function(BuildContext context, Object error) errorMessageBuilder;
  final Widget Function(BuildContext context) progressBuilder;
  final ScrollPhysics physics;
  final Widget noItemsWidget;
  final bool kickStart;

  const LivePaginatedList({
    @required this.controller,
    this.scrollController,
    @required this.itemBuilder,
    this.noItemsWidget,
    this.errorMessageBuilder,
    this.progressBuilder,
    this.onError,
    this.physics,
    this.kickStart = true,
    Key key,
  }) : super(key: key);

  factory LivePaginatedList.separated({
    Key key,
    @required PaginationController controller,
    @required Widget Function(BuildContext, ListState<T>, int) itemBuilder,
    @required Widget Function(BuildContext, int) separatorBuilder,
    Widget noItemsWidget,
    Widget Function(BuildContext context, Object error) errorMessageBuilder,
    Widget Function(BuildContext context) progressBuilder,
    void Function(BuildContext context, Object error) onError,
    ScrollPhysics physics,
    bool kickStart = true,
  }) =>
      LivePaginatedList(
        controller: controller,
        itemBuilder: (context, state, index) {
          final int itemIndex = index ~/ 2;
          if (index.isEven) {
            return itemBuilder(context, state, itemIndex);
          } else {
            return separatorBuilder(context, itemIndex);
          }
        },
        noItemsWidget: noItemsWidget,
        errorMessageBuilder: errorMessageBuilder,
        progressBuilder: progressBuilder,
        onError: onError,
        physics: physics,
        kickStart: kickStart,
      );

  @override
  _LivePaginatedListState<T> createState() => _LivePaginatedListState<T>();
}

class _LivePaginatedListState<T> extends State<LivePaginatedList<T>> {
  ScrollController scrollController;
  WidgetAwarePagesSubscriptionsHandler _subsHandler;

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
              physics: widget.physics,
            );
          },
        ),
      ),
    );
  }
}
