// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cat.dart';

// **************************************************************************
// SqfliteModelGenerator
// **************************************************************************

extension CatQuery on Cat {
  static String createTable = '''CREATE TABLE IF NOT EXISTS Cat(
		key INTEGER PRIMARY KEY AUTOINCREMENT,
			age TEXT NOT NULL,
			name TEXT NOT NULL
	)''';

  static const $CatSelectArgs $default =
      $CatSelectArgs(key: true, age: true, name: true);

  static String $createSelect(
    $CatSelectArgs? select, [
    String childName = '',
  ]) =>
      select?.$check == true
          ? [
              if (select?.key ?? false)
                '${childName}cat.key as ${childName}cat_key',
              if (select?.age ?? false)
                '${childName}cat.age as ${childName}cat_age',
              if (select?.name ?? false)
                '${childName}cat.name as ${childName}cat_name'
            ].join(',')
          : $createSelect($default);
  static String $createWhere(
    $CatWhereArgs? where, [
    String childName = '',
  ]) =>
      [
        if (where?.key != null) '${childName}cat.key = ${where?.key}',
        if (where?.age != null) '${childName}cat.age = \'${where?.age}\'',
        if (where?.name != null) '${childName}cat.name = \'${where?.name}\''
      ].join(' AND ').whereStr;
  static Future<List<Cat>> getAll(
    Database database, {
    $CatSelectArgs? select,
    $CatWhereArgs? where,
  }) async =>
      (await database.rawQuery('''SELECT ${$createSelect(select)} FROM Cat cat
''') as List<Map>).map(Cat.fromDB).toList();
  Future<int> insert(Database database) async {
    final $id = await database.rawInsert('''INSERT OR REPLACE INTO Cat (key,
age,
name) 
       VALUES(?, ?, ?)''', [
      key,
      age,
      name,
    ]);
    return $id;
  }

  Future<int> update(Database database) async {
    return await database
        .update('Cat', toDB(), where: "cat.key = ?", whereArgs: [key]);
  }

  static Future<Cat?> getById(
    Database database,
    int? key, {
    $CatSelectArgs? select,
  }) async {
    final res = (await database.rawQuery('''
SELECT 
${$createSelect(select)}
 FROM Cat cat
WHERE cat.key = ?
''', [key]) as List<Map>);
    return res.isNotEmpty ? Cat.fromDB(res.first) : null;
  }

  Future<void> delete(Database database) async {
    await database.rawQuery('''DELETE FROM Cat cat WHERE cat.key = ?''', [key]);
  }

  static Future<void> deleteById(
    Database database,
    int? key,
  ) async {
    await database.rawQuery('''DELETE FROM Cat cat WHERE cat.key = ?''', [key]);
  }

  static Future<void> deleteAll(Database database) async {
    await database.rawDelete('''DELETE * FROM Cat''');
  }

  static Cat $fromDB(
    Map json, [
    String childName = '',
  ]) =>
      Cat(
        key: json['${childName}cat_key'] as int?,
        age: json['${childName}cat_age'] as String,
        name: json['${childName}cat_name'] as String,
      );
  Map<String, dynamic> $toDB() => {
        'key': key,
        'age': age,
        'name': name,
      };
}

class $CatSelectArgs {
  const $CatSelectArgs({
    this.key,
    this.age,
    this.name,
  });

  final bool? key;

  final bool? age;

  final bool? name;

  bool get $check => key == true || age == true || name == true;
}

class $CatWhereArgs {
  const $CatWhereArgs({
    this.key,
    this.age,
    this.name,
  });

  final int? key;

  final String? age;

  final String? name;
}
