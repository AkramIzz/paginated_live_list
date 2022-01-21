import 'dart:async';

/// Returns a single-subscription stream that produces the same events as the
/// stream that [create] returns.
///
/// If [create] returns a single-subscription stream, the stream is subscribed
/// to once, and calls to pause and resume, pauses and resumes the underlying
/// stream.
///
/// If the returned stream is a broadcast stream, the stream is created and
/// subscribed to when its first and only subscriber is added, and each time the
/// stream is resumed after a pause. Calls to pause and resume cancels and
/// recreate the underlying stream.
Stream<T> asUnicastStream<T>({
  required Stream<T> Function() create,
  bool cancelOnError = false,
}) {
  late StreamController<T> controller;
  late StreamSubscription<T> subscription;
  late bool isBroadcast;

  void _cancelListener() {
    subscription.cancel();
  }

  void _startListener() {
    final stream = create();
    isBroadcast = stream.isBroadcast;
    subscription = stream.listen(
      (event) {
        controller.add(event);
      },
      onError: (error, st) {
        controller.addError(error, st);
      },
      onDone: () {
        _cancelListener();
        controller.close();
      },
      cancelOnError: cancelOnError,
    );
  }

  void _pauseListener() {
    if (isBroadcast) {
      _cancelListener();
    } else {
      subscription.pause();
    }
  }

  void _resumeListener() {
    if (isBroadcast) {
      _startListener();
    } else {
      subscription.resume();
    }
  }

  controller = StreamController<T>(
    onListen: _startListener,
    onCancel: _cancelListener,
    onPause: _pauseListener,
    onResume: _resumeListener,
    sync: true,
  );

  return controller.stream;
}
