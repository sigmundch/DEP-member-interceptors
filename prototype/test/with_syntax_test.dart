import 'common.dart';

class MyObject implements TestCaseInterface {
  int field1 with noDiff = 0;
  int field2 with incrementOnRead = 0;

  int x;

  int get getter with readWriteDiffs => x;
  set setter(int v) with readWriteDiffs => x = v;
}


main() {
  interceptorTests(new MyObject());
}
