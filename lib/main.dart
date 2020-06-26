import 'dart:io' show Platform;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:random_words/random_words.dart';

void main() {
  runApp(MyApp());
}

final coll = Firestore.instance.collection('users');
String deviceId;

Future<String> getId() async {
  final deviceInfo = DeviceInfoPlugin();
  return kIsWeb
      ? 'anon${Random().nextInt(10000)}'
      : Platform.isIOS
          ? (await deviceInfo.iosInfo).identifierForVendor
          : Platform.isAndroid
              ? (await deviceInfo.androidInfo).androidId
              : 'anon${Random().nextInt(10000)}';
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    getId().then((id) => deviceId = id);
    return StreamBuilder<QuerySnapshot>(
        stream: coll.snapshots(),
        builder: (context, snapshot) => snapshot.hasData
            ? GlobalSnapshot(snapshot: snapshot, child: start)
            : loading);
  }
}

class GlobalSnapshot extends InheritedWidget {
  final AsyncSnapshot<QuerySnapshot> snapshot;

  @override
  bool updateShouldNotify(GlobalSnapshot oldWidget) => true;

  GlobalSnapshot({Widget child, this.snapshot}) : super(child: child);

  static GlobalSnapshot of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<GlobalSnapshot>();
  }
}

final start = MaterialApp(
    title: "Playlistz",
    theme: ThemeData.dark(),
    initialRoute: '/',
    routes: {
      '/': (context) => Initiate(),
      '/home': (context) => Generator(),
      '/saved': (context) => SavedList(),
    });

final loading = Scaffold(
  body: Center(
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
        SizedBox(
          child: CircularProgressIndicator(),
          width: 20,
          height: 20,
        ),
        const Padding(
            padding: EdgeInsets.only(top: 16), child: Text('Loading...'))
      ])),
);

const unsaved = TextStyle(fontSize: 50, fontWeight: FontWeight.bold);
const saved = TextStyle(
    fontSize: 50, fontWeight: FontWeight.bold, color: Colors.lightGreen);

class Initiate extends StatefulWidget {
  @override
  InitiateState createState() => InitiateState();
}

class InitiateState extends State<Initiate> {
  Stream<DocumentSnapshot> stream;
  @override
  void initState() {
    super.initState();
    _setupName();
  }

  void _setupName() async {
    final users = await coll.where('id', isEqualTo: deviceId).getDocuments();

    ///
    if (users.documents.isEmpty) {
      final controller = TextEditingController();
      final name = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
                  title: Text('What is your name?'),
                  content: TextField(
                    controller: controller,
                    autofocus: true,
                    onSubmitted: (text) {
                      Navigator.pop(context, text);
                    },
                  ),
                  actions: <Widget>[
                    FlatButton(
                      child: Text('Submit'),
                      onPressed: () {
                        Navigator.pop(context, controller.text);
                      },
                    )
                  ]));
      coll.add({'id': deviceId, 'name': name, 'saved': []});
    }
  }

  @override
  Widget build(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, '/home', (Route<dynamic> route) => false);
    return Container(
      child: Text("Hello"),
    );
  }
}

class Generator extends StatefulWidget {
  //final DocumentSnapshot snapshot;
  //Generator({this.snapshot});

  @override
  GeneratorState createState() => GeneratorState();

  ///
}

extension on DocumentSnapshot {
  ///
  TextStyle style(String name) => isSaved(name) ? saved : unsaved;
  bool isSaved(String name) => savedList.contains(name);
  List<String> get savedList => List.from(data['saved']);
  Future delete(String s) => _updateSaved(FieldValue.arrayRemove([s]));
  Future add(String s) => _updateSaved(FieldValue.arrayUnion([s]));
  Future toggle(String s) => isSaved(s) ? delete(s) : add(s);
  Future _updateSaved(dynamic value) => reference.updateData({'saved': value});
  String get name => data['name'];
  String get id => data['id'];
  List<Map> get receivedList => List.from(data['received']);
}

class GeneratorState extends State<Generator> {
  String name;

  @override

  ///
  void initState() {
    super.initState();
    updateName(false);
  }

