import 'common.dart';

class MyObject implements TestCaseInterface {
  int field1 >> noDiff = 0;
  int field2 >> incrementOnRead = 0;

  int x;

  int get getter >> readWriteDiffs => x;
  set setter(int v) >> readWriteDiffs => x = v;
}


main() {
  interceptorTests(new MyObject());
}
