/// Create a binding that observes changes when invoking the 0-arg function [f]
Binding observe(f) => new Expression(f);

/// Whether we are currently tracking dependencies between observable
/// expressions.
Binding _current = null;

/// Wrap a one-arg function [f] into a function taht ignores obververs
/// internally. This is useful if you want to track observability only in a
/// subset of the subexpressions.
ignoreObservers(f) => (e) {
  var c = _current;
  _current = null;
  var r = f(e);
  _current = c;
  return r;
};

/// The property-interceptor of observable properties that implements read and
/// write barriers. When attaching listeners the read barriers will record what
/// other observable fields are used when evaluating an expression.
const observable = const _Interceptor();

/// Implements [observable].
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
      () => new ObservableProperty(name, getter, setter));
}

/// A Binding is used to listen for observable changes on an expression or
/// property. Internally holds the current value of the expression/property and
/// how it depends on other observable expressions/properties.
abstract class Binding<T> {
  bool _firstTime = false;
  List _listeners = null;

  T get value;

  Set<Binding> inDeps;
  Set<Binding> outDeps;

  _dependsOn(other) {
    if (outDeps == null) outDeps = new Set();
    outDeps.add(other);
    other._usedBy(this);
  }

  _usedBy(other) {
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

  _notify([Set seen]) {
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
        o._notify(seen);
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

/// Node for an observable expression.
class Expression<T> extends Binding<T> {
  /// Closure that returns the current value of the expression.
  Function _read;
  Expression(this._read);

  T get value => _read();
}

/// Node for an observable property in an object.
class ObservableProperty<T> extends Binding<T> {
  final Symbol name;
  final Function getter;
  final Function setter;

  ObservableProperty(this.name, this.getter, this.setter);

  get simpleString => '#$name';
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
