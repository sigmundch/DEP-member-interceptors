# Member Interceptors

## Contact information

Author: Sigmund Cherem ([@sigmundch][])

[DEP proposal location](https://github.com/sigmundch/DEP-member-interceptors/blob/master/proposal.md)

Stakeholders:
  * Gilad Bracha ([@gbracha][])
  * Lasse R.H. Nielsen ([@lrhn][])
  * Vyacheslav Egorov ([@mraleph][])

**Note about background**: This proposal was derived from design discussions
with several Dart team members from an idea initially suggested by @mraleph.
Some contents below were adapted from text written by @gbracha and @lrhn.

## Summary

We propose an extension to the Dart language to support intercepting top-level
and class members using an _interceptor_.

Interceptors provide a way to statically add behavior to members without
incurring lots of boilerplate code. The definition of interceptors are
constant objects, so the semantics of the program are still understood at
compile time. Interceptors are applied to members by decorating these members
using annotations. This separation allows frameworks to define what the behavior
of an interceptor is, while users just focus on decorating their members with
the features they wish to use.

**Note about terminology**: The term "_interceptor_" used in this document is
similar to the concept of [python decorators][] or [advice in Lisp][advice].
We use the term _intercepted member_ to refer to a member that is decorated with
an interceptor.  We may also use the term _redirected member_ for the same
purpose, as using the member redirects the implementation to the
interceptor.

## Motivation

This proposal is heavily motivated by a specific use case in data observability.
A feature widely used in UI frameworks, including [Angular][] and [Polymer][].

Many UI frameworks provide a lot of declarative features that help developers
focus on building web applications without having to worry about low-level
details, like how information has to be plumbed from data models to UI widgets.
Some of these features include templates, dependency injection, and
data observability.  These features can be expressed very succinctly, but under
the hood they may be implemented using reflection (typically for
development time in Dartium) and with code generation (typically with
transformers for deployment).

Data observability is a feature that lets users listen for changes that occur on
their data models. This is typically used by the framework to automatically
react to changes and reflect them in the UI layer.

While working with data observability in Polymer, we run into these challenges:

* It is not possible to guarantee a synchronous delivery of change notifications
  without requiring users to write additional boilerplate code (see more in the
  [examples][] section below). The Dart language is not expressive enough to achieve
  this goal.

* As a result, our [implementation](https://github.com/dart-lang/observe) must
  deliver observable changes asynchronously using dirty-checking at
  development-time.

* To achieve performance at deployment time, we elminate dirty-checking by
  rewriting observable fields into properties with write barriers. What is
  especially peculiar about this transformation is that it modifies the source
  files in place. This adds additional complexity to our build system. All other
  code generation done by Polymer can be done so that the original source code
  is unmodified.

* Composition of observable expressions is hard and we were forced to move
  compound expressions into a domain-specific language written in strings and
  annotations (more examples below).


All these challenges led us to brainstorm about possible ways to address these
limitations in the language. Other languages have opted to include observability
as a first-class concept (e.g. ES6's [Object Observe][]). This proposal takes a
different angle: improve the expressiveness of the Dart language to be able to
implement synchronous observability as a library.

One of the benefits that this proposal entails is that the use of
mirrors and code-generation in Polymer will be restricted to APIs that can be
handled by the [reflectable package][], and on-the-side code generation of
`Dart` files from `HTML` files. So, there would be no need to modify Dart files
in place anymore.

## Examples

Member interceptors can be used to implement read barriers, write barriers, or
trapping method calls.  Below are some examples where interceptors can be
useful.

**Note**: In these examples we use the standard annotation syntax
to decorate members with an interceptor. Further down in this proposal we
discuss this and other syntax options and their tradeoffs.

### Example 1: memoization

A simple interceptor can be used to memoize results of function calls and
property getters. For example, one could write a fibonacci implementation with
memoization as follows:

```dart
@memoize int fibonacci(int n) =>
    n <= 1 ? 1 : fibonacci(n - 1) + fibonacci(n - 2);
```

Internally, the `memoize` annotation declares an interceptor that traps calls
to `fibonacci` and returns a cached result if one is available. In other words,
the code above is equivalent to writing something like:

```dart
Map<int, int> _fibonacci_cache = {};
int fibonacci(int n) =>
  _fibonacci_cache.putIfAbsent(n, () => _fibonacci(n));

int _fibonacci(int n) =>
    n <= 1 ? 1 : fibonacci(n - 1) + fibonacci(n - 2);
```


### Example 2: debug-only/test-only features

Interceptors can be used to require that certain code is only executed in a
specific context. For example, this can be used for:
* turning on logging at development time.
* instrumenting while investigating performance bottlenecks.
* making functions visible only for testing.

For example, a `visibleForTesting` interceptor can be used as follows:

```dart
class MyEncapsulatedLogic {
  int _name;

  @visibleForTesting
  set nameForTest(n) { _name = n; }
}
```

which is equivalent to something like:

```dart
class MyEncapsulatedLogic {
  int _name;

  set nameForTest(n) {
    if (!const bool.fromEnvironment('test')) {
      throw "Invalid: using test-only feature in application!!";
    }
    _nameForTest = n;
  }

  set _nameForTest(n) { _name = n; }
}
```

### Example 3: contract validation

Users can express and check invariants or pre- and post-conditions using
interceptors. For example:

```dart
class MyValue {
  @nonnegative int x;
}
```

internally the `nonnegative` interceptor can check that `x` is never set to have
a negative value. Which would be equivalent to write:

```dart
class MyValue {
  int _x;
  int get x => _x;
  int set x(v) {
    if (v < 0) throw "x can't be negative!";
    _x = v;
  }
}
```

### Example 4: observability

Coming back to our motivating use-case.  Consider this code from Polymer, where
an annotation is already used to indicate that a field is observable:


```dart
class Person implements Observable {
  @observable String firstName;
}
```

Today, Polymer performs dirty-checking and delives notifications at the
end of every event loop. With this proposal, the annotation above would become
an interceptor, which would let us detect changes when they happen, and would
allow us to deliver these notifications synchronously. In other
words, it would be as if the user had written:

```dart
class Person implements Observable {
  String _firstName;
  String get firstName => _firstName;
  set firstName(String newValue) {
    var oldValue = _firstName;
    _firstName = newValue;
    notifyChanges(#firstName, oldValue, newValue);
  }
}
```

Now suppose we want to observe not just a field, but an actual property composed
of other fields. For example, let's combine `firstName` and `lastName` to create
`fullName`. Without interceptors, the dependency between observable properties
needs to be encoded somehow in a domain specific language, this could be
annotations that encode dependencies directly, for example. In Polymer, we
reused an expression language that was used in other parts of the system
instead, so a composed property looks like this today:

```dart
class Person implements Observable {
  @observable String firstName;
  @observable String lastName;

  @ComputedProperty('fullName + " " + lastName')
  String get fullName => readValue(this, #fullName);
}
```

This code looks a bit magical and, well, it sort of is. From the
`ComputedProperty` annotation Polymer reflectively evaluates the expression, the
`readValue` function is used to avoid duplicating the expression again in the
body of the getter, but also to help the framework in two ways: first, to encode
the dependency between the computed property and the underyling fields, second,
to prevent users from seeing an inconsistent state that may arise due to the
asynchornous nature of the change notificaitons.

Interceptors would let us encode computed expressions directly in Dart without
resorting to some sort of DSL. For example, one could simply write:

```dart
class Person implements Observable {
  @observable String firstName;
  @observable String lastName;

  @observable get fullName => '$firstName $lastName';
}
```

besides issuing notifications on write operations, the `observable` interceptor
can detect read operations and automatically establish the dependency between
properties.

As part of this proposal, we have provided a prototype implementation using
transformers. See the [example/observe/][] folder to see the
observable interceptor in action.

## Proposal

Member interceptors are a shorthand notation for creating indirect access to
properties and methods, where access goes through the interceptor first.

The process of writing member interceptors consists of declaring an
interceptor object and decorating a member with such interceptor.

### Interceptor object declaration

An interceptor object is a constant expression that implements one or more of
the interceptor interfaces:

```dart
abstract class ReadInterceptor {
  get(target, Member member);
}

abstract class WriteInterceptor {
  set(target, value, Member member);
}

abstract class InvokeInterceptor {
  invoke(target, List positionalArguments, Map<Symbol,dynamic> namedArguments,
      Member member);
}

abstract class Interceptor implements
    ReadInterceptor, WriteInterceptor, InvokeInterceptor {
}
```

If an interceptor implements `ReadInterceptor`, it can be used to intercept
getters and reading fields. Similarly, if it implements
`WriteInterceptor` it can be used on setter calls, and if it implements
`InvokeInterceptor` it can be used on method calls.

The `Member` type is a constant object defined as:

```dart
abstract class Member {
  final Symbol name;
  const Member(this.name);
  get(target);
  set(target, value);
  invoke(target, List positionalArguments, Map<Symbol, dynamic> namedArguments);
}
```

`Member` objects are created automatically by language implementations (VM,
dart2js). Note: this class simplifies how we explain this proposal, but a viable
alternative would be to desugar the `Member` object and pass the relevant
information on the `Interceptor` API directly. See the [alternatives][] section
for details.

The `Member` and `Interceptor` interfaces would be added to a `dart:` library
known to the Dart VM and dart2js.

### Interceptor usage syntax

The decoration process is how we tell that a field, getter, setter, or method
should be redirected to an interceptor.  Dart annotations already
provide syntax to decorate members, so we propose reusing the annotation
syntax for the purpose of annotating members with interceptors.

**Note**: we have also considered other ideas requiring syntactic changes to the
language. Please see the [alternatives][] section below for details and
discussion about tradeoffs.

#### Decorating classes and libraries

Using an interceptor in a class or a library is considered syntactic sugar for
decorating every member of that class or library.

#### Decorating from the side

Sometimes users wish to intercept members of classes that they use, but that
that they don't control. For example, code loaded from a third-party package.

We propose adding a side-annotation that calls out which member is being
annotated, for example:

```
library mylibrary;

@ApplyInterceptorTo(observable, MyClass, #name)
import 'other.dart' show MyClass;
```

This is similar to the side-annotation style that is used by the [reflectable
package][].

## Semantics

Because interceptors are constant objects, we can determine before the program
starts whether a member is decorated, and expand it accordingly. A member is
expanded by creating a new declaration where the original member is made
private, and the original name is used for a new member that intercepts
access to the original one.

### Getters
An intercepted getter
```dart
  @interceptor get name <body>;
```
is equivalent to:
```dart
  get name => interceptor.get(target, const _$nameMember());
  get _$name <body>;
```

where:
  * `_$name` is a unique private name not used elsewhere,
  * `target` is either `this` if the getter is an instance member, or `null` if it is a top-level or
static member, and
  * the class `_$nameMember` is defined as:

```dart
  class _$nameMember extends Member {
    const _$nameMember() : super(#name);
    get(target) => target._$name;
    set(target, value) { target._$name = value; }
    invoke(target, positional, named) =>
      Function.apply(target._$name, positional, named);
  }
```

More validation can be added to ensure that target is one where the `Member`
applies, depending on which error message is desired for misuse cases.

### Setters

Similarly, an intercepted setter
```dart
  @interceptor void set(value) <body>
```

is equivalent to:

```dart
  set name(value) => interceptor.set(target, value, const _$nameMember());
  set _$name(value) <body>
```

If a class declares both a getter or a setter, the corresponding private name
`_$name` is the same for both.

### Fields

An intercepted field:
```dart
@interceptor var name;
```

is equivalent to:
```dart
  var _$name;
  get name => interceptor.get(target, const _$nameMember());
  set name(value) => interceptor.set(target, value, const _$nameMember());
```

A final field will not have the setter, and the `_$name` field will be final.

### Initializers

Initialization does not go through the interceptor, so all initializers are
updated to write directly the private symbol. Also, to keep the paramenter name
in an initializer formal, we change them to be a normal parameter and
move the initialization to the initializer list.  For example:

```dart
class MyClass {
  @incerceptor String name1 = "1";
  @incerceptor String name2;
  @incerceptor String name3;
  MyClass(this.name2) : name2 = "2";
```

would become:

```dart
class MyClass {
  String _$name1 = "1";
  get name => interceptor.get(this, const _$nameMember());
  set name(value) => interceptor.set(this, value, const _$nameMember());

  String _$name2;
  get name => interceptor.get(this, const _$nameMember());
  set name(value) => interceptor.set(this, value, const _$nameMember());

  String _$name3;
  get name => interceptor.get(this, const _$nameMember());
  set name(value) => interceptor.set(this, value, const _$nameMember());

  MyClass(String name3) : _$name2 = "2", _$name3 = name;
}
```

One possible extension for this proposal would be to allow an interceptor to run
during initialization. We discuss this idea in more detail in the
[alternatives][] section below.

### Methods

Finally, an intercepted method:
```dart
@inteceptor method(args) <body>
```

is equivalent to:
```dart
  method(args) => interceptor.invoke(target, positionalArgs, namedArgs,
      const _$nameMember());
  _$method(args) <body>
```
where the list of arguments and map of named arguments are the same kind that
would be part of the `Invocation` passed to `noSuchMethod`.

It's important to note that unlike `noSuchMethod`, these invocations are fully
resolved and known at compile-time. This means that with proper inlining,
compilers like dart2js should be able to eliminate the indirection and the use
of `Function.apply` in `Member.invoke`.

### Combined interceptors

Multiple interceptors applied on the same member are expanded in the reverse order
they are written. For example:

```dart
class MyClass {
  @interceptor1
  @interceptor2
  get name => body;
}
```

is equivalent to:
```dart
class MyClass {
  @interceptor1
  get name => interceptor2.get(this, const _$nameAMember);
  get _$nameA => body;
```

which is then equivalent to:
```dart
class MyClass {
  get name => interceptor1.get(this, const _$nameBMember);
  get _$nameB => interceptor2.get(this, const _$nameAMember);
  get _$nameA => body;
```

## Alternatives

### Decorating syntax

An alternative to using annotations would be to introduce a new syntax to denote
when interceptors are applied. Some ideas we've discussed include:

**Alternative A**: Adding a special `>>` operator that goes before `async`,
`async*`, `sync*` if those are present. For example:

```dart
String name >> interceptor = "";
String get name >> interceptor => "";
set name(v) >> interceptor { … };
void name(v1, v2) >> interceptor { … };
```

**Alternative B**: Adding a special `with` keyword that goes in the same
location.  Some have suggested that interceptors feel like a mixin at the level
of a member, so the keyword `with` could be used for this purpose as well. For
example:

```dart
String name with interceptor = "";
String get name with interceptor => "";
set name(v) with interceptor { … };
void name(v1, v2) with interceptor { … };
```


**Alternative C**: A new annotation syntax. For example:
```dart
@@interceptor String name = "";
@@interceptor String get name => "";
@@interceptor set name(v) { … };
@@interceptor void name(v1, v2) { … };
```


One concern with the alternative (A) is that it can be hard to read and that
users already have an understanding that `>>` means R-shift. For instance, this
example is especially hard to read:

```dart
  int get value >> interceptor => 1 >> 8;
```

Alternative (B) reads better than (A). Alternative (C) seems to add a tax
without much benefits compared to just using plain annotations.

There are a few benefits of going with traditional annotations (as this proposal
suggests):

 * There are no syntax changes required in the language. The new types will be
   added to a `dart:` library so the change would be backwards compatible.  The
   challenge is that now language implementors need to resolve the type of
   annotations in order to distinguish plain annotations from interceptors.

 * Frameworks can encapsulate whether or not they use interceptors. This also
   means that a framework like Polymer can switch to use interceptors internally
   without exposing a breaking change to their users (fields annotated
   `@observable` will continue to work).

 * It doesn't require additional changes to also support decorating classes,
   libraries, or providing [side-annotations](#decorating-from-the-side).

The main point against using annotation is that it will adds semantic meaning to
annotations, but until now the language didn't have any feature that directly did
so. However, it is worth nothing that annotations have been given semantic
meaning by frameworks in the past. In particular, annotations are visible from
the mirror system and frameworks like Polymer and Angular already use that
information. Users of these frameworks are familiar with this and understand
that many annotations have a semantic purpose.

<!--
Using annotations as the interceptor syntax can reduces the cost of adding the
interceptor feature and it can be a first stepping stone to add more power to
Dart annotations.
-->

Readers of this proposal might also find interesting the trade-off discussion
about syntax from the original [python decorators proposal][python decorators].

### The Member object

One concern about the `Member` abstraction is that it introduces an object in
the intercepting API. Since this object is constant, we believe language
implementors can provide it with little overhead.

If performance is a concern, we could revisit the interceptor interfaces and
inline the information directly on the call. A detailed look at the semantics
without the `Member` class are available in a [suplemental document][no-member].

### Intercept initializers

One possible extension to this proposal is to allow interceptors to run at the
time fields are initializated. This may be a separate interceptor than
`ReadInterceptor`, since its intent is fairly different.

Such interceptor could have several important applications. For instance, it
could be used to implement a static dependency injection system in Dart.  That
is, a user could write:

```dart
class MyClass {
  @inject final MyService service;

  MyClass();
}
```

And the `inject` interceptor will initialize the `service` field with the
corresponding implementation.

### Intercept all kinds of tear-off operations

Under the current proposal we treat implicit tear-off of methods, for example in
the expression `o.m`, as a getter, so `ReadInterceptors` will be used on such
operation. With the introduction of [tear-offs][], we could conceively do the
same for `o#m`, or have a separate kind of interceptor for this purpose.

### Other proposals: partial classes

Depending on the actual design, partial classes (see [bug 8547][b8547]) is a
different language proposal that could help with data observability. With
partial classes we wouldn't eliminate the need for code generation, but we
could do so in a way that code is generated in a separate file.

For example, we would ask users to write code like this:
```dart
part 'example.g.dart'; // auto-generated

class Person {
  @observable String _firstName;
  @observable String _lastName;
  @observable String _fullName => '$_firstName $_lastName';
}
```

and autogenerate `example.g.dart` to have:
```dart

partial class MyClass {
  int get firstName => observable.get(this, const __firstNameMember());
  int get lastName => observable.get(this, const __lastNameMember());
  int get fullName => observable.get(this, const __fullNameMember());
}

class __firstNameMember() {
  ...
  get(o) => o._firstName;
}

...
```

This is not as general as interceptors, though. In particular, it requires
code-generation, it is not possible to intercept properties on the side, and it
requires conventions (such as using a private name instead of a public name) to
be able to correctly override the public behavior of objects.


## Implications and limitations

Here are some important implications and limitations of this proposal, many of
which we have mentioned thoroughout the document:

* Interceptors are static: everything is analyzeable at compile-time.

* Interceptors do not change the signature of methods, so APIs are consistent
  and for the purpose of type analysis, interceptors can be ignored.

* Interceptors introduce a new private symbol that is not available anywhere
  else in the library. That means, `_$name` cannot be fabricated by a programmer
  and used in the same library to "reach inside" the intercepted element.

* If we use the annotation syntax, this would be the first DEP that introduces a
  semantic meaning to annotations outside of Dart's mirror system.

## Deliverables

The sources of this github repo include several examples of intereceptors
working. The code is organized as follows:

* [prototype/][]: contains a prototype implementation that only handles fields,
  getters, and setters. The implementation demonstrates 3 alternative syntaxes
  (annotations, `with` and `>>`). To keep things simple, the prototype is mainly
  syntax based. That means, it doesn't resolve types and it will not figure out
  whether an annotation is an interceptor or not, it simply assumes that they
  are. However, this is good enough to use for the two examples below.

* [example/observe/][]: contains an implementation of observability using
  interceptors (see [example 4][] above).

* [example/nonnegative/][]: contains an example of non-nullability checks
  implemented as interceptors (see [example 3][] above).


[@sigmundch]: https://github.com/sigmundch
[@gbracha]: https://github.com/gbracha
[@lrhn]: https://github.com/lrhn
[@mraleph]: https://github.com/mraleph
[reflectable package]: http://github.com/dart-lang/reflectable
[tear-offs]: https://github.com/dart-lang/dart_enhancement_proposals/blob/master/Accepted/0003%20-%20Generalized%20Tear-offs/proposal.md
[python decorators]: https://www.python.org/dev/peps/pep-0318/
[python class decorators]: https://www.python.org/dev/peps/pep-3129/
[advice]: http://en.wikipedia.org/wiki/Advice_(programming)
[Angular]: http://github.com/angular/angular.dart
[Polymer]: http://github.com/dart-lang/polymer-dart
[no-member]: no_member_semantics.md
[prototype/]: prototype/README.md
[example/observe/]: example/observe/README.md
[example/nonnegative/]: example/nonnegative/README.md
[Object Observe]: http://arv.github.io/ecmascript-object-observe/
[alternatives]: #alternatives
[examples]: #examples
[example 3]: #example-3-contract-validation
[example 4]: #example-4-observability
[b8547]: https://code.google.com/p/dart/issues/detail?id=8547
