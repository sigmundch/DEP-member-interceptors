// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of observe;

/// The actual [observable] interceptor.
class _Interceptor implements ReadInterceptor, WriteInterceptor {
  const _Interceptor();

  get(o, member) {
    var last = null;
    var _shouldRecord = _current != null;
    if (_shouldRecord) {
      last = _current;
      _current = _propObserver(o, member);
      if (last != null) last._dependsOn(_current);
    }
    var res = member.get(o);
    if (_shouldRecord) _current = last;
    return res;
  }

  set(o, value, member) {
    var p = _propObserver(o, member);
    member.set(o, value);
    p.update(value);
  }
}


/// Expando to cache binding information on each observable property.
final Expando<Map<Symbol, Binding>> _properties =
    new Expando<Map<Symbol, Binding>>();

_propObserver(model, member) {
  // TODO(sigmund): this is incorrect, we are mixing the model of multiple
  // libraries together, this might be a useful change in the proposal: pass
  // some form of library info for top-levels, maybe the library name?
  var key = model != null ? model : #observe;
  var map = _properties[key];
  if (map == null) _properties[key] = map = {};
  return map.putIfAbsent(member.name, () => 
      new _ObservableProperty(member.name,
        () => member.get(model), (v) => member.set(model, v)));
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
