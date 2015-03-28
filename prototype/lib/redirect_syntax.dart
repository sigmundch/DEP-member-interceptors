// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library interceptor.transformer.redirect_syntax;

import 'dart:async';

import 'package:barback/barback.dart';
import 'src/regex_based_transformer.dart';

class InterceptorTransformerWithRedirectSyntax extends RegexBasedTransformer {

  InterceptorTransformerWithRedirectSyntax.asPlugin();

  final RegExp fieldReg =
      new RegExp('\n( [ ]*[^ \n]\+) ([^ ]*) >> ([^ ]*) ([^;]*;)');

  final RegExp topReg =
      new RegExp('\n([^ \n]\+) ([^ ]*) >> ([^ ]*) ([^;]*;)');

  final RegExp getReg =
      new RegExp('\n( [ ]*[^ \n]*) get ([^ ]*) >> ([^ ]*) (=>[^;]*|{[^}]*});');

  final RegExp setReg =
      new RegExp('([^s\n]*)set ([^\\(]*)\\(([^\)]*)\\) >> ([^ ]*) (=>[^;]*|{[^}]*});');

}