  void updateName([bool callSetState = true]) {
    final adjective =
        WordAdjective.random(maxSyllables: 4, safeOnly: false).asCapitalized;
    final noun =
        WordNoun.random(maxSyllables: 4, safeOnly: false).asCapitalized;
    final name = [adjective, noun].join(' ');
    if (callSetState) {
      ///
      setState(() => this.name = name);
    } else {
      this.name = name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final DocumentSnapshot snapshot = GlobalSnapshot.of(context)
        .snapshot
        .data
        .documents
        .singleWhere((element) => element['id'] == deviceId);
    return Scaffold(
        appBar: AppBar(
          title: Text("Playlistz"),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.list, size: 30),
              onPressed: () => Navigator.pushNamed(context, '/saved'),
            ),
            /*IconButton(
            icon: Icon(Icons.list, size: 30),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReceivedList,
              ),
            ),
          )*/
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text("Hello ${snapshot.name}!",
                  style: TextStyle(fontSize: 20, color: Colors.blue)),
              Text('Is This Name Fire?', style: TextStyle(fontSize: 40)),
              Container(
                height: 300,
                //color: Colors.orange,
                child: Center(
                    child: Text(name,
                        textAlign: TextAlign.center,
                        style: snapshot.style(name))),
              ),
              MaterialButton(
                onPressed: updateName,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.refresh, size: 50),
                    Text(' New', style: TextStyle(fontSize: 30))
                  ],
                ),
                shape: StadiumBorder(),
                color: Colors.orange,
                minWidth: 80,
                height: 60,
              )
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => snapshot.toggle(name),
          child: Icon(Icons.whatshot, size: 30),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ));
  }
}

class SavedList extends StatefulWidget {
  //final DocumentSnapshot snapshot;
  //SavedList({@required this.snapshot});

  @override
  SavedListState createState() => SavedListState();
}

class SavedListState extends State<SavedList> {
  @override
  Widget build(BuildContext context) {
    final DocumentSnapshot snapshot = GlobalSnapshot.of(context)
        .snapshot
        .data
        .documents
        .singleWhere((element) => element['id'] == deviceId);
    final saved = snapshot.savedList;
    return Scaffold(
      appBar: AppBar(title: Text("${snapshot.name}'s Fire Playlistz")),
      body: ListView.builder(
        itemCount: saved.length,
        itemBuilder: (context, index) {
          final item = saved[index];
          return Dismissible(
            key: ValueKey(item),
            onDismissed: (_) => snapshot.delete(item),
            background: Container(color: Colors.red),
            child: Column(
              children: <Widget>[
                ListTile(title: Text('$item', style: TextStyle(fontSize: 20))),
                Divider(),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => newName(snapshot),
        child: Icon(Icons.add, size: 30),
      ),
    );
  }

  void newName(snapshot) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text('Add your own playlist name'),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  onSubmitted: (text) {
                    Navigator.pop(context, text);
                  },
                ),
                actions: <Widget>[
                  FlatButton(
                    child: Text('Submit'),
                    onPressed: () {
                      Navigator.pop(context, controller.text);
                    },
                  )
                ]));
    snapshot.add(name);
  }
}
/*
class ReceivedList extends StatefulWidget {
  final DocumentSnapshot snapshot;
  ReceivedList({@required this.snapshot});

  @override
  ReceivedListState createState() => ReceivedListState();
}

class ReceivedListState extends State<ReceivedList> {
  @override
  Widget build(BuildContext context) {
    final rec = widget.snapshot.receivedList;
    return Scaffold(
        appBar: AppBar(title: Text("Received Names")),
        body: ListView.builder(
            itemCount: rec.length,
            itemBuilder: (context, index) {
              final item = rec[index];
              void _addReceived() {
                widget.snapshot.add(item['name']);
                widget.snapshot.reference.updateData({
                  'received': FieldValue.arrayRemove([item])
                });
              }

              return Column(
                children: <Widget>[
                  Expanded(child:
                  ListTile(
                      key: UniqueKey(),
                      title: Text(item['name']),
                      subtitle: Text(item['sender']),
                      trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            MaterialButton(
                              onPressed: _addReceived,
                              child: Text('Add'),
                              shape: StadiumBorder(),
                              color: Colors.lightGreen,
                              minWidth: 8.0,
                            ),
                            SizedBox(
                              width: 15.0,
                            ),
                            MaterialButton(
                                onPressed: () =>
                                    widget.snapshot.reference.updateData({
                                      'received': FieldValue.arrayRemove([item])
                                    }),
                                child: Text('Nah'),
                                shape: StadiumBorder(),
                                color: Colors.red,
                                minWidth: 8.0),
                          ]))),
                  Divider(),
                ],
              );
            }));
  }
}*/
