// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library nonnull;

import 'package:interceptor/interceptor.dart';

const nonnull = const _NonNullInterceptor();

/// An interceptor that checks that you never set a null value on a field.
class _NonNullInterceptor implements WriteInterceptor {
  const _NonNullInterceptor();

  // TODO(sigmund): the current propotype always injects the get call,
  // eventually when we include resolution in it, we wont need to, and hence we
  // wont need to include this code either:
  get(o, member) => member.get(o);

  set(o, value, member) {
    if (value == null) throw "Can't set a null value to ${member.name}";
    member.set(o, value);
  }
}


