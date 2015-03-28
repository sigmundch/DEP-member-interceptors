// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library interceptor.transformer.src.regex_based_transformer;

import 'dart:async';

import 'package:barback/barback.dart';
import 'snippets.dart';

abstract class RegexBasedTransformer extends Transformer {

  final String allowedExtensions = '.dart';

  // must have 4 groups: type, name, interceptor, body
  RegExp get fieldReg;

  // must have 4 groups: type, name, interceptor, body
  RegExp get topReg;

  // must have 4 groups: type, name, interceptor, body
  RegExp get getReg;

  // must have 5 groups: prefix (an optional type), name, args, interceptor, body
  RegExp get setReg;


  Future apply(Transform transform) async {
    var content = await transform.primaryInput.readAsString();
    var vars = new Set();
    var newContent = content.replaceAllMapped(fieldReg, (m) {
      var type = m.group(1);
      var name = m.group(2);
      var interceptor = m.group(3);
      var body = m.group(4);
      return '\n\n  // from: ${m.group(0).substring(3)}\n'
          '$type __\$$name $body\n'
          '${emitFlatGetter(type.trim(), name, interceptor, true)}'
          '${emitFlatSetter(type.trim(), name, interceptor, true)}';
    }).replaceAllMapped(topReg, (m) {
      var type = m.group(1);
      var name = m.group(2);
      var interceptor = m.group(3);
      var body = m.group(4);
      return '\n\n// from: ${m.group(0).substring(1)}\n'
          '$type __\$$name $body\n'
          '${emitFlatGetter(type.trim(), name, interceptor, false)}'
          '${emitFlatSetter(type.trim(), name, interceptor, false)}';
    }).replaceAllMapped(getReg, (m) {
      var type = m.group(1);
      var name = m.group(2);
      var interceptor = m.group(3);
      var body = m.group(4);
      return 
          '\n\n  // from: ${m.group(0).substring(3)}\n'
          '$type get __\$$name $body;\n'
          '${emitFlatGetter(type.trim(), name, interceptor, true)}';
    }).replaceAllMapped(setReg, (m) {
      var prefix = m.group(1);
      var name = m.group(2);
      var args = m.group(3);
      var tokens = args.split(' ');
      var type = tokens.length == 1 ? '' : tokens[0].trim();
      var interceptor = m.group(4);
      var body = m.group(5);
      return 
          '\n\n  // from: ${m.group(0).substring(3)}\n'
          '$prefix set __\$$name($args) $body;'
          '${emitFlatSetter(type, name, interceptor, true)}';
    });
    transform.addOutput(new
        Asset.fromString(transform.primaryInput.id, newContent));
  }
}

