import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
// import 'package:flutter_language_identification/flutter_language_identification.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:twitch_tts/configPage.dart';
import 'package:web_socket_channel/io.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Twitch TTS',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Twitch TTS'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _accessToken = '';
  StreamController streamController;
  List<String> messages = [];
  TextEditingController _targetChannelController = TextEditingController();
  bool streamState = false;
  bool manualStop = false;
  WebSocket streamSocket;
  FlutterTts flutterTts;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) WebView.platform = SurfaceAndroidWebView();
    if (Platform.isIOS) _iOSSetUp();
    setState(() {
      this.streamController = StreamController();
    });
    this.streamController.sink.add(this.messages);
  }

  void _iOSSetUp() async {
    flutterTts = FlutterTts();
    await flutterTts
        .setIosAudioCategory(IosTextToSpeechAudioCategory.playAndRecord, [
      IosTextToSpeechAudioCategoryOptions.allowBluetooth,
      IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
      IosTextToSpeechAudioCategoryOptions.mixWithOthers
    ]);
  }

  void _streamClose() async {
    await this.streamSocket.close();

    setState(() {
      this.manualStop = true;
      this.streamState = false;
    });
  }

  void _irc() async {
    if (streamState) return;
    // FlutterLanguageIdentification languageIdentification =
    //     FlutterLanguageIdentification();

    WebSocket.connect('wss://irc-ws.chat.twitch.tv:443').then((ws) {
      // await flutterTts.setSharedInstance(true);

      var channel = IOWebSocketChannel(ws);
      setState(() {
        this.streamState = true;
        this.streamSocket = ws;
        this.manualStop = false;
      });

      channel.stream.handleError((error) {
        print('error' + error);
        this.messages.insert(0, 'ERROR: ' + error.toString());
      });

      // ignore: cancel_subscriptions
      var subsc = channel.stream.listen((msg) {});

      subsc.onError((handleError) {
        print('error' + handleError.toString());
        this.messages.insert(0, 'ERROR: ' + handleError.toString());
      });

      subsc.onData((message) async {
        print(message);
        var msg = message.replaceAll('\r\n', '');
        RegExp exp = new RegExp(r'^(:[^ ]+ )?([^ ]+) (.*)$');
        var match = exp.firstMatch(msg);
        if (match != null) {
          var name = match.group(1);
          var command = match.group(2);
          var body = match.group(3);

          switch (command) {
            case 'PRIVMSG':
              // tts Speed
              final SharedPreferences prefs =
                  await SharedPreferences.getInstance();
              final ttsSpeed = prefs.getDouble('ttsSpeed') ?? 0.6;
              await flutterTts.setSpeechRate(ttsSpeed);

              RegExp exp2 = new RegExp(r'^:([^ ]+)\!');
              RegExp exp3 = new RegExp(r':(.+)');
              var match2 = exp2.firstMatch(name);
              var match3 = exp3.firstMatch(body);
              if (match2 != null && match3 != null) {
                name = match2.group(1);
                msg = match3.group(1);

                await flutterTts
                    .setLanguage(prefs.getString('languageChoice') ?? 'ja-JP');
                // await languageIdentification.identifyLanguage(msg);

                // languageIdentification.setSuccessHandler((message) {
                //   print(message);
                // });

                // languageIdentification.setErrorHandler((message) {
                //   print(message);
                // });

                // languageIdentification.setFailedHandler((message) {
                //   print(message);
                // });

                // await flutterTts.setLanguage(langIDResult);
                setState(() {
                  this.messages.insert(0, name + ': ' + msg);
                });
                // print(name);
                // print(msg);
                flutterTts.speak(name + msg);
                // if (result == 1) setState(() => ttsState = TtsState.playing);
              }
              break;
            default:
          }
        }
      });

      subsc.onDone(() {
        print('done');
        if (this.manualStop) return;
        print('try to recco');
        setState(() {
          this.streamState = false;
        });
        _irc();
      });

      channel.sink.add('PASS oauth:' + _accessToken);
      channel.sink.add('NICK bot');
      channel.sink.add('JOIN #' + this._targetChannelController.text);

      setState(() {
        this.messages.insert(0, 'SYSTEM INFO: JOINED '+ this._targetChannelController.text);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Container(
          padding: const EdgeInsets.all(20),
          child: Column(children: <Widget>[
            Expanded(
              child: _accessToken == ''
                  ? WebView(
                      initialUrl:
                          "https://id.twitch.tv/oauth2/authorize?client_id=220do23kc8h2t9ig63rj9fg6zmn93k&redirect_uri=https://www.bluemoon.works/twitchtts/&response_type=token&scope=chat:read%20chat:edit",
                      javascriptMode: JavascriptMode.unrestricted,
                      onPageFinished: (String url) {
                        print('Page finished loading: $url');
                        if (url.startsWith('https://www.bluemoon.works/')) {
                          var startIdx = url.indexOf('=');
                          var endIdx = url.indexOf('&');
                          setState(() {
                            _accessToken = url.substring(startIdx + 1, endIdx);
                          });
                        }
                      },
                    )
                  : StreamBuilder(
                      stream: this.streamController.stream,
                      builder: (BuildContext context,
                          AsyncSnapshot<dynamic> snapShot) {
                        if (snapShot.hasData) {
                          return ListView.builder(
                            itemCount: snapShot.data.length,
                            itemBuilder: (BuildContext context, int index) {
                              return Card(
                                  child: ListTile(
                                onTap: () {},
                                title: Text(snapShot.data[index]),
                                subtitle: Text(_targetChannelController.text),
                              ));
                            },
                          );
                        } else {
                          return Text('No data');
                        }
                      },
                    ),
            ),
            this.streamState
                ? Container()
                : TextField(
                    controller: _targetChannelController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'TARGET CHANNEL',
                    ),
                  ),
          ]),
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            FloatingActionButton(
                heroTag: 'config',
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ConfigPage(),
                      ));
                },
                tooltip: 'config',
                child: Icon(Icons.settings)),
            Padding(
              padding: EdgeInsets.all(14),
              child: Container(color: Colors.red),
            ),
            this.streamState
                ? FloatingActionButton(
                    onPressed: _streamClose,
                    tooltip: 'stop',
                    child: Icon(Icons.stop_circle))
                : FloatingActionButton(
                    onPressed: _irc,
                    tooltip: 'play',
                    child: Icon(Icons.play_arrow),
                    // child: Icon(Icons.stop),
                  ), // This trailing comma makes auto-formatting nicer for build methods.
          ],
        ));
  }
}
