// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library interceptor.transformer;

import 'dart:async';

import 'package:barback/barback.dart';
import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/scanner.dart';
import 'package:source_maps/refactor.dart';
import 'package:source_span/source_span.dart';

import 'src/snippets.dart';

/// Note this prototype doesn't check that the actual annotations implement the
/// interceptor API, we simply do a syntactic replacement which is enough to
/// illustrate the feature for the purpose of the DEP.
class InterceptorTransformerWithAnnotationSyntax extends Transformer {

  InterceptorTransformerWithAnnotationSyntax.asPlugin();

  final String allowedExtensions = '.dart';

  Future apply(Transform transform) async {
    var content = await transform.primaryInput.readAsString();
    var id = transform.primaryInput.id;
    var url = id.path.startsWith('lib/')
        ? 'package:${id.package}/${id.path.substring(4)}' : id.path;
    var sourceFile = new SourceFile(content, url: url);
    var transaction = new _Helper(content, sourceFile).transform();
    if (!transaction.hasEdits) {
      transform.addOutput(transform.primaryInput);
    } else {
      var printer = transaction.commit();
      printer.build(url);
      transform.addOutput(new Asset.fromString(id, printer.text));
    }
  }
}

class _Helper {
  final CompilationUnit unit;
  final TextEditTransaction code;
  final members = new Set<String>();

  _Helper(String inputCode, SourceFile sourceFile)
      : unit = parseCompilationUnit(inputCode, suppressErrors: true),
        code = new TextEditTransaction(inputCode, sourceFile);

  TextEditTransaction transform() {
    for (var declaration in unit.declarations) {
      if (declaration is ClassDeclaration) {
        _transformClass(declaration);
      } else {
        if (declaration.metadata.length == 0) continue;
        if (declaration is TopLevelVariableDeclaration) {
          _transformField(declaration, declaration.variables);
        } else if (declaration is FunctionDeclaration )  {
          _transformMethod(declaration);
        }
      }
    }
    if (members.isNotEmpty) {
      var importOffset = unit.directives.last.end;
      code.edit(importOffset, importOffset, emitInterceptorImport());

      for (var member in members) {
        code.edit(unit.end, unit.end, emitMemberClass(member));
      }
    }
    return code;
  }

  void _transformClass(ClassDeclaration cls) {
    // Track fields that were transformed.
    var instanceFields = new Set<String>();

    for (var member in cls.members) {
      if (member.metadata.length == 0) continue;
      if (member is FieldDeclaration) {
        _transformField(member, member.fields);
        var names = member.fields.variables.map((v) => v.name.name);
        instanceFields.addAll(names);
      } else if (member is MethodDeclaration) {
        _transformMethod(member);
      }
    }

    // If nothing has an annotation, bail.
    if (instanceFields.length == 0) return;

    // Fix initializers.
    for (var member in cls.members) {
      if (member is ConstructorDeclaration) {
        _fixConstructor(member, instanceFields);
      }
    }
  }

  void _fixConstructor(ConstructorDeclaration ctor, Set<String> changedFields) {
    // Fix normal initializers
    for (var initializer in ctor.initializers) {
      if (initializer is ConstructorFieldInitializer) {
        var field = initializer.fieldName;
        if (changedFields.contains(field.name)) {
          code.edit(field.offset, field.end, '__\$${field.name}');
        }
      }
    }

    // Fix "this." initializer in parameter list. These are tricky:
    // we need to preserve the name and add an initializer.
    // Preserving the name is important for named args, and for dartdoc.
    // BEFORE: Foo(this.bar, this.baz) { ... }
    // AFTER:  Foo(bar, baz) : __$bar = bar, __$baz = baz { ... }

    var thisInit = [];
    for (var param in ctor.parameters.parameters) {
      if (param is DefaultFormalParameter) {
        param = param.parameter;
      }
      if (param is FieldFormalParameter) {
        var name = param.identifier.name;
        if (changedFields.contains(name)) {
          thisInit.add(name);
          // Remove "this." but keep everything else.
          code.edit(param.thisToken.offset, param.period.end, '');
        }
      }
    }

    if (thisInit.length == 0) return;

    // TODO(jmesserly): smarter formatting with indent, etc.
    var inserted = thisInit.map((i) => '__\$$i = $i').join(', ');

    int offset;
    if (ctor.separator != null) {
      offset = ctor.separator.end;
      inserted = ' $inserted,';
    } else {
      offset = ctor.parameters.end;
      inserted = ' : $inserted';
    }

    code.edit(offset, offset, inserted);
  }

  void _transformField(AnnotatedNode member, VariableDeclarationList fields) {
    // Unfortunately "var" doesn't work in all positions where type annotations
    // are allowed, such as "var get name". So we use "dynamic" instead.
    var type = 'dynamic';
    if (fields.type != null) {
      type = _getOriginalCode(fields.type);
    } else if (_hasKeyword(fields.keyword, Keyword.VAR)) {
      // Replace 'var' with 'dynamic'
      code.edit(fields.keyword.offset, fields.keyword.end, type);
    }

    if (fields.variables.length > 1) throw "more than one variable not supported";
    var interceptor = _extractInterceptor(member.metadata);

    var isInstance = member is FieldDeclaration && !member.isStatic;
    var end = member.end;
    for (var variable in fields.variables) {
      var nameNode = variable.name;
      final name = nameNode.name;
      members.add(name);
      code.edit(nameNode.offset, nameNode.end, '__\$$name');
      code.edit(end, end, emitGetter(type, name, interceptor, isInstance));
      code.edit(end, end, emitSetter(type, name, interceptor, isInstance));
    }
  }
  String _getOriginalCode(AstNode node) =>
      code.original.substring(node.offset, node.end);


  void _transformMethod(member) {
    assert (member is MethodDeclaration || member is FunctionDeclaration);
    var interceptor = _extractInterceptor(member.metadata);
    var nameNode = member.name;
    var name = nameNode.name;
    var isInstance = member is MethodDeclaration && !member.isStatic;
    var end = member.end;
    if (member.isGetter) {
      members.add(name);
      code.edit(nameNode.offset, nameNode.end, '__\$$name');
      var type = member.returnType;
      code.edit(end, end, emitGetter(type, name, interceptor, isInstance));
    } else if (member.isSetter) {
      members.add(name);
      code.edit(nameNode.offset, nameNode.end, '__\$$name');
      var type = member.parameters.parameters[0].type;
      code.edit(end, end, emitSetter(type, name, interceptor, isInstance));
    }
  }

  String _extractInterceptor(List<Annotation> metadata) {
    if (metadata.length > 1) throw "more than one annotation not supported";
    var meta = metadata.first;
    var interceptor = code.original.substring(meta.offset + 1, meta.end);
    if (meta.arguments != null) interceptor = 'const $interceptor';
    return interceptor;
  }
}

bool _hasKeyword(Token token, Keyword keyword) =>
    token is KeywordToken && token.keyword == keyword;

