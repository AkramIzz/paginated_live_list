import 'package:flutter/foundation.dart';

class _ErrorHolder {
  final Object error;
  final StackTrace stackTrace;

  _ErrorHolder(this.error, this.stackTrace);
}

abstract class OrError<V> {
  OrError._();

  factory OrError.value(V value) => _Value<V>._(value);
  factory OrError.error(Object e, StackTrace st) =>
      _Error<V>._(_ErrorHolder(e, st));

  _Error<V> get _asError => this as _Error<V>;
  _Value<V> get _asValue => this as _Value<V>;

  bool get isError;
  bool get isValue;

  /// use in places where `this` is guaranteed to be a value
  V get asValue => (this as _Value<V>)._value;

  /// use in places where `this` is guaranteed to be an error
  _ErrorHolder get asError => (this as _Error<V>)._error;

  R incase<R>({
    @required R Function(V v) value,
    @required R Function(_ErrorHolder e) error,
  }) {
    return this.isValue
        ? value(this._asValue._value)
        : error(this._asError._error);
  }

  OrError<VM> mapValue<VM>(
    VM Function(V v) value,
  ) {
    return this.isValue
        ? OrError.value(
            (value).call(this._asValue._value),
          )
        : this;
  }

  Stream<R> asyncIncase<R>({
    Stream<R> Function(V v) value,
    Stream<R> Function(_ErrorHolder e) error,
  }) {
    return this.isValue
        ? value?.call(this._asValue._value) ?? Stream.empty()
        : error?.call(this._asError._error) ?? Stream.empty();
  }
}

class _Value<V> extends OrError<V> {
  _Value._(this._value) : super._();

  final V _value;

  @override
  bool get isError => false;

  @override
  bool get isValue => true;
}

class _Error<V> extends OrError<V> {
  _Error._(this._error) : super._();

  final _ErrorHolder _error;

  @override
  bool get isError => true;

  @override
  bool get isValue => false;
}
