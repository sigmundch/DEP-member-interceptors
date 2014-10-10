import 'package:o2/o2.dart';

class Counter extends Observable {
  //expansion of: int i >> observable = 1;
  int _i = 1;
  int get i => observable.read(this, #i, () => _i);
  set i(value) => observable.write(this, #i, value, (v) => _i = v);
}

class UI extends Observable {
  Counter counter = new Counter();
  //expansion of: String text >> observable = counter.i;
  String get text => '${observable.read(this, #text, () => counter.i)}';



  //expansion of: int a >> observable = 1;
  int _a = 1;
  int get a => observable.read(this, #a, () => _a);
  set a(value) => observable.write(this, #a, value, (v) => _a = v);

  //expansion of: int b >> observable = 20;
  int _b = 20;
  int get b => observable.read(this, #b, () => _b);
  set b(value) => observable.write(this, #b, value, (v) => _b = v);

  //expansion of: bool which >> observable = false;
  bool _which = true;
  bool get which => observable.read(this, #which, () => _which);
  set which(value) => observable.write(this, #which, value, (v) => _which = v);

  //expansion of: int get val >> observable => which ? a : b;
  int get val => observable.read(this, #val, () => which ? a : b);
}


main() {
 var u = new UI();
 u.listen(#text, () => print(u.text));
 u.listen(#val, () => print('-> ${u.val}'));
 u.a++;
 u.which = false;
 u.which = true;
 u.b += 10;
 print('__');
 u.which = false;
 u.b += 10;
 u.a++;
 print('__');
 u.which = true;
 u.counter.i = 3;
 u.counter.i = 4;
 u.counter.i = 5;
}
