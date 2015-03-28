// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// This library is a fun silly UI that renders in the command line in a way
/// that highlights observable changes.
///
/// The UI is composed of [View]s, which can be a layout, a label, a button, or
/// an input box. Label, buttons, and input boxes are bound to observable data.
/// The UI is a string that is updated asynchronously. It contains ANSII color
/// sequeneces to highlight portions that changed since the last time the UI was
/// printed.
library observe.example.ui;

import 'package:observe/observe.dart';
import 'dart:async';

linear(list, h) => new LinearLayout(list, h);
input(g, s) => new InputBox(g, s);
button(a, b) => new Button(a, b);
label(a) => new Label(a);

/// Base class for all views.
abstract class View {
  View parent;
  bool change = false;
  Binding draw;
 
  View() {
    /// Here is where all the magic happens (how we react and redraw changes
    /// asynchornously):
    /// - this call to observe will register any dependency we care about
    /// - synchronously observe will call `redraw` on any change
    /// - `redraw` will update the structure of this view-hierarchy, but we
    ///    won't print a new line until the end of the event loop.
    /// - if multiple changes occur, we'll render all of them together at the
    ///   end of the event loop.
    draw = observe(_renderWithChangeHighlight)..listen(redraw);
  }

  String _renderWithChangeHighlight() {
    var r = render();
    if (change) r = '[32m$r[0m';
    return r;
  }

  String render();

  reset() {
    change = false;
  }

  redraw({bool first: true}) {
    change = first;
    if (parent != null) {
      parent.redraw(first: false);
    } else {
      schedulePrint();
    }
  }

  bool scheduled = false;
  schedulePrint() async {
    if (scheduled) return;
    scheduled = true;

    // Wait to render until the end of this event-loop:
    await new Future.value(); 
    scheduled = false;
    print(_renderWithChangeHighlight());
    reset();
  }
}

/// A view that renders subviews in a liner fashion.
class LinearLayout extends View {
  List subviews;
  final String joiner;
  LinearLayout(this.subviews, bool horizontal)
      : joiner = horizontal ? '' : '\n' {
    subviews.forEach((v) => v.parent = this);
  }

  reset() {
    super.reset();
    subviews.forEach((s) => s.reset());
  }

  // Note: we ignore observers in subviews, since this view doesn't change when
  // the subviews do.
  String render() => 
      '${subviews.map(ignoreObservers((e) => e.draw.value)).join(joiner)}';
}

class Button extends View {
  var label;
  var action;
  Button(this.label, this.action);
  String render() => '<${label()}>';
  click() => action();
}

class InputBox extends View {
  var read;
  var write;
  InputBox(this.read, this.write);
  String render() => '_${read()}__';

  set value(v) => write(v);
}

class Label extends View {
  var label;
  Label(label)
      : label = label is Function ? label : (() => label);
  String render() => '${label()}';
}
