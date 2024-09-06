import 'dart:async';
import 'dart:developer';

import 'package:example/core/models/cat.dart';
import 'package:example/core/services/_local_database.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await LocalDatabase.init();
      runApp(const MyApp());
    },
    (e, s) {
      log(e.toString());
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with LocalDatabase {
  List<Cat> _cats = [];

  @override
  void initState() {
    _requestPer();
    try {
      Cat(
        age: DateTime.now().toString(),
        name: 'Cat ${DateTime.now()}',
      ).insert(instance!);
      _initList();
    } catch (e) {
      print(e);
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (final cat in _cats)
              Text(
                cat.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _initList,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _initList() async {
    Cat(
      age: DateTime.now().toString(),
      name: 'Cat ${DateTime.now()}',
    ).insert(instance!);
    final cats = await CatQuery.getAll(instance!);
    setState(() {
      _cats = cats;
    });
  }

  void _requestPer() async {
    await Permission.storage.request().then(print);
    await Permission.manageExternalStorage.request().then(print);
  }
}
