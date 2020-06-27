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

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    getId().then((id) => deviceId = id);
    return StreamBuilder<QuerySnapshot>(
        stream: coll.snapshots(),
        builder: (context, snapshot) => snapshot.hasData
            ? GlobalSnapshot(snapshot: snapshot, child: start)
            : Container());
  }
}

class GlobalSnapshot extends InheritedWidget {
  GlobalSnapshot({Widget child, this.snapshot}) : super(child: child);

  final AsyncSnapshot<QuerySnapshot> snapshot;
  //final DocumentSnapshot doc = snapshot.data.documents.singleWhere((element) => element['id'] == deviceId);

  @override
  bool updateShouldNotify(GlobalSnapshot old) => true;

  static GlobalSnapshot of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<GlobalSnapshot>();
  }
}

final start = MaterialApp(
    title: "Playlistz",
    theme: ThemeData.dark(),
    initialRoute: '/home',
    routes: {
      '/home': (context) => Generator(),
      '/saved': (context) => SavedList(),
      '/received': (context) => ReceivedList(),
    });

const unsaved = TextStyle(fontSize: 50, fontWeight: FontWeight.bold);
const saved = TextStyle(
    fontSize: 50, fontWeight: FontWeight.bold, color: Colors.lightGreen);

extension on DocumentSnapshot {
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

class Generator extends StatefulWidget {
  @override
  GeneratorState createState() => GeneratorState();
}

class GeneratorState extends State<Generator> {
  String name;
  bool finished = false;

  @override
  void initState() {
    super.initState();
    _setupName().then((f) => setState(() => finished = f));
    updateName(false);
  }

  Future<bool> _setupName() async {
    final users = await coll.where('id', isEqualTo: deviceId).getDocuments();

    if (users.documents.isEmpty) {
      final controller = TextEditingController();
      final name = await showDialog<String>(
          context: context,
             barrierDismissible: false,
            builder: (context) => AlertDialog(
                  title: Text('What is your name?'),
                  content: TextField(
                    controller: controller,
                    autofocus: true,
                  ),
                  actions: <Widget>[
                    FlatButton(
                      child: Text('Submit'),
                      onPressed: () {
                        Navigator.pop(context, controller.text);
                      },
                    )
                  ]));
      coll.add({'id': deviceId, 'name': name, 'saved': [], 'received': []});
    }
    //setState(() {
    return finished = true;
    //});
  }

