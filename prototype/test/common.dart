// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.


/// Common parts to all tests of this prototype. We included 3 implementations
/// based on the annotations, `>>` and `with` syntax, so that they can be
/// compared side-by-side.
///
/// This file declares the actual interceptor, the interface of the class
/// that will be annotated with interceptors, and the actual tests that access
/// an instance of this class to check that members are intercepted.
library test.common;

import 'package:unittest/unittest.dart';
import 'package:interceptor/interceptor.dart';

// This is the interface that each test will implement, we declare it here to
// make it simpler to write all tests together in a single file. However the
// actual interceptors are applied when this interface is implemented (see
// annotation_syntax_test.dart, with_syntax_test.dart, and
// redirect_syntax_test.dart).
abstract class TestCaseInterface {
  // To decorate with [noDiff], which under the multiple syntax alternatives
  // would be:
  //   @noDiff int field1;
  //   int field1 >> noDiff;
  //   int field1 with noDiff;
  int field1;
  int field2; // incrementOnRead

  int x; // Not decorated
  int get getter => x; // readWriteDiffs
  set setter(int v) => x = v; // readWriteDiffs
}

List<String> testLog = [];

/// This test illustrates a simple interceptor that logs information, and may
/// change the underlying value that is being intercepted in some way.
class TestInterceptor implements ReadInterceptor, WriteInterceptor {

  // When reading a value, return value + readDiff.
  final int readDiff;

  // Whether to increment the underlying value on a read operation (illustrates
  // you can have side-effects on reads!).
  final bool incrementOnRead;

  // When writing a field, write value + writeDiff, unless the value was 0, in
  // which case, simply write 0.
  final int nonZeroWriteDiff;

  const TestInterceptor({this.readDiff: 0, this.nonZeroWriteDiff: 0,
    this.incrementOnRead: false});

  /// This is the interceptor API in the proposal.
  get(target, member) => read(target, member.name,
      () => member.get(target), (v) => member.set(target, v));
  set(target, value, member) => write(target, member.name, value,
      () => member.get(target), (v) => member.set(target, v));

  /// This is the alternative API where `member` is flatten.
  read(o, name, getter, setter) {
    testLog.add('read $name (before)');
    var res = getter();
    if (incrementOnRead) {
      res++;
      setter(res);
    }
    testLog.add('read $name (after): $res');
    return res + readDiff;
  }

  write(o, name, value, getter, setter) {
    testLog.add('write $value to $name (before)');
    setter(value == 0 ? 0 : value + nonZeroWriteDiff);
    testLog.add('wrote $name (after)');
  }
}

const noDiff = const TestInterceptor();
const readWriteDiffs =
    const TestInterceptor(readDiff: 30, nonZeroWriteDiff: 10);
const incrementOnRead = const TestInterceptor(incrementOnRead: true);

/// These are the actual tests that access fields in `o` and show how
/// interceptors are doing their job.
void interceptorTests(TestCaseInterface o) {
  setUp(() {
    o.field1 = 0;
    o.field2 = 0;
    o.x = 0;
    testLog = [];
  });

  test('field read is intercepted', () {
    expect(testLog, []);
    var value = o.field1;
    expect(testLog, ['read ${#field1} (before)', 'read ${#field1} (after): 0']);
    expect(value, 0);
    value = o.field1;
    expect(testLog, [
      'read ${#field1} (before)',
      'read ${#field1} (after): 0',
      'read ${#field1} (before)',
      'read ${#field1} (after): 0'
    ]);
  });

  test('field write is intercepted', () {
    expect(testLog, []);
    o.field1 = 1;
    expect(testLog, [
      'write 1 to ${#field1} (before)',
      'wrote ${#field1} (after)'
    ]);
    expect(o.field1, 1);
    expect(testLog, [
      'write 1 to ${#field1} (before)',
      'wrote ${#field1} (after)',
      'read ${#field1} (before)',
      'read ${#field1} (after): 1'
    ]);
  });

  test('read interceptor can access setter', () {
    expect(o.field2, 1);
    expect(o.field2, 2);
    expect(o.field2, 3);
    expect(testLog, [
      'read ${#field2} (before)',
      'read ${#field2} (after): 1',
      'read ${#field2} (before)',
      'read ${#field2} (after): 2',
      'read ${#field2} (before)',
      'read ${#field2} (after): 3',
    ]);
  });

  test('getter is intercepted', () {
    var z = o.getter;
    expect(testLog, ['read ${#getter} (before)', 'read ${#getter} (after): 0']);
    expect(o.x, 0);
    expect(z, 30);
  });

  test('setter is interepted', () {
    o.setter = 2;
    expect(testLog, ['write 2 to ${#setter} (before)', 'wrote ${#setter} (after)']);
    expect(o.x, 12);
    expect(o.getter, 42);
  });
}
