import 'dart:math';

import 'package:flutter/material.dart' hide Page;
import 'package:live_paginated_list/live_paginated_list.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paginated Live List Demo',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _generator = Random();

  PaginationController<int> controller;

  @override
  initState() {
    super.initState();
    controller = PaginationController(_streamPage, true);
  }

  Stream<Page<int>> _streamPage(PageCursor cursor) async* {
    final pageIndex = (cursor as IntPageCursor)?.next ?? 0;
    while (true) {
      await Future.delayed(Duration(seconds: _generator.nextInt(5)));
      yield Page(
        List.generate(5, (index) => _generator.nextInt((pageIndex+1) * 5) + pageIndex * 5),
        IntPageCursor(pageIndex + 1),
        pageIndex == 9,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LivePaginatedList<int>(
        controller: controller,
        itemBuilder: (context, state, index) {
          return Container(
            height: 128.0,
            width: double.infinity,
            color: Colors.primaries[index % Colors.primaries.length],
            child: Text(state.items[index].toString()),
          );
        },
        progressBuilder: (context) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ));
        },
      ),
    );
  }
}
