import 'package:example/firebase_options.dart';
import 'package:example/offer_model.dart';
import 'package:example/offers_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:live_paginated_list/live_paginated_list.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final OffersController controller;

  @override
  initState() {
    super.initState();
    controller = OffersController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: ActionsButton(controller: controller),
      body: LivePaginatedList<Offer>(
        controller: controller,
        itemBuilder: (context, state, index) {
          final item = state.items[index];
          return Dismissible(
            key: ValueKey(item.id),
            direction: DismissDirection.endToStart,
            onDismissed: (direction) {
              controller.onDeleteOffer(item);
            },
            background: _buildDismissBackground(Alignment.centerRight),
            child: ListTile(
              leading: _buildAvatar(item.author),
              title: Text('\$${item.price}'),
              subtitle: Text('until ${_formatDate(item.availableUntil)}'),
              trailing: Text('on ${_formatDate(item.createdAt)}'),
            ),
          );
        },
        progressBuilder: (context) {
          return Center(
              child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ));
        },
      ),
    );
  }

  Widget _buildAvatar(String author) {
    return CircleAvatar(
      backgroundColor:
          Colors.primaries[author.hashCode % Colors.primaries.length],
      child: Text(
        author.split(' ').map((name) => name[0].toUpperCase()).join(),
      ),
    );
  }

  Widget _buildDismissBackground(AlignmentGeometry alignment) {
    return Container(
      color: Colors.red,
      child: Align(
        alignment: alignment,
        child: Icon(Icons.delete),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return date.toString().split(" ")[0];
  }
}

class ActionsButton extends StatefulWidget {
  const ActionsButton({
    Key? key,
    required this.controller,
  }) : super(key: key);

  final OffersController controller;

  @override
  State<ActionsButton> createState() => _ActionsButtonState();
}

class _ActionsButtonState extends State<ActionsButton> {
  bool isOpen = false;

  void _toggle() {
    setState(() {
      isOpen = !isOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isOpen) {
      return FloatingActionButton(
        child: Icon(Icons.arrow_back),
        onPressed: _toggle,
      );
    }

    final separator = const SizedBox(width: 12.0);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          child: Text(
            '+10',
            style: TextStyle(fontSize: 18.0),
          ),
          onPressed: () => widget.controller.onAddOffers(),
        ),
        separator,
        FloatingActionButton(
          child: Icon(Icons.clear_all),
          onPressed: () => widget.controller.onClearOffers(),
        ),
        separator,
        FloatingActionButton(
          child: Icon(Icons.arrow_forward),
          onPressed: _toggle,
        ),
      ],
    );
  }
}
