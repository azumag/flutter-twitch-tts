import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class ConfigPage extends StatefulWidget {
  const ConfigPage({key}) : super(key: key);

  @override
  _ConfigPageState createState() => _ConfigPageState();
}

/// This is the private State class that goes with MyStatefulWidget.
class _ConfigPageState extends State<ConfigPage> {
  double _currentSliderValue = 1.0;
  List<dynamic> languages;
  String _languageChoice = 'ja-JP';
  bool _disableSelfAd = false;
  bool _disableAd = false;

  @override
  void initState() {
    super.initState();
    setConfigValue();
  }

  void setConfigValue() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      this._currentSliderValue = prefs.getDouble('ttsSpeed') ?? 1.0;
      this._languageChoice = prefs.getString('languageChoice') ?? 'ja-JP';
      this._disableAd = prefs.getBool('disableAd') ?? false;
      this._disableSelfAd = prefs.getBool('disableSelfAd') ?? false;
    });
  }

  Future<List<dynamic>> _getLanguageList() async {
    FlutterTts flutterTts = FlutterTts();
    final languages = await flutterTts.getLanguages;
    return languages;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Config'),
          centerTitle: true,
        ),
        body: Container(
          padding: EdgeInsets.all(10),
          margin: EdgeInsets.all(30),
          child: Column(
            children: [
              Text('TTS Speed: ' + _currentSliderValue.toString()),
              Slider(
                value: _currentSliderValue,
                min: 0,
                max: 2,
                divisions: 40,
                label: _currentSliderValue.toString(),
                onChanged: (double value) async {
                  final SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  prefs.setDouble('ttsSpeed', value);
                  setState(() {
                    _currentSliderValue = value;
                  });
                },
              ),
              Divider(
                height: 20,
                thickness: 5,
                indent: 0,
                endIndent: 0,
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                Text('Language Select: '),
                FutureBuilder(
                    future: _getLanguageList(),
                    builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
                      if (snapshot.hasData) {
                        return DropdownButton(
                            value: _languageChoice,
                            onChanged: (value) async {
                              final SharedPreferences prefs =
                                  await SharedPreferences.getInstance();
                              prefs.setString('languageChoice', value);
                              setState(() {
                                this._languageChoice = value;
                              });
                            },
                            items: snapshot.data
                                .map((e) => DropdownMenuItem<String>(
                                      value: e,
                                      child: Text(e),
                                    ))
                                .toList());
                      } else {
                        return Text('loading');
                      }
                    })
              ]),
              Divider(
                height: 20,
                thickness: 5,
                indent: 0,
                endIndent: 0,
              ),
              CheckboxListTile(
                activeColor: Colors.blue,
                title: Text('上部広告を外す'),
                controlAffinity: ListTileControlAffinity.leading,
                value: _disableSelfAd,
                onChanged: (value) async {
                  final SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  prefs.setBool('disableSelfAd', value);
                  setState(() {
                    this._disableSelfAd = value;
                  });
                },
              ),
              CheckboxListTile(
                activeColor: Colors.blue,
                title: Text('下部広告を外す'),
                controlAffinity: ListTileControlAffinity.leading,
                value: _disableAd,
                onChanged: (value) async {
                  final SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  prefs.setBool('disableAd', value);
                  setState(() {
                    this._disableAd = value;
                  });
                },
              ),
            ],
          ),
        ));
  }
}
