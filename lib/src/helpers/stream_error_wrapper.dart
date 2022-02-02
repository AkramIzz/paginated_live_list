import 'dart:async';

import 'result.dart';

final orErrorWrapper = _StreamOrErrorWrapper();

/// A class that wraps streams to always emit OrError events.
///
/// All errors, including those raised within the callback before creating the
/// stream, are caught and added as events.
class _StreamOrErrorWrapper {
  Stream<Result<T>> call<T>(Stream<T> callback()) {
    try {
      return callback().transform(StreamTransformer.fromHandlers(
        handleError: (error, st, sink) {
          sink.add(Result.error(error, st));
        },
        handleData: (data, sink) {
          sink.add(Result.value(data));
        },
      ));
    } catch (e, st) {
      return Stream.value(Result.error(e, st));
    }
  }
}
