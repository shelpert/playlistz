import 'package:flutter/material.dart';
import 'package:random_words/random_words.dart';

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

class Generator extends StatefulWidget {
  @override
  GeneratorState createState() => GeneratorState();
}

class GeneratorState extends State<Generator> {
  String _playlistName = 'Fire Playlist';
  final saved = Set<String>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Playlistz"),
          actions: <Widget>[
            IconButton(icon: Icon(Icons.list, size: 30), onPressed: _showSaved)
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
                  child: Text('$_playlistName',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 50, fontWeight: FontWeight.bold)),
                ),
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
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ));
  }

  void _newPlaylistName() {
    setState(() {
      String adjective =
          WordAdjective.random(maxSyllables: 4, safeOnly: false).asCapitalized;
      String noun =
          WordNoun.random(maxSyllables: 4, safeOnly: false).asCapitalized;
      _playlistName = '$adjective' + ' ' + '$noun';
    });
  }

  void _savePlaylistName() {
    setState(() {
      saved.add(_playlistName);
    });
  }

  void _showSaved() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          final savedList = saved.toList();
          return Scaffold(
            appBar: AppBar(
              title: Text('Fire Playlistz'),
            ),
            body: ListView.builder(
                itemCount: savedList.length,
                itemBuilder: (context, index) {
                  final item = savedList[index];
                  return Dismissible(
                    key: Key(item),
                    onDismissed: (direction) {
                      setState(() {
                        savedList.removeAt(index);
                        saved.remove('$item');
                      });
                    },
                    background: Container(color: Colors.red),
                    child: Column(
                      children: <Widget>[
                        ListTile(title: Text('$item', style: TextStyle(fontSize: 20))),
                        Divider()
                      ]
                    )
                  );
                }),
          );
        },
      ),
    );
  }
}
