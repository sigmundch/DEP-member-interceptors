// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library nonnull.test.nonnull_test;

import 'package:nonnull/nonnull.dart';
import 'package:unittest/unittest.dart';

@nonnull int i = 0;
int j = null;

class A {
  @nonnull int i;
  int j = 0;
}

main() {
  var a = new A();
  test('initial values are not checked', () {
    expect(i, 0);
    expect(a.i, isNull);
    expect(a.j, 0);
    expect(j, isNull);
  });

  test('write operations are checked', () {
    i = 1;
    j = 1;
    a.i = 1;
    a.j = 1;

    expect(() => i = null, throws);
    expect(i, 1);
    j = null;
    expect(j, isNull);
    expect(() => a.i = null, throws);
    expect(a.i, 1);
    a.j = null;
    expect(a.j, isNull);
  });
}
