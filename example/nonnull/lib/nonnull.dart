// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library nonnull;

import 'package:interceptor/interceptor.dart';

const nonnull = const _NonNullInterceptor();

/// An interceptor that checks that you never set a null value on a field.
class _NonNullInterceptor implements WriteInterceptor {
  const _NonNullInterceptor();

  // TODO(sigmund): This method here won't be needed on a real implementation.
  // The current propotype doesn't do resolution, so it always adds the
  // interceptor for reads and writes (even though this is supposed to be a
  // write-only interceptor).
  get(o, member) => member.get(o);

  set(o, value, member) {
    if (value == null) throw "Can't set a null value to ${member.name}";
    member.set(o, value);
  }
}


