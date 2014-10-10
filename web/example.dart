import 'dart:io';
import 'dart:async';
import 'package:o2/o2.dart';
import 'package:o2/ui.dart';

class Model {
  int i >> observable = 1;
  int a >> observable = 1;
  int b >> observable = 20;
  bool which >> observable = true;
  int get val >> observable => which ? a : b;
}

int j >> observable = 3;

class UI {
  Model model = new Model();
  View root;
  var ia;
  var ib;
  var bt;
 
  UI() {
    //ia = input(model.&a);
    //ib = input(model.&b);

    ia = input(() => model.a, (v) => model.a = v);
    ib = input(() => model.b, (v) => model.b = v);

    bt = button(
        () => '${model.which ? 'on' : 'off'}',
        () => model.which = !model.which);

    root = linear([
        label('  a: '), ia,
        label(', b: '), ib,
        label(() => '  current: ${model.val} $j '), bt,
    ], true);
  }
}



main() {
 var u = new UI();
 var model = u.model;
 print('initial:     ${u.root.render()}');

 new Future.value().then((_) {
   stdout.write('a++          ');
   model.a++;
 }).then((_) => new Future.value()).then((_) {
   stdout.write('toggle       ');
   model.which = false;
 }).then((_) => new Future.value()).then((_) {
   stdout.write('toggle       ');
   model.which = true;
 }).then((_) => new Future.value()).then((_) {
   stdout.write('b += 10      ');
   model.b += 10;
 }).then((_) => new Future.value()).then((_) {
   stdout.write('toggle       ');
   model.which = false;
 }).then((_) => new Future.value()).then((_) {
   stdout.write('b += 10      ');
   model.b += 10;
 }).then((_) => new Future.value()).then((_) {
   stdout.write('a = 40       ');
   model.a = 40;
 }).then((_) => new Future.value()).then((_) {
   print('a = 40       ${u.root.render()}');
   model.a = 40;
 }).then((_) => new Future.value()).then((_) {
   stdout.write('toggle       ');
   model.which = true;
 }).then((_) => new Future.value()).then((_) {
   print('i++          ${u.root.render()}');
   model.i++;
   j++;



 }).then((_) => new Future.value()).then((_) {
   print('-- interact via UI --');
   stdout.write('input a = 7  ');
   u.ia.value = 7;
 }).then((_) => new Future.value()).then((_) {
   stdout.write('input b = 54 ');
   u.ib.value = 54;
 }).then((_) => new Future.value()).then((_) {
   stdout.write('click        ');
   u.bt.click();
 }).then((_) => new Future.value()).then((_) {
   stdout.write('click        ');
   u.bt.click();
 });
}
