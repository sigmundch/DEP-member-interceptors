import 'common.dart';

class MyObject implements TestCaseInterface {
  @noDiff int field1 = 0;
  @incrementOnRead int field2 = 0;

  int x;

  @readWriteDiffs int get getter => x;
  @readWriteDiffs set setter(int v) => x = v;
}


main() {
  interceptorTests(new MyObject());
}
