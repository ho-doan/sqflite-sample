import 'package:analyzer/dart/element/element.dart';
import 'package:change_case/change_case.dart';
import 'package:code_builder/code_builder.dart';
import 'package:collection/collection.dart';
import 'package:sqflite_generator/src/annotation_builder/column.dart';
import 'package:sqflite_generator/src/annotation_builder/foreign_key.dart';
import 'package:sqflite_generator/src/annotation_builder/index.dart';
import 'package:sqflite_generator/src/annotation_builder/primary_key.dart';
import 'package:sqflite_generator/src/annotation_builder/property.dart';

class AEntity {
  final List<AColumn> columns;
  final List<AForeignKey> foreignKeys;
  final List<APrimaryKey> primaryKeys;
  final List<AIndex> indices;
  final String className;
  final String classType;
  String get extensionName => '${classType}Query';

  String get rawCreateTable {
    final all = [
      ...primaryKeys.map(
        (e) => e.rawCreate(
          autoId: e.auto,
          isId: true,
          isIds: primaryKeys.length > 1,
          isFore: foreignKeys.any((f) => e.nameDefault == f.nameDefault),
        ),
      ),
      ...columns.map((e) => e.rawCreate()),
      ...indices.map((e) => e.rawCreate()),
      // TODO(hodoan): handle list
      ...foreignKeys
          .where((e) => !e.dartType.isDartCoreList)
          .map((e) => e.rawCreate()),
      primaryKeys.rawCreate(foreignKeys),
      ...foreignKeys.map((e) => e.rawCreateForeign),
    ].where((e) => e != null && e.isNotEmpty);
    return 'CREATE TABLE IF NOT EXISTS $className(\n\t\t${all.join(',\n\t\t\t')}\n\t)';
  }

  String get rawFromDB {
    return [
      aPs.map(
        (e) {
          if (e.rawFromDB) {
            return '${e.nameDefault}: ${e.dartType}.fromDB(json,${e is AForeignKey ? e.subSelect(foreignKeys.duplicated(e)) : '\'\''})';
          }
          if (e.dartType.toString().contains('DateTime')) {
            return '${e.nameDefault}: DateTime.fromMillisecondsSinceEpoch(json[\'\${childName}${e.nameFromDB}\'] as int? ?? -1,)';
          }
          if (e.dartType.isDartCoreBool) {
            return '${e.nameDefault}: (json[\'${e.nameFromDB}\'] as int?) == 1';
          }
          return '${e.nameDefault}: json[\'\${childName}${e.nameFromDB}\'] as ${e.dartType}';
        },
      ).join(','),
      ','
    ].join();
  }

  String get rawToDB {
    return [
      aPs.map(
        (e) {
          if (e.rawFromDB) {
            return '\'${e.nameToDB}\': ${e.defaultSuffix}.id';
          }
          if (e.dartType.toString().contains('DateTime')) {
            return '\'${e.nameToDB}\': ${e.defaultSuffix}.millisecondsSinceEpoch';
          }
          return '\'${e.nameToDB}\':${e.nameDefault}';
        },
      ).join(','),
      ','
    ].join();
  }

  String get rawGetAll {
    return [
      '(await database.rawQuery(',
      '\'\'\'SELECT \${\$createSelect(select)} FROM $className ${className.toSnakeCase()}',
      ...aFores,
      '\'\'\') as List<Map>).map($classType.fromDB).toList()'
    ].join('\n');
  }

  String get rawFindOne {
    return [
      'final res = (await database.rawQuery(\'\'\'',
      'SELECT ',
      '\${\$createSelect(select)}',
      ' FROM $className ${className.toSnakeCase()}',
      'WHERE ${_whereDB.join(' AND ')}',
      ...aFores,
      '\'\'\',',
      _whereStaticArgs,
      ') as List<Map>);',
      'return res.isNotEmpty? $classType.fromDB(res.first) : null;'
    ].join('\n');
  }

  String delete(bool isStatic) {
    return [
      'await database.rawQuery(\'\'\'DELETE FROM $className ${className.toSnakeCase()} WHERE ${_whereDB.join(' AND ')}\'\'\',',
      isStatic ? _whereStaticArgs : _whereArgs,
      ');'
    ].join('');
  }

  String get deleteAll {
    return [
      'DELETE * FROM $className',
    ].join('\n');
  }

  const AEntity._({
    required this.columns,
    required this.foreignKeys,
    required this.primaryKeys,
    required this.indices,
    required this.className,
    required this.classType,
  });

  static AEntity? of(ClassElement element, [int step = 0]) {
    if (step > 3) return null;
    return AEntity._fromElement(element, step);
  }

  factory AEntity._fromElement(ClassElement element, int step) {
    final fields = element.fields.cast<FieldElement>();

    final cons = element.constructors.where((e) => !e.isFactory);
    final fs = <FieldFormalParameterElement>[
      for (final s in cons)
        ...s.parameters
            .whereType<FieldFormalParameterElement>()
            .cast()
            .toList(),
    ];
    final ss = <SuperFormalParameterElement>[
      for (final s in cons)
        ...s.parameters
            .whereType<SuperFormalParameterElement>()
            .cast()
            .toList(),
    ];
    final indies = AIndexX.fields(fields, element.displayName, step + 1);
    final primaries =
        APrimaryKeyX.fields(fields, element.displayName, step + 1);
    final fores =
        AForeignKeyX.fields(step + 1, fields, element.displayName, ss);

    return AEntity._(
      className: element.displayName.replaceFirst('\$', ''),
      classType: element.displayName,
      columns: AColumnX.fields(
        step + 1,
        fields,
        element.displayName,
        [...fs, ...ss],
        primaries,
        indies,
        fores,
      ),
      foreignKeys: fores,
      primaryKeys: primaries,
      indices: indies,
    );
  }
}

