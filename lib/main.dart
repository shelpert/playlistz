import 'package:flutter/material.dart';
import 'package:random_words/random_words.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_id/device_id.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: "Playlistz", theme: ThemeData.dark(), home: Generator());
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

class Generator extends StatefulWidget {
  @override
  GeneratorState createState() => GeneratorState();
}

class GeneratorState extends State<Generator> {
  PlaylistName plName = PlaylistName();
  final saved = Set<String>();

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
    setState(() {
      if (plName.isSaved) {
        plName.isSaved = false;
        plName.style = plName.unsaved;
        saved.remove(plName.name);
      } else {
        plName.isSaved = true;
        plName.style = plName.saved;
        saved.add(plName.name);
      }
    });
  }

  void _awaitSavedList(BuildContext context) async {
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SavedList(saved: saved, current: plName),
        ));

    setState(() {
      plName = result;
    });
  }
}

class SavedList extends StatefulWidget {
  final saved;
  final current;
  SavedList({this.saved, this.current});

  @override
  SavedListState createState() =>
      SavedListState(saved: this.saved, current: this.current);
}

class SavedListState extends State<SavedList> {
  Set<String> saved;
  PlaylistName current;

  SavedListState({this.saved, this.current});

  @override
  Widget build(BuildContext context) {
    final savedList = saved.toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('Fire Playlistz'),
        leading: new IconButton(
          icon: new Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(current),
        ),
      ),
      body: ListView.builder(
          itemCount: savedList.length,
          itemBuilder: (context, index) {
            final item = savedList[index];
            return Dismissible(
                key: Key(item),
                onDismissed: (direction) {
                  setState(() {
                    saved.remove('$item');
                    if ('$item' == current.name) {
                    current.style = current.unsaved;
                    current.isSaved = false;
                    }
                  });
                },
                background: Container(color: Colors.red),
                child: Column(children: <Widget>[
                  ListTile(
                      title: Text('$item', style: TextStyle(fontSize: 20))),
                  Divider()
                ]));
          }),
    );
  }
}
