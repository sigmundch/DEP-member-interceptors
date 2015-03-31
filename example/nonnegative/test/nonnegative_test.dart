// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library nonnegative.test.nonnegative_test;

import 'package:nonnegative/nonnegative.dart';
import 'package:unittest/unittest.dart';

@nonnegative int i = 0;
int j = -1;

class A {
  @nonnegative int i;
  int j = 0;
}

main() {
  var a = new A();
  test('initial values are not validated', () {
    expect(i, 0);
    expect(a.i, isNull);
    expect(a.j, 0);
    expect(j, -1);
  });

  test('write operations are validated', () {
    i = 1;
    j = 1;
    a.i = 1;
    a.j = 1;

    expect(() => i = -2, throws);
    expect(i, 1);
    j = -2;
    expect(j, -2);
    expect(() => a.i = -2, throws);
    expect(a.i, 1);
    a.j = -2;
    expect(a.j, -2);
  });
}
