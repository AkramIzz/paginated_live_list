import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:paginated_live_list/src/basic/pagination_behavior.dart';
import 'package:paginated_live_list/src/basic/providers.dart';
import 'package:paginated_live_list/src/basic/view_builder.dart';
import 'package:paginated_live_list/src/helpers/provider.dart';

import 'package:paginated_live_list/src/pagination_controller.dart';

class PaginatedLiveList<T> extends StatefulWidget {
  /// if null, it's expected that a `PaginationControllerProvider` will provide
  /// the controller.
  final PaginationController<T>? controller;
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

  @override
  void initState() {
    super.initState();
    scrollController = widget.scrollController ?? ScrollController();
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PaginationControllerProvider<T>.value(
      controller:
          widget.controller ?? Provider.of<PaginationController<T>>(context)!,
      child: WidgetAwareSubscriptionsHandlerProvider<T>(
        child: PaginationBehavior<T>(
          scrollController: scrollController,
          kickStart: widget.kickStart,
          child: PaginatedViewBuilder<T>(
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
                    return PaginationIndicatorBuilder(state: state);
                  }

                  return PageItem<T>(
                    index: i,
                    item: state.items[i],
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
      ),
    );
  }
}
