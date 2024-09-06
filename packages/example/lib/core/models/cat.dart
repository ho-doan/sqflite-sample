import 'package:sqflite/sqflite.dart';
import 'package:sqflite_annotation/sqflite_annotation.dart';

part 'cat.g.dart';

@entity
class Cat {
  const Cat({
    this.key,
    this.cautions = const [],
    required this.age,
    required this.name,
  });

  factory Cat.fromDB(
    Map<dynamic, dynamic> json, [
    String childName = '',
  ]) =>
      CatQuery.$fromDB(json, childName);

  @primaryKey
  final int? key;

  @ForeignKey(name: 'cautionsId')
  final List<String> cautions;

  final String name;
  final String age;

  Map<String, dynamic> toDB() => $toDB();
}
