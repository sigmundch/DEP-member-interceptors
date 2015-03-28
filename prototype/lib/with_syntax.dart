// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library interceptor.transformer.with_syntax;

import 'dart:async';

import 'package:barback/barback.dart';
import 'src/regex_based_transformer.dart';

class InterceptorTransformerWithWithSyntax extends RegexBasedTransformer {

  InterceptorTransformerWithWithSyntax.asPlugin();

  final RegExp fieldReg =
      new RegExp('\n( [ ]*[^ \n]\+) ([^ ]*) with ([^ ]*) ([^;]*;)');

  final RegExp topReg =
      new RegExp('\n([^ \n]\+) ([^ ]*) with ([^ ]*) ([^;]*;)');

  final RegExp getReg =
      new RegExp('\n( [ ]*[^ \n]*) get ([^ ]*) with ([^ ]*) (=>[^;]*|{[^}]*});');

  final RegExp setReg =
      new RegExp('([^s\n]*)set ([^\\(]*)\\(([^\)]*)\\) with ([^ ]*) (=>[^;]*|{[^}]*});');
}
