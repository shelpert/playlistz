import 'dart:io' show Platform;
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info/device_info.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:random_words/random_words.dart';

void main() {
  runApp(MyApp());
}

Future<RemoteConfig> setupRemoteConfig() async {
  final RemoteConfig remoteConfig = await RemoteConfig.instance;
  // Enable developer mode to relax fetch throttling
  remoteConfig.setConfigSettings(RemoteConfigSettings(debugMode: true));
  remoteConfig.setDefaults(<String, dynamic>{
    'askName': 'What is your name?',
    'sendColor': 0xFF2196F3,
    'fireColor': 0xFFF44336,
    'newColor': 0xFFFF9800,
    'title': 'Playlistz',
    'drawerTitle': 'Options',
    'drawerColor': 0xFFF44336,
    'drawerSaved': 'Saved',
    'drawerReceived': 'Received',
    'fireName': 'Is This Name Fire?',
    'fireNameSize': 40.0,
    'addColor': 0xFFF44336,
    'dismissColor': 0xFFF44336,
    'addReceived': 'Add',
    'addReceivedColor': 0xFF8BC43A,
    'ignoreReceived': 'Nah',
    'ignoreReceivedColor': 0xFFF44336,
  });
  await remoteConfig.fetch(expiration: const Duration(seconds: 0));
  await remoteConfig.activateFetched();

  return remoteConfig;
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

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final usersStream = coll.snapshots();
  final rcFuture = setupRemoteConfig();
  final idFuture = getId();

  RemoteConfig remoteConfig;

  String deviceId;
  @override
  void initState() {
    super.initState();
    // Wait for both futures to finish before proceeding
    Future.wait([idFuture, rcFuture]).then((list) {
      final RemoteConfig rc = list[1];
      final String id = list[0];
      setState(() {
        // Do the mutation of state within this "closure" inside `setState`.
        this.remoteConfig = rc;
        this.deviceId = id;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if ([remoteConfig, deviceId].any((x) => x == null)) {
      return Container();
    }
    return StreamBuilder<QuerySnapshot>(
        stream: usersStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container();
          }
          return Provider.value(
            value: GlobalSnapshot(
                snapshot: snapshot.data,
                remoteConfig: remoteConfig,
                deviceId: deviceId),
            child: start,
          );
        });
  }
}

class GlobalSnapshot {
  GlobalSnapshot(
      {@required this.snapshot,
      @required this.remoteConfig,
      @required this.deviceId}) {
    final documentList = snapshot.documents;
    documentMap = documentList
        .asMap()
        .map((index, value) => MapEntry(value['id'], value));
    docSnap = documentMap[deviceId];
  }
  final QuerySnapshot snapshot;
  final RemoteConfig remoteConfig;
  final String deviceId;
  DocumentSnapshot docSnap;
  Map documentMap;
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

final unsaved = TextStyle(fontSize: 50, fontWeight: FontWeight.bold);
final saved = TextStyle(
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
  List<Map> get receivedList => List.from(data['received']);
}

class Generator extends StatefulWidget {
  @override
  GeneratorState createState() => GeneratorState();
}

class GeneratorState extends State<Generator> {
  String name;

  @override
  void initState() {
    super.initState();
    _setupName();
    updateName(false);
  }

  void _setupName() async {
    final users = await coll.where('id', isEqualTo: deviceId).getDocuments();

    if (users.documents.isEmpty) {
      final remoteConfig = Provider.of<GlobalSnapshot>(context).remoteConfig;
      final controller = TextEditingController();
      final name = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
                  title: Text(remoteConfig.getString('askName')),
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
    final snapshot = Provider.of<GlobalSnapshot>(context).docSnap;
    if (snapshot == null) {
      return loading;
    } else {
      final remoteConfig = Provider.of<GlobalSnapshot>(context).remoteConfig;
      return Scaffold(
          appBar: AppBar(
            title: Text(remoteConfig.getString('title')),
          ),
          endDrawer: mainDrawer(remoteConfig: remoteConfig),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Text(remoteConfig.getString('fireName'),
                    style: TextStyle(
                        fontSize: remoteConfig.getDouble('fireNameSize'))),
                Container(
                  height: 300,
                  child: Center(
                      child: Text(name,
                          textAlign: TextAlign.center,
                          style: snapshot.style(name))),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    MaterialButton(
                      onPressed: () => {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Sending(name: name),
                            ))
                      },
                      child: Icon(Icons.send, size: 30),
                      shape: CircleBorder(),
                      color: Color(remoteConfig.getInt('sendColor')),
                      minWidth: 80,
                      height: 60,
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
                      color: Color(remoteConfig.getInt('newColor')),
                      minWidth: 80,
                      height: 60,
                    ),
                    MaterialButton(
                      onPressed: () => snapshot.toggle(name),
                      child: Icon(Icons.whatshot, size: 30),
                      shape: CircleBorder(),
                      color: Color(remoteConfig.getInt('fireColor')),
                      minWidth: 80,
                      height: 60,
                    )
                  ],
                )
              ],
            ),
          ));
    }
  }

  Widget mainDrawer({@required remoteConfig}) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          Container(
              height: 80.0,
              child: DrawerHeader(
                  child: Text(remoteConfig.getString('drawerTitle')),
                  decoration: BoxDecoration(
                      color: Color(remoteConfig.getInt('drawerColor'))),
                  margin: EdgeInsets.all(0.0),
                  padding: EdgeInsets.all(20.0))),
          ListTile(
              title: Text(remoteConfig.getString('drawerSaved')),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/saved');
              }),
          ListTile(
            title: Text(remoteConfig.getString('drawerReceived')),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/received');
            },
          ),
        ],
      ),
    );
  }
}

