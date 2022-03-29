import 'package:flutter/material.dart';

class Provider<T> extends StatefulWidget {
  static T? of<T>(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_InheritedProvider<T>>()
        ?.value;
  }

  const Provider(
      {Key? key, required this.create, this.dispose, required this.child})
      : value = null,
        super(key: key);

  const Provider.value({Key? key, required this.value, required this.child})
      : create = null,
        dispose = null,
        super(key: key);

  final T? value;
  final T Function(BuildContext)? create;
  final void Function(BuildContext, T)? dispose;
  final Widget child;

  @override
  State<Provider<T>> createState() => _ProviderState<T>();
}

class _ProviderState<T> extends State<Provider<T>> {
  T? value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (value != null && widget.create != null) {
      widget.dispose?.call(context, value!);
    }

    value = widget.value ?? widget.create!(context);
  }

  @override
  void didUpdateWidget(Provider<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value || widget.create != oldWidget.create) {
      if (widget.create != oldWidget.create) {
        widget.dispose?.call(context, value!);
      }

      value = widget.value ?? widget.create!(context);
    }
  }

  @override
  void dispose() {
    widget.dispose?.call(context, value!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedProvider<T>(value: value!, child: widget.child);
  }
}

class _InheritedProvider<T> extends InheritedWidget {
  _InheritedProvider({Key? key, required this.value, required this.child})
      : super(key: key, child: child);

  final T value;
  final Widget child;

  @override
  bool updateShouldNotify(_InheritedProvider oldWidget) =>
      value != oldWidget.value;
}
