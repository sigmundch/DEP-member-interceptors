// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library interceptor.transformer;

import 'dart:async';

import 'package:barback/barback.dart';
import 'package:analyzer/analyzer.dart';
import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/error.dart';
import 'package:analyzer/src/generated/parser.dart';
import 'package:analyzer/src/generated/scanner.dart';
import 'package:source_maps/refactor.dart';
import 'package:source_span/source_span.dart';


/// Note this prototype doesn't check that the actual annotations implement the
/// interceptor API, we simply do a syntactic replacement which is enough to
/// illustrate the feature for the purpose of the DEP.
class InterceptorTransformerWithAnnotationSyntax extends Transformer {

  InterceptorTransformerWithAnnotationSyntax.asPlugin();

  final String allowedExtensions = '.dart';

  static final RegExp _fieldReg =
      new RegExp('\n\( [ ]*[^ \n]\+\) \([^ ]*\) >> \([^ ]*\) \([^;]*;\)');

  static final RegExp _topReg =
      new RegExp('\n\([^ \n]\+\) \([^ ]*\) >> \([^ ]*\) \([^;]*;\)');

  static final RegExp _getReg =
      new RegExp('\n\( [ ]*[^ \n]*\) get \([^ ]*\) >> \([^ ]*\) \(=>[^;]*\);');

  Future apply(Transform transform) async {
    if (transform.primaryInput.id.path != 'web/example.dart') return;
    var content = await transform.primaryInput.readAsString();
    var transaction = _transformCompilationUnit(content, sourceFile);
    if (!transaction.hasEdits) {
      transform.addOutput(transform.primaryInput);
    } else {
      var printer = transaction.commit();
      printer.build(url);
      transform.addOutput(new Asset.fromString(id, printer.text));
    }
  }

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
            '$type get $name => $interceptor.read(this, #$name, () $body, null);';
      });
      transform.addOutput(new
          Asset.fromString(transform.primaryInput.id, newContent));
    });
  }
}

TextEditTransaction _transformCompilationUnit(
    String inputCode, SourceFile sourceFile) {
  var unit = parseCompilationUnit(inputCode, suppressErrors: true);
  var code = new TextEditTransaction(inputCode, sourceFile);

  for (var declaration in unit.declarations) {
    if (declaration is ClassDeclaration) {
      _transformClass(declaration, code, sourceFile);
    } else if (declaration is TopLevelVariableDeclaration) {
      _transformFields(declaration, declaration.variables, code);
    }
  }
  return code;
}

void _transformClass(ClassDeclaration cls, TextEditTransaction code) {
  // Track fields that were transformed.
  var instanceFields = new Set<String>();

  for (var member in cls.members) {
    if (member is FieldDeclaration) {
      if (member.metadata.length > 0) {
        _transformFields(member, member.fields, code);
        var names = member.fields.variables.map((v) => v.name.name);
        instanceFields.addAll(names);
      }
    }
  }

  // If nothing has an annotation, bail.
  if (instanceFields.length == 0) return;

  // Fix initializers.
  for (var member in cls.members) {
    if (member is ConstructorDeclaration) {
      _fixConstructor(member, code, instanceFields);
    }
  }
}

bool _hasKeyword(Token token, Keyword keyword) =>
    token is KeywordToken && token.keyword == keyword;

String _getOriginalCode(TextEditTransaction code, AstNode node) =>
    code.original.substring(node.offset, node.end);

void _fixConstructor(ConstructorDeclaration ctor, TextEditTransaction code,
    Set<String> changedFields) {

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

void _transformFields(AnnotatedNode member, VariableDeclarationList fields,
    TextEditTransaction code) {

  // Unfortunately "var" doesn't work in all positions where type annotations
  // are allowed, such as "var get name". So we use "dynamic" instead.
  var type = 'dynamic';
  if (fields.type != null) {
    type = _getOriginalCode(code, fields.type);
  } else if (_hasKeyword(fields.keyword, Keyword.VAR)) {
    // Replace 'var' with 'dynamic'
    code.edit(fields.keyword.offset, fields.keyword.end, type);
  }

  if (fields.variables.length > 1) throw "not supported";
  var meta = member.metadata.first;
  var interceptor = _getOriginalCode(meta);

  // remove all metadata
  code.edit(meta.offset, meta.end, '');

  for (int i = 0; i < fields.variables.length; i++) {
    final field = fields.variables[i];
    final name = field.name.name;

    var target = member is FieldDeclaration && !member.isStatic ? 'this' : 'null';
    var beforeInit = 'get $name => $interceptor.read($target, #$name, () => __\$$name, (v) => __\$$name = v);\n  $type __\$$name';

    if (i > 0) beforeInit = '$type $beforeInit';

    code.edit(field.name.offset, field.name.end, beforeInit);

    // Replace comma with semicolon
    final end = _findFieldSeperator(member.endToken.next);
    if (end.type == TokenType.COMMA) code.edit(end.offset, end.end, ';');

    code.edit(end.end, end.end, '\n  set $name($type value) { '
        '$interceptor.write($target, #$name, () => __\$$name, (v) { __\$$name = v;});');
  }
}

Token _findFieldSeperator(Token token) {
  while (token != null) {
    if (token.type == TokenType.COMMA || token.type == TokenType.SEMICOLON) {
      break;
    }
    token = token.next;
  }
  return token;
}

// TODO(sigmund): remove hard coded Polymer support (@published). The proper way
// to do this would be to switch to use the analyzer to resolve whether
// annotations are subtypes of ObservableProperty.
final observableMatcher =
    new RegExp("@(published|observable|PublishedProperty|ObservableProperty)");
