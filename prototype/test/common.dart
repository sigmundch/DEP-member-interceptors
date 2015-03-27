library test.common;

import 'package:unittest/unittest.dart';

List<String> testLog = [];

class TestInterceptor {
  // when reading a field, return field + readDiff
  final int readDiff;

  final bool incrementOnRead;

  // when writing a field, write value + writeDiff, unless the value was 0, in
  // which case, simply write 0.
  final int nonZeroWriteDiff;
  const TestInterceptor({this.readDiff: 0, this.nonZeroWriteDiff: 0,
    this.incrementOnRead: false});

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

// this is the interface that each test will implement, we declare it here to
// make it simpler to write all tests together.
abstract class TestCaseInterface {
  // For [noDiff], which under the multiple syntax alternatives would be:
  //   @noDiff int field1;
  //   int field1 >> noDiff;
  //   int field1 with noDiff;
  int field1;
  int field2; // incrementOnRead

  int x; // Not decorated
  int get getter => x; // readWriteDiffs
  set setter(int v) => x = v; // readWriteDiffs
}

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