extension AUpdate on AEntity {
  String get name => className.replaceFirst('\$', '');
  List<String> rawUpdate([AProperty? parent]) {
    // TODO(hodoan): handle
    if (parent?.dartType.isDartCoreList ?? false) {
      return [];
    }
    if (parent != null) {
      return ['await ${parent.defaultSuffix}.update(database);'];
    }
    return {
      for (final fore in foreignKeys)
        ...fore.entityParent?.rawUpdate(fore) ?? <String>[],
      'return await database.update(\'$className\',toDB(), '
          'where: "${_whereDB.join(' AND ')}",'
          ' whereArgs: [${_whereArgs.join(' , ')}]);',
    }.toList();
  }
}

extension AInsert on AEntity {
  String rawInsert([AForeignKey? ps]) {
    // TODO(hodoan): handle
    if (ps?.dartType.isDartCoreList ?? false) return '';
    final fieldsRaw = aPs.map((e) => e.nameToDB).join(',\n');

    if (ps != null) {
      return 'final \$${'${className}Id_${ps.nameDefault}'.toCamelCase()} = await ${ps.defaultSuffix}.insert(database);';
    }

    final fieldsValue = aPs.map((e) {
      if (e.rawFromDB) {
        if (e is AForeignKey) {
          return '\$${'${e.entityParent?.className}Id_${e.nameDefault}'.toCamelCase()}';
        }
      }
      if (ps != null) return '$ps.${e.nameDefault}';
      return e.nameDefault;
    }).join(',');

    return [
      ...foreignKeys.map(
        (e) => e.entityParent?.rawInsert(e),
      ),
      '''final \$id = await database.rawInsert(\'\'\'INSERT OR REPLACE INTO $className ($fieldsRaw) 
       VALUES(${List.generate(fFields.length, (index) => '?').join(', ')})\'\'\',
       [
        $fieldsValue,
       ]
      );''',
      if (ps == null) 'return \$id;'
    ].join('\n');
  }
}

extension AForeignKeyXYZ on List<AForeignKey> {
  bool duplicated(AForeignKey v) {
    return where((e) => e.typeNotSuffix == v.typeNotSuffix).length > 1;
  }
}

extension AQuery on AEntity {
  String get selectClassName => '\$${className}SelectArgs';
  String get defaultSelectClass => '\$default';
  String get whereClassName => '\$${className}WhereArgs';
  List<String> get aFieldNames {
    return [
      ...primaryKeys,
      ...columns,
      ...indices,
      ...foreignKeys,
    ].map((e) => e.nameToDB).toList();
  }

  List<String> get aFores {
    return [
      for (final e in foreignKeys)
        // TODO(hodoan): handle is list
        if (!e.dartType.isDartCoreList)
          //   ' INNER JOIN ${e.entityParent?.name} ${e.joinAsStr(foreignKeys.duplicated(e))}'
          //       ' ON ${e.joinAsStr(foreignKeys.duplicated(e))}.${e.entityParent?.primaryKeys.firstOrNull?.nameToDB}'
          //       ' = ${className.toSnakeCase()}.${e.name?.toSnakeCase()}'
          // else
          ' INNER JOIN ${e.entityParent?.name} ${e.joinAsStr(foreignKeys.duplicated(e))}'
              ' ON ${e.joinAsStr(foreignKeys.duplicated(e))}.${e.entityParent?.primaryKeys.first.nameToDB}'
              ' = ${className.toSnakeCase()}.${e.name?.toSnakeCase()}'
    ];
  }

