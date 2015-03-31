// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Declares the interceptor APIs. This would eventually be part of a `dart:`
// library.
library interceptor;

/// An interceptor that captures read operations.
abstract class ReadInterceptor {
  get(target, Member member);
}

/// An interceptor that captures write operations.
abstract class WriteInterceptor {
  set(target, value, Member member);
}

/// An interceptor that captures invokations.
abstract class InvokeInterceptor {
  invoke(target, List positionalArguments, Map<Symbol,dynamic> namedArguments,
      Member member);
}

/// An interceptor of everything...
abstract class Interceptor implements
    ReadInterceptor, WriteInterceptor, InvokeInterceptor {
}

abstract class Member {
  final Symbol name;
  const Member(this.name);
  get(target);
  set(target, value);
  invoke(target, List positionalArguments, Map<Symbol, dynamic> namedArguments);
}
