// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// ConfigGenerator
// **************************************************************************

// ignore_for_file: lines_longer_than_80_chars, prefer_relative_imports, directives_ordering, require_trailing_commas, always_put_required_named_parameters_first

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:developer';
import 'package:flutter/services.dart';

import 'package:example/core/models/cat.dart' as i0;

import 'package:sql_external_db/sql_external_db.dart';

import 'dart:io';

final List<String> _schemas = [i0.CatQuery.createTable];

Future<Database> $configSql([RootIsolateToken? token]) async {
  if (token != null) {
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  }
  Directory? documentsDirectory;
  final pathNative = await SqlExternalDb.instance
      .externalPath('group.com.hodoan.db_shared//demo.db');
  if (pathNative != null) {
    documentsDirectory = Directory(pathNative);
  }

  assert(documentsDirectory != null, 'external storage directory is empty');
  final path = join(documentsDirectory!.path, 'demo.db');

  final database = await openDatabase(
    path,
    version: 1,
    onOpen: (db) {
      log('db open');
    },
    onCreate: (Database db, int version) async {
      log('db create');
      await Future.wait([for (final schema in _schemas) db.execute(schema)]);
      log('db end create');
    },
    onConfigure: (db) async {
      await db.execute('PRAGMA foreign_keys = ON');
    },
  );

  return database;
}

Future<void> $clearDatabase(Database db) =>
    Future.wait([i0.CatQuery.deleteAll(db)]);
