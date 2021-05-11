import 'dart:async';

import 'package:flutter/widgets.dart';

class StreamListener<T> extends StatefulWidget {
  final Stream<T> stream;
  final void Function(BuildContext, T) listener;
  final bool Function(T previous, T next) notifyWhen;
  final Widget child;

  const StreamListener({
    Key key,
    this.stream,
    this.listener,
    this.notifyWhen,
    this.child,
  }) : super(key: key);

  @override
  _StreamListenerState<T> createState() => _StreamListenerState<T>();
}

class _StreamListenerState<T> extends State<StreamListener<T>> {
  StreamSubscription<T> _subscription;

  @override
  void initState() {
    super.initState();
    _listenToStream();
  }

  @override
  void didUpdateWidget(StreamListener<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) {
      _subscription.cancel();
      _listenToStream();
    }
  }

  void _listenToStream() {
    T previous;
    _subscription = widget.stream.listen((event) {
      if (previous == null || (widget?.notifyWhen(previous, event) ?? true)) {
        previous = event;
        widget.listener(context, event);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class StreamConsumer<T> extends StatefulWidget {
  final Stream<T> stream;
  final Widget Function(BuildContext context, T) builder;
  final void Function(BuildContext context, T) listener;
  final bool Function(T previous, T next) notifyWhen;
  final bool Function(T previous, T next) buildWhen;

  const StreamConsumer({
    Key key,
    this.stream,
    this.listener,
    this.notifyWhen,
    this.builder,
    this.buildWhen,
  }) : super(key: key);

  @override
  _StreamConsumerState<T> createState() => _StreamConsumerState<T>();
}

class _StreamConsumerState<T> extends State<StreamConsumer<T>> {
  StreamSubscription<T> _subscription;
  T _lastEvent;

  @override
  void initState() {
    super.initState();
    _listenToStream();
  }

  @override
  void didUpdateWidget(StreamConsumer<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) {
      _subscription.cancel();
      _listenToStream();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _lastEvent);
  }

  void _listenToStream() {
    _subscription = widget.stream.listen((event) {
      final shouldNotify = _lastEvent == null ||
          (widget.notifyWhen?.call(_lastEvent, event) ?? true);

      final shouldBuild = _lastEvent == null ||
          (widget.buildWhen?.call(_lastEvent, event) ?? true);

      _lastEvent = event;

      if (shouldNotify) {
        widget.listener(context, event);
      }

      if (shouldBuild) {
        setState(() {});
      }
    });
  }
}