  List<AProperty> get aPs {
    return {
      for (final e in primaryKeys)
        e.nameDefault: e, // TODO(hodoan): handle list
      for (final e in foreignKeys)
        if (!e.dartType.isDartCoreList) e.nameDefault: e,
      for (final e in columns) e.nameDefault: e,
      for (final e in indices) e.nameDefault: e,
    }.values.toList();
  }

  List<String> get $check {
    return [
      for (final item in aPs)
        item is AForeignKey
            ? '${item.nameDefault}?.\$check == true'
            : '${item.nameDefault} == true'
    ];
  }
}

extension AParam on AEntity {
  Parameter get selectArgs => Parameter((p) => p
    ..name = 'select'
    ..type = refer('$selectClassName?')
    ..named = true
    ..required = false);
  Parameter get whereArgs => Parameter((p) => p
    ..name = 'where'
    ..type = refer('$whereClassName?')
    ..named = true
    ..required = false);
  Parameter get selectChildArgs => Parameter((p) => p
    ..name = 'childName'
    ..type = refer('String')
    ..defaultTo = Code('\'\'')
    ..named = false
    ..required = false);
  Parameter get databaseArgs => Parameter((p) => p
    ..name = 'database'
    ..type = refer('Database'));
  Parameter get fromArgs => Parameter((p) => p
    ..name = 'json'
    ..type = refer('Map'));
  List<Parameter> get keysRequiredArgs => [
        for (final key in keys)
          if (key is AForeignKey)
            for (final k in key.entityParent?.keys ?? <AProperty>[])
              if (k is AForeignKey)
                for (final sk in key.entityParent?.keys ?? <AProperty>[])
                  Parameter((p) => p
                    ..name = '${k.nameDefault}_${sk.nameDefault}'.toCamelCase()
                    ..type = refer(sk.dartType.toString()))
              else
                Parameter((p) => p
                  ..name = '${key.nameDefault}_${k.nameDefault}'.toCamelCase()
                  ..type = refer(k.dartType.toString()))
          else
            Parameter((p) => p
              ..name = key.nameDefault
              ..type = refer(key.dartType.toString()))
      ];
  List<Parameter> get fieldOptionalArgs => [
        for (final item in aPs)
          Parameter((f) => f
            ..name = item.nameDefault
            ..named = true
            ..required = false
            ..toThis = true)
      ];
}

extension AFields on AEntity {
  List<Field> get fFields => [
        for (final item in aPs)
          Field(
            (f) => f
              ..name = item.nameDefault
              ..modifier = FieldModifier.final$
              ..type = refer(item is AForeignKey
                  ? '${item.entityParent?.selectClassName}?'
                  : 'bool?'),
          ),
      ];
  List<Field> get selectFields => [
        for (final item in aPs)
          Field((f) => f
            ..name = item.nameDefault
            ..modifier = FieldModifier.final$
            ..type = refer(item is AForeignKey
                ? '${item.entityParent?.selectClassName}?'
                : 'bool?'))
      ];
  List<Field> get whereFields => [
        for (final item in aPs)
          Field((f) => f
            ..name = item.nameDefault
            ..modifier = FieldModifier.final$
            ..type = refer(item is AForeignKey
                ? '\$${item.entityParent?.className}WhereArgs?'
                : '${item.dartType.toString().replaceFirst('?', '')}?'))
      ];
  List<AProperty> get keys {
    return [
      for (final item in primaryKeys)
        foreignKeys
                .firstWhereOrNull((e) => e.nameDefault == item.nameDefault) ??
            item
    ];
  }

  List<String> get _whereArgs {
    return [
      for (final key in keys)
        if (key is AForeignKey)
          for (final item in key.entityParent?.keys ?? [])
            '${key.defaultSuffix}.${item.nameToDB}'
        else
          key.nameToDB
    ];
  }

  List<String> get _whereStaticArgs =>
      _whereArgs.map((e) => e.toCamelCase()).toList();

  List<String> get _whereDB {
    return [
      for (final key in keys) '${className.toSnakeCase()}.${key.nameToDB} = ?'
    ];
  }
}