  void updateName([bool callSetState = true]) {
    final adjective =
        WordAdjective.random(maxSyllables: 4, safeOnly: false).asCapitalized;
    final noun =
        WordNoun.random(maxSyllables: 4, safeOnly: false).asCapitalized;
    final name = [adjective, noun].join(' ');
    if (callSetState) {
      setState(() => this.name = name);
    } else {
      this.name = name;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (finished) {
      final List<DocumentSnapshot> snapshotList =
        GlobalSnapshot.of(context).snapshot.data.documents;
      final int con = snapshotList.indexWhere((element) => element['id'] == deviceId);
      if (con != -1) {
        final DocumentSnapshot snapshot =
            snapshotList.singleWhere((element) => element['id'] == deviceId);
        return Scaffold(
            appBar: AppBar(
              title: Text("Playlistz"),
            ),
            endDrawer: Drawer(
              child: ListView(
                // Important: Remove any padding from the ListView.
                padding: EdgeInsets.zero,
                children: <Widget>[
                  Container(
                      height: 80.0,
                      child: DrawerHeader(
                          child: Text('Options',
                              style: TextStyle(color: Colors.white)),
                          decoration: BoxDecoration(color: Colors.blue),
                          margin: EdgeInsets.all(0.0),
                          padding: EdgeInsets.all(20.0))),
                  ListTile(
                      title: Text('Saved'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/saved');
                      }),
                  ListTile(
                    title: Text('Received'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/received');
                    },
                  ),
                ],
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('Is This Name Fire?', style: TextStyle(fontSize: 40)),
                  Container(
                    height: 300,
                    //color: Colors.orange,
                    child: Center(
                        child: Text(name,
                            textAlign: TextAlign.center,
                            style: snapshot.style(name))),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: <Widget>[
                      MaterialButton(
                        onPressed: () => {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => Sending(
                                    name: name, myName: snapshot.data['name']),
                              ))
                        },
                        child: Icon(Icons.send, size: 30),
                        shape: CircleBorder(),
                        color: Colors.blue,
                        minWidth: 80,
                        height: 60,
                      ),
                      SizedBox(
                        width: 30,
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
      } else {
        return loading;
      }
    } else {
      return loading;
    }
  }
}

class SavedList extends StatefulWidget {
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
        onPressed: () async {
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
        },
        child: Icon(Icons.add, size: 30),
      ),
    );
  }
}

class ReceivedList extends StatefulWidget {
  @override
  ReceivedListState createState() => ReceivedListState();
}

class ReceivedListState extends State<ReceivedList> {
  @override
  Widget build(BuildContext context) {
    final DocumentSnapshot snapshot = GlobalSnapshot.of(context)
        .snapshot
        .data
        .documents
        .singleWhere((element) => element['id'] == deviceId);
    final rec = snapshot.receivedList;
    return Scaffold(
        appBar: AppBar(title: Text("Received Names")),
        body: ListView.builder(
            itemCount: rec.length,
            itemBuilder: (context, index) {
              final item = rec[index];
              void _addReceived() {
                snapshot.add(item['name']);
                snapshot.reference.updateData({
                  'received': FieldValue.arrayRemove([item])
                });
              }

              return Column(
                children: <Widget>[
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
                              width: 8.0,
                            ),
                            MaterialButton(
                                onPressed: () => snapshot.reference.updateData({
                                      'received': FieldValue.arrayRemove([item])
                                    }),
                                child: Text('Nah'),
                                shape: StadiumBorder(),
                                color: Colors.red,
                                minWidth: 8.0),
                          ])),
                  Divider(),
                ],
              );
            }));
  }
}

class Sending extends StatefulWidget {
  final String name;
  final String myName;
  Sending({this.name, this.myName});

  @override
  SendingState createState() => SendingState();
}

class SendingState extends State<Sending> {
  @override
  Widget build(BuildContext context) {
    final List<DocumentSnapshot> snapshot =
        GlobalSnapshot.of(context).snapshot.data.documents;
    snapshot.removeWhere((element) => element['id'] == deviceId);
    return Scaffold(
        appBar: AppBar(title: Text("Send")),
        body: ListView.builder(
            itemCount: snapshot.length,
            itemBuilder: (context, index) {
              final item = snapshot[index]['name'];
              final id = snapshot[index]['id'];
              final plName = widget.name;
              return Column(
                children: <Widget>[
                  ListTile(
                      key: UniqueKey(),
                      title: Text(item),
                      onTap: () => showDialog<String>(
                          context: context,
                          builder: (context) => AlertDialog(
                                  title: Text('Send $plName to $item?'),
                                  actions: <Widget>[
                                    FlatButton(
                                      child: Text('Cancel'),
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                    ),
                                    FlatButton(
                                      child: Text('Send'),
                                      onPressed: () {
                                        DocumentSnapshot theirSnap =
                                            GlobalSnapshot.of(context)
                                                .snapshot
                                                .data
                                                .documents
                                                .singleWhere((element) =>
                                                    element['id'] == id);
                                        theirSnap.reference.updateData({
                                          'received': FieldValue.arrayUnion([
                                            {
                                              'name': plName,
                                              'sender': widget.myName
                                            }
                                          ])
                                        });
                                        Navigator.pop(context);
                                        Navigator.pop(context);
                                      },
                                    )
                                  ]))),
                  Divider(),
                ],
              );
            }));
  }
}
