import 'dart:convert';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';
import 'package:source_gen/source_gen.dart';
import 'package:sqflite_annotation/sqflite_annotation.dart';
import 'package:sqflite_generator/src/config_builder/annotation_builder/config.dart';

import 'import_config_builder.dart';

const imports = '''import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:developer';
import 'package:flutter/services.dart';
''';

const _analyzerIgnores = '// ignore_for_file: lines_longer_than_80_chars, '
    'prefer_relative_imports, directives_ordering, require_trailing_commas, always_put_required_named_parameters_first';

class ConfigGenerator extends GeneratorForAnnotation<SqlConfig> {
  @override
  generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) async {
    final emitter = DartEmitter(useNullSafetySyntax: true);
    // if (element is! MethodElement) return null;
    final funcName = element.displayName;
    final AConfig config = AConfigX.fromElement(element);

    //#region import entities model
    final injectableConfigFiles = Glob("**/**.sql_model.json");
    final configs = <ModelConfigGen>[];
    await for (final id in buildStep.findAssets(injectableConfigFiles)) {
      final json = jsonDecode(await buildStep.readAsString(id));
      final lst = json as List;
      configs.addAll(lst.map(ModelConfigGen.fromJson));
    }

    //#endregion

    final entitiesImports = <String>[
      for (int i = 0; i < configs.length; i++)
        "import '${configs[i].imports.first}' as i$i;",
      if (config.externalDB != null)
        "import 'package:sql_external_db/sql_external_db.dart';",
      if (config.externalDB != null)
        "import 'dart:io';"
      else
        "import 'package:path_provider/path_provider.dart'",
    ];

    final schemasGen = <String>[
      for (int i = 0; i < configs.length; i++) 'i$i.${configs[i].name}Query',
    ];

    final schemas = <String>[
      for (final item in schemasGen) '$item.createTable',
    ].join(',');

    final schemaValue = Field((f) {
      f
        ..name = '_schemas'
        ..modifier = FieldModifier.final$
        ..assignment = Code('[$schemas]')
        ..type = refer('List<String>');
    });

    final schemaClear = [for (final item in schemasGen) '$item.deleteAll(db)'];

    final funcClearDbBuilder = Method(
      (m) => m
        ..name = '\$clearDatabase'
        ..requiredParameters.add(Parameter(
          (p) => p
            ..name = 'db'
            ..type = refer('Database'),
        ))
        ..returns = refer('Future<void>')
        ..body = Code('Future.wait([${schemaClear.join(',')}]);')
        ..lambda = true,
    );

    final functionConfigBuilder = Method((m) {
      m
        ..name = '\$$funcName'
        ..modifier = MethodModifier.async
        ..optionalParameters.add(Parameter((p) {
          p
            ..name = 'token'
            // ..covariant = true
            ..type = refer('RootIsolateToken?');
        }))
        ..body = Code('''
          if (token != null) {
            BackgroundIsolateBinaryMessenger.ensureInitialized(token);
          }
          Directory? documentsDirectory;
          ${config.externalDB != null ? """
            final pathNative = await SqlExternalDb.instance
                  .externalPath('group.com.hodoan.db_shared//demo.db');
              if (pathNative != null) {
                documentsDirectory = Directory(pathNative);
              }
            """ : 'documentsDirectory = await getApplicationDocumentsDirectory()'}
          assert(documentsDirectory != null, '${config.externalDB != null ? 'external storage ' : ''}directory is empty');
          final path = join(documentsDirectory!.path, '${config.name}');

          final database = await openDatabase(
            path,
            version: ${config.version},
            onOpen: (db) {
              log('db open');
            },
            onCreate: (Database db, int version) async {
              log('db create');
              await Future.wait([for (final schema in _schemas) db.execute(schema)]);
              log('db end create');
            },
            onConfigure: (db) async {
              ${config.isForeign ? 'await db.execute(\'PRAGMA foreign_keys = ON\');' : ''}
            },
          );

          return database;''')
        ..returns = refer('Future<Database>');
    });

    return DartFormatter().format([
      _analyzerIgnores,
      imports,
      ...entitiesImports,
      schemaValue.accept(emitter),
      functionConfigBuilder.accept(emitter),
      funcClearDbBuilder.accept(emitter),
    ].join('\n\n'));
  }
}
