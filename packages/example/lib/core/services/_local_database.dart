import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_annotation/sqflite_annotation.dart';

import '_local_database.db_config.dart';

export 'package:flutter/services.dart' show RootIsolateToken;

void initIsolateToken(RootIsolateToken token) {
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);
}

bool get kTest => Platform.environment.containsKey('FLUTTER_TEST');

mixin LocalDatabase {
  static late Database? _db;
  Database? get instance => _db;

  static Future<void> init([@visibleForTesting Database? dbTesting]) async {
    try {
      if (dbTesting != null) {
        _db = dbTesting;
        return;
      }
      _db = await configSql();
    } catch (e, stacktrace) {
      log('Init local failed: $e', stackTrace: stacktrace);
    }
  }

  static Future clearDatabase() async {
    // await _isar?.writeTxn<void>(() async {
    //   await _isar?.clear();
    // });
  }

  static Future<bool?> dispose() async {
    // return _isar?.close();
    // TODO(hodpOmi): doing
    return null;
  }
}

abstract class BaseLocalDatabase<T> {
  Stream<List<T>> listenDb() {
    throw UnimplementedError('listenDb $T');
  }

  Future<List<T>> getAll([Database? db]) {
    throw UnimplementedError('getAll $T');
  }

  Future<List<T>> getAllTask([RootIsolateToken? token]) async {
    Database? db;
    if (!kTest) {
      db = await configSql(token);
    }
    final lst = await getAll(db);
    return lst;
  }

  Future<List<T>> gets({required int limit, required int offset}) {
    throw UnimplementedError('gets $T');
  }

  Future<T?> get(String id) {
    throw UnimplementedError('get $T');
  }

  Future<T?> getByKey(int id) {
    throw UnimplementedError('getByKey $T');
  }

  Future<List<T>> filter() {
    throw UnimplementedError('filter $T');
  }

  Future<int> insert(T model) {
    throw UnimplementedError('insert $T');
  }

  Future<T> insertModel(T model) async {
    throw UnimplementedError('insert $T');
  }

  Future<bool> insertAll(List<T> models, [Database? db]) {
    throw UnimplementedError('insertAll $T');
  }

  Future<bool> insertAllTask(LocalTaskList<T> model) async {
    if (model.token == null && !kTest) throw Exception('token null');
    if (!kTest) {
      initIsolateToken(model.token!);
    }

    Database? db;
    if (!kTest) {
      db = await configSql(model.token);
    }
    final lst = await insertAll(model.models, db);
    return lst;
  }

  Future<int> update(T model) {
    throw UnimplementedError('update $T');
  }

  Future<List<int>> updateAll(List<T> models) {
    throw UnimplementedError('update $T');
  }

  /// Delete by key
  Future<bool> delete(int id) {
    throw UnimplementedError('delete $T');
  }
}

class LocalTask<T> {
  LocalTask({required this.model, required this.token});

  final T model;
  final RootIsolateToken? token;
}

class LocalTaskList<T> {
  LocalTaskList({required this.models, required this.token});

  final List<T> models;
  final RootIsolateToken? token;
}

@SqlConfig('pegasus.db')
Future<Database> configSql([RootIsolateToken? token]) => $configSql(token);
