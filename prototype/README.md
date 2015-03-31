## prototype

This is a very raw prototype of the interceptor API. This includes the
[interface definitions][interceptor.dart] described in our proposal, and 3
implementations of a transformer to illustrate 3 of the syntax alternatives:

* [transformer.dart][] implements the default syntax using annotations. This
  transformation uses a normal Dart parser and can handle annotations on
  top-level properties and on fields.

* [with_syntax.dart][] implements the syntax of the form:
  `int x with interceptor = 1;`. This implementation is more brittle, it simply
  uses regular expressions to do the substitutions.

* [redirect_syntax.dart][] implements the syntax `int x >> interceptor = 1;`.
  This implentation is also brittle (very similar to the `with` syntax).

**Important Note**: for simplicity, and since this prototype is just for
illustration purposes, these implementations don't use type resolution. The
default implementation blindly assumes that all annotations are interceptors.
All implementations assume that interceptors implement both `ReadInterceptor`
and `WriteInterceptor`.  They support fields, getters, and setters, but there is
no support for methods at this time.

The [test][] folder illustrates how these transformers work. All tests are written
using field interceptors on classes, that way most of the code is in one shared
location ([common.dart][]) and the test for each syntax simply invokes the test
function their own test object. 

[interceptor.dart]: lib/interceptor.dart
[transformer.dart]: lib/transformer.dart
[with_syntax.dart]: lib/with_syntax.dart
[redirect_syntax.dart]: lib/redirect_syntax.dart
[test]: test/
[common.dart]: test/common.dart
