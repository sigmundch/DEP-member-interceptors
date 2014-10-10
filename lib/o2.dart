import 'dart:mirrors';

Binding _current = null;

ignoreObservers(f) => (e) {
  var c = _current;
  _current = null;
  var r = f(e);
  _current = c;
  return r;
};

Binding observe(f) => new Expression(f);

class Interceptor {

  const Interceptor();

  read(o, name, original) {
    var last = null;
    var _shouldRecord = _current != null;
    if (_shouldRecord) {
      last = _current;
      _current = _propObserver(o, name);
      if (last != null) last.dependsOn(_current);
    }
    var res = original();
    if (_shouldRecord) _current = last;
    return res;
  }

  write(o, name, value, original) {
    var p = _propObserver(o, name);
    original(value);
    p.update(value);
  }
}

const observable = const Interceptor();

final Expando<Map<Symbol, Binding>> _properties =
    new Expando<Map<Symbol, Binding>>();

_propObserver(model, name) {
  var map = _properties[model];
  if (map == null) _properties[model] = map = {};
  return map.putIfAbsent(name, () => new ObservableProperty(model, name));
}

abstract class Binding<T> {
  bool _firstTime = false;
  List _listeners = null;

  T get value;

  Set<Binding> inDeps;
  Set<Binding> outDeps;

  dependsOn(other) {
    if (outDeps == null) outDeps = new Set();
    outDeps.add(other);
    other.usedBy(this);
  }

  usedBy(other) {
    if (inDeps == null) inDeps = new Set();
    inDeps.add(other);
  }

  _updateDependencies() {
    if (outDeps != null) {
      for (var o in outDeps) {
        o.inDeps.remove(this);
      }
      outDeps.clear();
    }
    _current = this;
    var _discard = value;
    _current = null;
  }

  listen(listener) {
    if (_listeners == null) {
      _listeners = [];
      _updateDependencies();
    }
    _listeners.add(listener);
    //print('listen on: $this');
  }

  notify([Set seen]) {
    if (_listeners == null && (inDeps == null || inDeps.isEmpty)) return;
    bool first = seen == null;
    if (first) seen = new Set();
    if (seen.contains(this)) return;
    seen.add(this);
    if (_listeners != null) {
      for (var callback in _listeners.toList()) {
        callback();
      }
    }
    if (inDeps != null) {
      for (var o in inDeps) {
        o.notify(seen);
      }
    }
    if (first) {
      seen.forEach((e) => e._updateDependencies());
    }
  }

  String toString() {
    var sb = new StringBuffer();
    _prettyPrint(sb, new Set());
    return sb.toString();
  }

  void _prettyPrint(sb, seen) {
    sb.write(simpleString);
    if (seen.contains(this)) return;
    seen.add(this);
    if (outDeps != null) {
      sb.write(' -> [');
      bool first = true;
      for (var o in outDeps) {
        if (!first) sb.write(', ');
        first = false;
        o._prettyPrint(sb, seen);
      }
      sb.write(']');
    }
  }

  get simpleString => '$value';
}

class Expression<T> extends Binding<T> {
  Function _read;
  Expression(this._read);

  T get value => _read();
}

class ObservableProperty<T> extends Binding<T> {
  final Object target;
  final Symbol name;

  ObservableProperty(this.target, this.name);

  get simpleString => '#$name';
  T get value => reflect(target).getField(name).reflectee;
  set value(T v) => reflect(target).setField(name, v).reflectee;

  var lastValue;
  update(value) {
    if (lastValue != value) {
      lastValue = value;
      notify();
    }
  }
}
