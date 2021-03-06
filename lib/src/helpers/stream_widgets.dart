import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:paginated_live_list/src/helpers/behavior_stream.dart';

class BehaviorStreamListener<T> extends StatefulWidget {
  final BehaviorStream<T> stream;
  final void Function(BuildContext, T) listener;
  final bool Function(T previous, T next)? notifyWhen;
  final Widget child;

  const BehaviorStreamListener({
    Key? key,
    required this.stream,
    required this.listener,
    this.notifyWhen,
    required this.child,
  }) : super(key: key);

  @override
  _BehaviorStreamListenerState<T> createState() =>
      _BehaviorStreamListenerState<T>();
}

class _BehaviorStreamListenerState<T> extends State<BehaviorStreamListener<T>> {
  StreamSubscription<T>? _subscription;

  @override
  void initState() {
    super.initState();
    _listenToStream();
  }

  @override
  void didUpdateWidget(BehaviorStreamListener<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) {
      _subscription?.cancel();
      _listenToStream();
    }
  }

  void _listenToStream() {
    T previous = widget.stream.current;
    _subscription = widget.stream.skip(1).listen((event) {
      if (widget.notifyWhen?.call(previous, event) ?? true) {
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

class BehaviorStreamBuilder<T> extends StatefulWidget {
  final BehaviorStream<T> stream;
  final Widget Function(BuildContext context, T) builder;
  final bool Function(T previous, T next)? buildWhen;

  const BehaviorStreamBuilder({
    Key? key,
    required this.stream,
    required this.builder,
    this.buildWhen,
  }) : super(key: key);

  @override
  _BehaviorStreamBuilderState<T> createState() =>
      _BehaviorStreamBuilderState<T>();
}

class _BehaviorStreamBuilderState<T> extends State<BehaviorStreamBuilder<T>> {
  StreamSubscription<T>? _subscription;
  late T _lastEvent;

  @override
  void initState() {
    super.initState();
    _lastEvent = widget.stream.current;
    _listenToStream();
  }

  @override
  void didUpdateWidget(BehaviorStreamBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) {
      _subscription?.cancel();
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
    _subscription = widget.stream.skip(1).listen((event) {
      final shouldBuild = widget.buildWhen?.call(_lastEvent, event) ?? true;
      _lastEvent = event;
      if (shouldBuild) {
        setState(() {});
      }
    });
  }
}

class BehaviorStreamConsumer<T> extends StatefulWidget {
  final BehaviorStream<T> stream;
  final Widget Function(BuildContext context, T) builder;
  final void Function(BuildContext context, T) listener;
  final bool Function(T previous, T next)? notifyWhen;
  final bool Function(T previous, T next)? buildWhen;

  const BehaviorStreamConsumer({
    Key? key,
    required this.stream,
    required this.listener,
    this.notifyWhen,
    required this.builder,
    this.buildWhen,
  }) : super(key: key);

  @override
  _BehaviorStreamConsumerState<T> createState() =>
      _BehaviorStreamConsumerState<T>();
}

class _BehaviorStreamConsumerState<T> extends State<BehaviorStreamConsumer<T>> {
  StreamSubscription<T>? _subscription;
  late T _lastEvent;

  @override
  void initState() {
    super.initState();
    _lastEvent = widget.stream.current;
    _listenToStream();
  }

  @override
  void didUpdateWidget(BehaviorStreamConsumer<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) {
      _subscription?.cancel();
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
    _subscription = widget.stream.skip(1).listen((event) {
      final shouldNotify = widget.notifyWhen?.call(_lastEvent, event) ?? true;

      final shouldBuild = widget.buildWhen?.call(_lastEvent, event) ?? true;

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
