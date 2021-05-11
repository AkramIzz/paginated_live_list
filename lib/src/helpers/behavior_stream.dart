import 'dart:async';

import 'package:flutter/foundation.dart';

abstract class BehaviorStream<T> extends Stream<T> {
  /// the last emitted event
  T get current;

  /// Adds a subscription to this stream ignoring first event
  ///
  /// implementers must not call [listen] or transform `this`, instead
  /// listen or transform the internal stream
  @protected
  StreamSubscription<T> listenToNewEvents(void onData(T event),
      {Function onError, void onDone(), bool cancelOnError});

  @override
  StreamSubscription<T> listen(void onData(T event),
      {Function onError, void onDone(), bool cancelOnError}) {
    return Stream.value(current).transform(StreamTransformer<T, T>.fromHandlers(
      handleDone: (sink) {
        listenToNewEvents(
          sink.add,
          onError: sink.addError,
          onDone: sink.close,
          cancelOnError: cancelOnError,
        );
      },
    )).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
