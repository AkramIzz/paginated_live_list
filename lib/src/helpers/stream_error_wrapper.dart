import 'dart:async';

import 'or_error.dart';

final orErrorWrapper = _StreamOrErrorWrapper();

/// A class that wraps streams to always emit OrError events.
///
/// All errors, including those raised within the callback before creating the
/// stream, are caught and added as events.
class _StreamOrErrorWrapper {
  Stream<OrError<T>> call<T>(Stream<T> callback()) {
    try {
      return callback().transform(StreamTransformer.fromHandlers(
        handleError: (error, st, sink) {
          sink.add(OrError.error(error, st));
        },
        handleData: (data, sink) {
          sink.add(OrError.value(data));
        },
      ));
    } catch (e, st) {
      return Stream.value(OrError.error(e, st));
    }
  }
}
