import 'package:flutter/material.dart';
import 'package:paginated_live_list/paginated_live_list.dart';
import 'package:paginated_live_list/src/helpers/provider.dart';

class PaginationControllerProvider<T>
    extends Provider<PaginationController<T>> {
  const PaginationControllerProvider({
    Key? key,
    required PaginationController<T> Function(BuildContext) create,
    required Widget child,
  }) : super(
            key: key,
            create: create,
            child: child,
            dispose: _disposeController);

  const PaginationControllerProvider.value({
    Key? key,
    required PaginationController<T> controller,
    required Widget child,
  }) : super.value(key: key, value: controller, child: child);

  static Controller? of<T, Controller extends PaginationController<T>>(
      BuildContext context) {
    return Provider.of<PaginationController<T>>(context) as Controller?;
  }
}

void _disposeController<T>(
  BuildContext context,
  PaginationController<T> controller,
) {
  controller.dispose();
}

class WidgetAwareSubscriptionsHandlerProvider<T>
    extends Provider<WidgetAwarePagesSubscriptionsHandler<T>> {
  const WidgetAwareSubscriptionsHandlerProvider.create({
    Key? key,
    required WidgetAwarePagesSubscriptionsHandler<T> Function(BuildContext)
        create,
    required Widget child,
  }) : super(key: key, create: create, dispose: _disposeHandler, child: child);

  const WidgetAwareSubscriptionsHandlerProvider.value({
    Key? key,
    required WidgetAwarePagesSubscriptionsHandler<T> handler,
    required Widget child,
  }) : super.value(key: key, value: handler, child: child);

  WidgetAwareSubscriptionsHandlerProvider({
    Key? key,
    required Widget child,
  }) : super(create: _createHandler, dispose: _disposeHandler, child: child);

  static Handler?
      of<T, Handler extends WidgetAwarePagesSubscriptionsHandler<T>>(
          BuildContext context) {
    return Provider.of<WidgetAwarePagesSubscriptionsHandler<T>>(context)
        as Handler?;
  }
}

WidgetAwarePagesSubscriptionsHandler<T> _createHandler<T>(
    BuildContext context) {
  final controller = Provider.of<PaginationController<T>>(context)!;
  return WidgetAwarePagesSubscriptionsHandler(controller);
}

void _disposeHandler<T>(
  BuildContext context,
  WidgetAwarePagesSubscriptionsHandler<T> handler,
) {
  handler.dispose();
}
