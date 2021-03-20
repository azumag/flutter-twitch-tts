import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConfigPage extends StatefulWidget {
  const ConfigPage({key}) : super(key: key);

  @override
  _ConfigPageState createState() => _ConfigPageState();
}

/// This is the private State class that goes with MyStatefulWidget.
class _ConfigPageState extends State<ConfigPage> {
  double _currentSliderValue = 1.0;

  @override
  void initState() {
    super.initState();
    setConfigValue();
  }

  void setConfigValue() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      this._currentSliderValue = prefs.getDouble('ttsSpeed') ?? 1.0;
    });
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
              Text('TTS Speed'),
              Slider(
                value: _currentSliderValue,
                min: 0,
                max: 2,
                divisions: 16,
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
              Text(_currentSliderValue.toString()),
            ],
          ),
        ));
  }
}