class SavedList extends StatefulWidget {
  @override
  SavedListState createState() => SavedListState();
}

class SavedListState extends State<SavedList> {
  @override
  Widget build(BuildContext context) {
    final DocumentSnapshot snapshot =
        Provider.of<GlobalSnapshot>(context).docSnap;
    final saved = snapshot.savedList;
    final RemoteConfig remoteConfig =
        Provider.of<GlobalSnapshot>(context).remoteConfig;
    return Scaffold(
      appBar: AppBar(title: Text("${snapshot.name}'s Fire Playlistz")),
      body: ListView.builder(
        itemCount: saved.length,
        itemBuilder: (context, index) {
          final item = saved[index];
          return Dismissible(
            key: ValueKey(item),
            onDismissed: (_) => snapshot.delete(item),
            background:
                Container(color: Color(remoteConfig.getInt('dismissColor'))),
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
        backgroundColor: Color(remoteConfig.getInt('addColor')),
        foregroundColor: Colors.white,
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
          if (name != null) {
            snapshot.add(name);
          }
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
    final DocumentSnapshot snapshot =
        Provider.of<GlobalSnapshot>(context).docSnap;
    final rec = snapshot.receivedList;
    final RemoteConfig remoteConfig =
        Provider.of<GlobalSnapshot>(context).remoteConfig;
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
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: <
                          Widget>[
                        MaterialButton(
                          onPressed: _addReceived,
                          child: Text(remoteConfig.getString('addReceived')),
                          shape: StadiumBorder(),
                          color: Color(remoteConfig.getInt('addReceivedColor')),
                          minWidth: 8.0,
                        ),
                        SizedBox(
                          width: 8.0,
                        ),
                        MaterialButton(
                            onPressed: () => snapshot.reference.updateData({
                                  'received': FieldValue.arrayRemove([item])
                                }),
                            child:
                                Text(remoteConfig.getString('ignoreReceived')),
                            shape: StadiumBorder(),
                            color: Color(
                                remoteConfig.getInt('ignoreReceivedColor')),
                            minWidth: 8.0),
                      ])),
                  Divider(),
                ],
              );
            }));
  }
}

class Sending extends StatelessWidget {
  final String name;
  Sending({this.name});

  @override
  Widget build(BuildContext context) {
    final List<DocumentSnapshot> allDocuments =
        Provider.of<GlobalSnapshot>(context).snapshot.documents;
    final DocumentSnapshot docSnap =
        Provider.of<GlobalSnapshot>(context).docSnap;
    final String myName = docSnap['name'];
    final snapshot =
        allDocuments.where((element) => element['id'] != deviceId).toList();
    return Scaffold(
        appBar: AppBar(title: Text("Send")),
        body: ListView.builder(
            itemCount: snapshot.length,
            itemBuilder: (context, index) {
              final item = snapshot[index]['name'];
              final id = snapshot[index]['id'];
              final plName = name;
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
                                            Provider.of<GlobalSnapshot>(context)
                                                .documentMap[id];
                                        theirSnap.reference.updateData({
                                          'received': FieldValue.arrayUnion([
                                            {'name': plName, 'sender': myName}
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
