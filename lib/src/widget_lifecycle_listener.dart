import 'package:flutter/material.dart';

/// A widget lifecycle listener
///
/// Instead of having to write a stateful widget, use this widget to wrap the
/// widget of interest
class WidgetLifecycleListener extends StatefulWidget {
  final Widget child;
  final void Function() onDisposed;
  final void Function() onInitialized;

  const WidgetLifecycleListener({
    @required this.onInitialized,
    @required this.onDisposed,
    @required this.child,
    Key key,
  }) : super(key: key);

  @override
  _WidgetLifecycleListenerState createState() =>
      _WidgetLifecycleListenerState();
}

class _WidgetLifecycleListenerState extends State<WidgetLifecycleListener> {
  @override
  void initState() {
    super.initState();
    widget.onInitialized();
  }

  @override
  dispose() {
    widget.onDisposed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
