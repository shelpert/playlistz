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

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: "Playlistz", theme: ThemeData.dark(), home: Initiate());
  }
}

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
    _setupName().then((r) => setState(() => stream = r.snapshots())); ///
  }

  Future<DocumentReference> _setupName() async {
    final deviceInfo = DeviceInfoPlugin();
    final id = kIsWeb
        ? 'anon${Random().nextInt(10000)}'
        : Platform.isIOS
            ? (await deviceInfo.iosInfo).identifierForVendor
            : Platform.isAndroid
                ? (await deviceInfo.androidInfo).androidId
                : 'anon${Random().nextInt(10000)}';
    final users = await coll.where('id', isEqualTo: id).getDocuments(); ///
    if (users.documents.isNotEmpty) {
      return users.documents.first.reference;
    }
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
    return coll.add({'id': id, 'name': name, 'saved': []});
  }

  @override
  Widget build(BuildContext context) {
    if (stream == null) {
      return loading;
    }
    return StreamBuilder<DocumentSnapshot>(
        stream: stream,
        builder: (context, snapshot) =>
            snapshot.hasData ? Generator(snapshot: snapshot.data) : loading);
  }
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

class Generator extends StatefulWidget {
  final DocumentSnapshot snapshot;
  Generator({this.snapshot});

  @override
  GeneratorState createState() => GeneratorState(); ///
}

extension on DocumentSnapshot { ///
  TextStyle style(String name) => isSaved(name) ? saved : unsaved;
  bool isSaved(String name) => savedList.contains(name);
  List<String> get savedList => List.from(data['saved']);
  Future delete(String s) => _updateSaved(FieldValue.arrayRemove([s]));
  Future add(String s) => _updateSaved(FieldValue.arrayUnion([s]));
  Future toggle(String s) => isSaved(s) ? delete(s) : add(s);
  Future _updateSaved(dynamic value) => reference.updateData({'saved': value});
  String get name => data['name'];
  String get id => data['id'];
}

class GeneratorState extends State<Generator> {
  String name;

  @override ///
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
    if (callSetState) { ///
      setState(() => this.name = name);
    } else {
      this.name = name;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: Text("Playlistz"),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.list, size: 30),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SavedList(snapshot: widget.snapshot),
              ),
            ),
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text("Hello ${widget.snapshot.name}!",
                style: TextStyle(fontSize: 20, color: Colors.blue)),
            Text('Is This Name Fire?', style: TextStyle(fontSize: 40)),
            Container(
              height: 300,
              //color: Colors.orange,
              child: Center(
                  child: Text(name,
                      textAlign: TextAlign.center,
                      style: widget.snapshot.style(name))),
            ),
            MaterialButton(
              onPressed: updateName,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.refresh, size: 50),
                  Text(' New', style: TextStyle(fontSize: 30))
                ],
              ),
              shape: StadiumBorder(),
              color: Colors.orange,
              minWidth: 40,
              height: 60,
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _savePlaylistName,
        child: Icon(Icons.whatshot, size: 30),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ));

  void _savePlaylistName() => widget.snapshot.toggle(name);
}

class SavedList extends StatefulWidget {
  final DocumentSnapshot snapshot;
  SavedList({@required this.snapshot});

  @override
  SavedListState createState() => SavedListState();
}

class SavedListState extends State<SavedList> {
  @override
  Widget build(BuildContext context) {
    final saved = widget.snapshot.savedList;
    return Scaffold(
      appBar: AppBar(title: Text("${widget.snapshot.name}'s Fire Playlistz")),
      body: ListView.builder(
        itemCount: saved.length,
        itemBuilder: (context, index) {
          final item = saved[index];
          return Dismissible(
            key: UniqueKey(),
            onDismissed: (_) => widget.snapshot.delete(item),
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
    );
  }
}