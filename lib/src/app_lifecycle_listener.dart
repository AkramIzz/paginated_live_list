import 'package:flutter/material.dart';

class AppLifecycleListener extends StatefulWidget {
  final Widget child;
  final void Function(BuildContext context, AppLifecycleState state) listener;

  AppLifecycleListener({
    @required this.child,
    @required this.listener,
  });

  @override
  _AppLifecycleListenerState createState() => _AppLifecycleListenerState();
}

class _AppLifecycleListenerState extends State<AppLifecycleListener>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance?.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.listener(context, state);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
