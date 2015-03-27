// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library interceptor.transformer.redirect_syntax;

import 'dart:async';

import 'package:barback/barback.dart';

class InterceptorTransformerWithRedirectSyntax extends Transformer {

  InterceptorTransformerWithRedirectSyntax.asPlugin();

  final String allowedExtensions = '.dart';

  static final RegExp _fieldReg =
      new RegExp('\n( [ ]*[^ \n]\+) ([^ ]*) >> ([^ ]*) ([^;]*;)');

  static final RegExp _topReg =
      new RegExp('\n([^ \n]\+) ([^ ]*) >> ([^ ]*) ([^;]*;)');

  static final RegExp _getReg =
      new RegExp('\n( [ ]*[^ \n]*) get ([^ ]*) >> ([^ ]*) (=>[^;]*|{[^}]*});');

  static final RegExp _setReg =
      new RegExp('([^s\n]*)set ([^\\(]*)\\(([^\)]*)\\) >> ([^ ]*) (=>[^;]*|{[^}]*});');


  Future apply(Transform transform) {
    return transform.primaryInput.readAsString().then((content) {
      var newContent = content.replaceAllMapped(_fieldReg, (m) {
        var type = m.group(1);
        var name = m.group(2);
        var interceptor = m.group(3);
        var body = m.group(4);
        return '\n\n  // from: ${m.group(0).substring(3)}\n'
            '$type _$name $body\n'
            '$type get $name => $interceptor.read(this, #$name, () => _$name,'
                ' (__v) => _$name = __v);\n'
            '  set $name($type __value) => '
                '$interceptor.write(this, #$name, __value, () => _$name,'
                    '(__v) => _$name = __v);';
      }).replaceAllMapped(_topReg, (m) {
        var type = m.group(1);
        var name = m.group(2);
        var interceptor = m.group(3);
        var body = m.group(4);
        return '\n\n// from: ${m.group(0).substring(1)}\n'
            '$type _$name $body\n'
            '$type get $name => $interceptor.read(null, #$name, () => _$name,'
                ' (__v) => _$name = __v);\n'
            'set $name($type __value) => '
                '$interceptor.write(null, #$name, __value, () => _$name,'
                    '(__v) => _$name = __v);';
      }).replaceAllMapped(_getReg, (m) {
        var type = m.group(1);
        var name = m.group(2);
        var interceptor = m.group(3);
        var body = m.group(4);
        return 
            '\n\n  // from: ${m.group(0).substring(3)}\n'
            '$type get _$name $body;\n'
            '$type get $name => $interceptor.read(this, #$name, () => _$name, null);';
      }).replaceAllMapped(_setReg, (m) {
        var prefix = m.group(1);
        var name = m.group(2);
        var args = m.group(3);
        var interceptor = m.group(4);
        var body = m.group(5);
        return 
            '\n\n  // from: ${m.group(0).substring(3)}\n'
            '$prefix set _$name($args) $body;\n'
            '$prefix set $name(v) => $interceptor.write(this, #$name, v,'
                ' () => _$name, (v) => _$name = v);';
      });
      transform.addOutput(new
          Asset.fromString(transform.primaryInput.id, newContent));
    });
  }
}
