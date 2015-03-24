// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of observe;

/// A Binding is used to listen for observable changes on an expression or
/// property. Internally holds the current value of the expression/property and
/// how it depends on other observable expressions/properties.
abstract class _Binding<T> {
  bool _firstTime = false;
  List _listeners = null;

  T get value;

  Set<Binding> _inDeps;
  Set<Binding> _outDeps;

  _dependsOn(other) {
    if (_outDeps == null) _outDeps = new Set();
    _outDeps.add(other);
    other._usedBy(this);
  }

  _usedBy(other) {
    if (_inDeps == null) _inDeps = new Set();
    _inDeps.add(other);
  }

  _updateDependencies() {
    if (_outDeps != null) {
      for (var o in _outDeps) {
        o._inDeps.remove(this);
      }
      _outDeps.clear();
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
    if (_listeners == null && (_inDeps == null || _inDeps.isEmpty)) return;
    bool first = seen == null;
    if (first) seen = new Set();
    if (seen.contains(this)) return;
    seen.add(this);
    if (_listeners != null) {
      for (var callback in _listeners.toList()) {
        callback();
      }
    }
    if (_inDeps != null) {
      for (var o in _inDeps) {
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
    sb.write(_simpleString);
    if (seen.contains(this)) return;
    seen.add(this);
    if (_outDeps != null) {
      sb.write(' -> [');
      bool first = true;
      for (var o in _outDeps) {
        if (!first) sb.write(', ');
        first = false;
        o._prettyPrint(sb, seen);
      }
      sb.write(']');
    }
  }

  get _simpleString => '$value';
}
