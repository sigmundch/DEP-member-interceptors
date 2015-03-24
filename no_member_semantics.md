## Member Interceptors semantics without Member

This document is a suplement of the [member interceptors proposal][proposal].
The initial proposal uses a const class `Member` to make it easy to pass data
from the system to the interceptor. This document explains the same semantics
but if the contents of `Member` are inlined directly in the intercepting API.

### Semantics

A redirecting member declaration is either:
* a redirecting field declaration
* a redirecting method declaration
* a redirecting getter declaration
* a redirecting setter declaration

#### A redirecting field declaration

```dart
var memberName >> constObjectExpression  [= e];
```

is equivalent to the declarations

```dart
_f = e;
get memberName => constObjectExpression.get(target, #memberName, _g, _s);
set memberName(v) => constObjectExpression.set(target, #memberName, v,  _g, _s);
```

where:

* `constObjectExpression` denotes a compile time constant object.
* The name `_f` is inaccessible to any Dart program.
* target is the receiver of the invocation (this) if it was an instance member
  access, otherwise it is null.
* `_g` is an implicitly defined static function  `static _g(rcvr) => rcvr._f;`
* `_s` is an implicitly defined static function  `static _s(rcvr, v) => rcvr._f = v`;

This implies that attempting to set a final field fails dynamically.

#### A redirecting getter declaration

```dart
get memberName >> constObjectExpression functionBody;
```

is equivalent to the getter declaration

```dart
get memberName => constObjectExpression.get(target, #memberName, _g, _s);
```

where:

`constObjectName` denotes a compile time constant object.

Throughout this section, we assume `constObjectExpression` supports the
following API (or possibly subsets thereof, TBD):

```dart
 abstract class Interceptor {
  get(target, name, getter, setter);
  set(target, name, value, getter, setter);
  invoke(target, name, positionalArguments, namedArguments, original);
}
```


* target is the receiver of the invocation (this) if it was an instance member
access, otherwise it is null.
* `_g` is an implicitly defined static function  `static _g(rcvr) => rcvr.__g`;
  where `__g` is an implicitly defined getter function `get __g functionBody`
  implicitly defined in the same scope as `memberName`.
* `_s` is an implicitly defined static function `static _s(rcvr, v) => rcvr.__s = v;`
  where `__s` is an implicitly defined setter function defined as follows:
  * If `memberName=` is a redirecting setter, `__s` is the implicit  setter
    whose body is defined by the function body given for `memberName=`.
  * If `memberName=` is an ordinary setter, `__s` is `memberName=`.
  * If no setter `memberName=` exists, `__s` is undefined and invoking it causes
    a runtime error.

#### A redirecting setter declaration
```dart
set memberName(v) >> constObjectExpression functionBody;
```

is equivalent to the setter declaration

```dart
set memberName(v) => constObjectExpression.set(target, #memberName, v,  _g, _s);
```

where:

* `constObjectExpression` denotes a compile time constant object.
* target is the receiver of the invocation (this) if it was an instance member access, otherwise it is null.
* `_g` is an implicitly defined static function  `static _g(rcvr) => rcvr.__g`;
  where `__g` is an implicitly defined s follows:
  * If memberName is a redirecting getter, `__g` is the implicit getter whose
    body is defined by the function body given for memberName.
  * If memberName is an ordinary getter, `__g` is `memberName`.
  * If no getter memberName exists, `__g` is undefined and invoking it causes a
    runtime error.

`_s` is an implicitly defined static function
`static _s(rcvr, v) => rcvr.__s = v`;
where `__s` is an implicitly defined setter function `set __s(v) functionBody`
implicitly defined in the same scope as memberName.

#### A redirecting method declaration

```dart
memberName(args) >> constObjectExpression functionBody;
```

is equivalent to the method declaration
```dart
memberName => constObjectExpression.invoke(target, #memberName, positionalArgs, namedArgs, _m);
```

where:

* `constObjectExpression` denotes a compile time constant object.
* target is the receiver of the invocation (this) if it was an instance member
  access, otherwise it is null.
* positionalArgs describes the positional arguments given in the actual
  invocation of the method.
* namedArgs describes the named arguments given in the actual invocation  of the
  method.
* `_m` is an implicitly defined static function `static _m(rcvr, args) => rcvr.__m(args);`
   where `__m` is a function `__m(args) {functionBody}` implicitly defined in
   the same scope as memberName.

[proposal]: proposal.md
