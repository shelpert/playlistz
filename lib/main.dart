import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:random_words/random_words.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info/device_info.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: "Playlistz", theme: ThemeData.dark(), home: Initiate());
  }
}

class PlaylistName {
  String name;
  TextStyle style;
  final unsaved = TextStyle(fontSize: 50, fontWeight: FontWeight.bold);
  final saved = TextStyle(
      fontSize: 50, fontWeight: FontWeight.bold, color: Colors.lightGreen);
  bool isSaved;

  PlaylistName() {
    name = 'Fire Playlist';
    style = unsaved;
    isSaved = false;
  }
}

class Initiate extends StatefulWidget {
  @override
  InitiateState createState() => InitiateState();
}

class InitiateState extends State<Initiate> {
  String name;

  Future _getId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isIOS) {
        return deviceInfo.iosInfo;
      } else {
        return deviceInfo.androidInfo; // unique ID on Android
      }
    } on PlatformException {
      print('Error');
    }
  }

  Future<List<Widget>> _checkUser({deviceId}) async {
    List<Widget> returnValue;
    final QuerySnapshot result = await Firestore.instance
        .collection('users')
        .where('id', isEqualTo: deviceId)
        .getDocuments();

    final List<DocumentSnapshot> docs = result.documents;

    if (docs.length == 0) {
      returnValue = <Widget>[
        AlertDialog(
            title: Text('What is your name?'),
            content: TextField(
              controller: TextEditingController(),
              onChanged: (text) {
                name = text;
              },
            ),
            actions: <Widget>[
              FlatButton(
                child: Text('Submit'),
                onPressed: () {
                  _newUser(deviceId);
                },
              )
            ])
      ];
      
    } else {
      //return <Widget>[Text('Finished')];
    }
    return returnValue;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _getId(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          List<Widget> children;
          if (snapshot.hasData) {
            final deviceId = snapshot.data.identifierForVendor;
            _checkUser(deviceId: deviceId).then((value) => children = value);
          } else {
            children = <Widget>[
              SizedBox(
                child: CircularProgressIndicator(),
                width: 20,
                height: 20,
              ),
              const Padding(
                  padding: EdgeInsets.only(top: 16), child: Text('Loading...'))
            ];
          }
          return Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: children));
        });
  }

  void _newUser(deviceId) {
    Firestore.instance
        .collection('users')
        .document(deviceId.data)
        .setData({'saved': [], 'id': deviceId, 'name': name});
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (context) => Generator(id: deviceId)));
  }
}

class Generator extends StatefulWidget {
  final id;
  Generator({this.id});

  @override
  GeneratorState createState() => GeneratorState(deviceId: this.id);
}

class GeneratorState extends State<Generator> {
  PlaylistName plName = PlaylistName();
  String deviceId;

  GeneratorState({this.deviceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Playlistz"),
          actions: <Widget>[
            IconButton(
                icon: Icon(Icons.list, size: 30),
                onPressed: () {
                  _awaitSavedList(context);
                })
          ],
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
                    child: Text(plName.name,
                        textAlign: TextAlign.center, style: plName.style)),
              ),
              MaterialButton(
                onPressed: _newPlaylistName,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.refresh, size: 50),
                    Text(' ', style: TextStyle(fontSize: 30)),
                    Text('New', style: TextStyle(fontSize: 30))
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
  }

  void _newPlaylistName() {
    setState(() {
      String adjective =
          WordAdjective.random(maxSyllables: 4, safeOnly: false).asCapitalized;
      String noun =
          WordNoun.random(maxSyllables: 4, safeOnly: false).asCapitalized;
      plName.name = '$adjective' + ' ' + '$noun';
      plName.style = plName.unsaved;
      plName.isSaved = false;
    });
  }

  void _savePlaylistName() {
    DocumentReference arr =
        Firestore.instance.collection('users').document(deviceId);
    if (plName.isSaved) {
      arr.updateData({
        'saved': FieldValue.arrayRemove([plName.name])
      });
    } else {
      arr.updateData({
        'saved': FieldValue.arrayUnion([plName.name])
      });
    }
    setState(() {
      if (plName.isSaved) {
        plName.isSaved = false;
        plName.style = plName.unsaved;
      } else {
        plName.isSaved = true;
        plName.style = plName.saved;
      }
    });
  }

  void _awaitSavedList(BuildContext context) async {
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SavedList(id: deviceId, current: plName),
        ));

    setState(() {
      plName = result;
    });
  }
}

class SavedList extends StatefulWidget {
  final id;
  final current;
  SavedList({this.id, this.current});

  @override
  SavedListState createState() =>
      SavedListState(id: this.id, current: this.current);
}

class SavedListState extends State<SavedList> {
  List<dynamic> saved;
  PlaylistName current;
  String id;
  DocumentReference arr;

  SavedListState({this.id, this.current});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Fire Playlistz'),
          leading: new IconButton(
            icon: new Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(current),
          ),
        ),
        body: StreamBuilder<DocumentSnapshot>(
            stream:
                Firestore.instance.collection('users').document(id).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return LinearProgressIndicator();
              saved = snapshot.data['saved'];
              return ListView.builder(
                  itemCount: saved.length,
                  itemBuilder: (context, index) {
                    final item = saved[index];
                    return Dismissible(
                        key: UniqueKey(),
                        onDismissed: (direction) {
                          setState(() {
                            if ('$item' == current.name) {
                              current.style = current.unsaved;
                              current.isSaved = false;
                            }
                          });
                          _updateSaved(item);
                        },
                        background: Container(color: Colors.red),
                        child: Column(children: <Widget>[
                          ListTile(
                              title: Text('$item',
                                  style: TextStyle(fontSize: 20))),
                          Divider()
                        ]));
                  });
            }));
  }

  void _updateSaved(item) async {
    arr = Firestore.instance.collection('users').document(id);
    await arr.updateData({
      'saved': FieldValue.arrayRemove(['$item'])
    });
  }
}
