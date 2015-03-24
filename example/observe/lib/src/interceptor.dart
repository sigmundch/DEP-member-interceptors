// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of observe;

/// The actual [observable] interceptor.
class _Interceptor {
  const _Interceptor();

  read(o, name, getter, setter) {
    var last = null;
    var _shouldRecord = _current != null;
    if (_shouldRecord) {
      last = _current;
      _current = _propObserver(o, name, getter, setter);
      if (last != null) last._dependsOn(_current);
    }
    var res = getter();
    if (_shouldRecord) _current = last;
    return res;
  }

  write(o, name, value, getter, setter) {
    var p = _propObserver(o, name, getter, setter);
    setter(value);
    p.update(value);
  }
}


/// Expando to cache binding information on each observable property.
final Expando<Map<Symbol, Binding>> _properties =
    new Expando<Map<Symbol, Binding>>();

_propObserver(model, name, getter, setter) {
  var map = _properties[model];
  if (map == null) _properties[model] = map = {};
  return map.putIfAbsent(name,
      () => new _ObservableProperty(name, getter, setter));
}

/// Node for an observable property in an object.
class _ObservableProperty<T> extends _Binding<T> {
  final Symbol name;
  final Function getter;
  final Function setter;

  _ObservableProperty(this.name, this.getter, this.setter);

  get _simpleString => '#$name';
  T get value => getter();
  set value(T v) => setter(v);

  var lastValue;
  update(value) {
    if (lastValue != value) {
      lastValue = value;
      _notify();
    }
  }
}
