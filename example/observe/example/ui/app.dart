// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// An example using `@observable` with a UI framework (well, a silly framework
/// that prints the UI as a string in the command line).
///
/// To see this example in action, from the `example/observe/` folder run:
///
///    pub run example/observe/ui/app.dart
library observe.example.ui.app;

import 'dart:io';
import 'dart:async';
import 'package:observe/observe.dart';
import 'ui.dart';

/// A data model with observable properties
class Model {
  // Note: these annotations are interceptors!
  @observable int i = 1;
  @observable int a = 1;
  @observable int b = 20;
  @observable bool which = true;
  @observable int get val => which ? a : b;
}

/// The "fancy" UI of the application, consists of a line with two input boxes
/// (to edit `model.a` and `model.b`, several labels (`a: `, `b: ` and a label
/// displaying the current value in `val`), and a button that toggles
/// `model.which`. This is rendered in a string as follows:
///
///      a: <input-box>, b: <input-box> <button> val: current_val
///
/// Internally the views listen for observable changes in parts of the model
/// used for rendering.
class UI {
  Model model = new Model();
  View root;
  var ia;
  var ib;
  var bt;
 
  UI() {
    ia = input(() => model.a, (v) => model.a = v);
    ib = input(() => model.b, (v) => model.b = v);

    bt = button(
        () => '${model.which ? 'picks a' : 'picks b'}',
        () => model.which = !model.which);

    root = linear([
        label('  a: '), ia,
        label(', b: '), ib,
        label('  '),
        bt, label(() => '  val: ${model.val} '),
    ], true);
  }
}

main() async {
  var u = new UI();
  var model = u.model;
  print('initial:     ${u.root.render()}');
  await _nextEventLoop();

  stdout.write('a++          ');
  model.a++;

  // We wait for the next event loop, otherwise this change and the next would
  // be combined and rendered together.
  await _nextEventLoop();

  model.which = false;
  stdout.write('toggle       ');
  await _nextEventLoop();

  model.which = true;
  stdout.write('toggle       ');
  await _nextEventLoop();

  model.b += 10;
  stdout.write('b += 10      ');
  await _nextEventLoop();

  model.which = false;
  stdout.write('toggle       ');
  await _nextEventLoop();

  model.b += 10;
  stdout.write('b += 10      ');
  await _nextEventLoop();

  model.a = 40;
  stdout.write('a = 40       ');
  await _nextEventLoop();

  // This step has no changes, so our UI system will not print a new copy of the
  // line. Instead, we print it here to show that nothing is green in the output
  // (there are no observable changes to highlight).
  model.a = 40;
  print('a = 40       ${u.root.render()}');
  await _nextEventLoop();

  model.which = true;
  stdout.write('toggle       ');
  await _nextEventLoop();

  // Likewise, no need to rerender for changes somewhere else in the app.
  model.i++;
  print('i++          ${u.root.render()}');
  await _nextEventLoop();

  // The "fancy" UI also can be used to interact with it directly (setting values
  // in "input boxes" and clicking "buttons"):
  print('-- interact via UI --');
  u.ia.value = 7;
  stdout.write('input a = 7  ');
  await _nextEventLoop();

  u.ib.value = 54;
  stdout.write('input b = 54 ');
  await _nextEventLoop();

  u.bt.click();
  stdout.write('click        ');
  await _nextEventLoop();

  u.bt.click();
  stdout.write('click        ');
}

_nextEventLoop() => new Future(() {});
