import 'package:flutter/material.dart';
import 'package:paginated_live_list/src/helpers/provider.dart';
import 'package:paginated_live_list/src/helpers/stream_widgets.dart';
import 'package:paginated_live_list/src/pagination_controller.dart';
import 'package:paginated_live_list/src/widget_aware_pagination.dart';
import 'package:paginated_live_list/src/widget_lifecycle_listener.dart';

class PaginatedViewBuilder<T> extends StatelessWidget {
  const PaginatedViewBuilder({
    Key? key,
    required this.builder,
    this.listener,
  }) : super(key: key);

  final Widget Function(BuildContext context, ListState<T> state) builder;
  final void Function(BuildContext context, ListState<T> state)? listener;

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<PaginationController<T>>(context)!;

    Widget widget = BehaviorStreamBuilder(
      stream: controller,
      builder: builder,
    );

    if (listener != null) {
      widget = BehaviorStreamListener(
        stream: controller,
        listener: listener!,
        child: widget,
      );
    }

    return widget;
  }
}

class PageItem<T> extends StatelessWidget {
  const PageItem({
    Key? key,
    required this.index,
    required this.item,
    required this.child,
  }) : super(key: key);

  final int index;
  final T item;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final subsHandler =
        Provider.of<WidgetAwarePagesSubscriptionsHandler<T>>(context);
    Widget widget = KeyedSubtree(
      key: ValueKey(item),
      child: child,
    );

    if (subsHandler != null) {
      widget = WidgetLifecycleListener(
        onInitialized: () {
          subsHandler.onItemInitialized(index);
        },
        onDisposed: () {
          subsHandler.onItemDisposed(index);
        },
        child: widget,
      );
    }

    return widget;
  }
}

class PaginationIndicatorBuilder<T> extends StatelessWidget {
  const PaginationIndicatorBuilder({
    Key? key,
    required this.state,
    this.progressBuilder,
    this.emptyListIndicator,
    this.errorBuilder,
  }) : super(key: key);

  final ListState<T> state;
  final Widget Function(BuildContext context)? progressBuilder;
  final Widget? emptyListIndicator;
  final Widget Function(BuildContext context, Object? error)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    if (state.status == ListStatus.loading) {
      return Center(child: progressBuilder?.call(context) ?? const SizedBox());
    } else if (state.status == ListStatus.end && state.items.isEmpty) {
      return emptyListIndicator ?? const SizedBox();
    } else if (state.status == ListStatus.error) {
      return errorBuilder?.call(context, state.pagesStates.last.error) ??
          const SizedBox();
    } else {
      return SizedBox();
    }
  }
}
