import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
// import 'package:flutter_language_identification/flutter_language_identification.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:twitch_tts/configPage.dart';
import 'package:web_socket_channel/io.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:admob_flutter/admob_flutter.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';
import 'package:carousel_slider/carousel_slider.dart';

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
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
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

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  String _accessToken = '';
  StreamController streamController;
  List<String> messages = [];
  TextEditingController _targetChannelController = TextEditingController();
  bool streamState = false;
  bool manualStop = false;
  WebSocket streamSocket;
  FlutterTts flutterTts;
  bool _disableAd = false;
  bool _disableSelfAd = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsFlutterBinding.ensureInitialized();
    Admob.initialize();
    flutterTts = FlutterTts();
    setConfigValue();
    if (Platform.isAndroid) WebView.platform = SurfaceAndroidWebView();
    if (Platform.isIOS) _iOSSetUp();
    setState(() {
      this.streamController = StreamController();
    });
    this.streamController.sink.add(this.messages);
  }

  void setConfigValue() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      this._disableAd = prefs.getBool('disableAd') ?? false;
      this._disableSelfAd = prefs.getBool('disableSelfAd') ?? false;
    });
  }

  Future<Map<String, dynamic>> adInitialize() async {
    final url = Uri.http('azumag.github.io', '/ad.json');
    var response = await http.get(url);
    return Future.value(json.decode(response.body));
  }

  void _iOSSetUp() async {
    await Admob.requestTrackingAuthorization();

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
    // await flutterTts.awaitSpeakCompletion(true);
    if (Platform.isAndroid) {
      await flutterTts.setQueueMode(1);
    }
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
              final SharedPreferences prefs =
                  await SharedPreferences.getInstance();
              final ttsSpeed = prefs.getDouble('ttsSpeed') ?? 0.6;
              print(ttsSpeed);
              if (Platform.isIOS) {
                await flutterTts.setSpeechRate(ttsSpeed);
              } else {
                flutterTts.setSpeechRate(ttsSpeed);
              }

              RegExp exp2 = new RegExp(r'^:([^ ]+)\!');
              RegExp exp3 = new RegExp(r':(.+)');
              var match2 = exp2.firstMatch(name);
              var match3 = exp3.firstMatch(body);
              if (match2 != null && match3 != null) {
                name = match2.group(1);
                msg = match3.group(1);

                if (Platform.isIOS) {
                  await flutterTts.setLanguage(
                      prefs.getString('languageChoice') ?? 'ja-JP');
                }
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
                flutterTts.speak(name + msg);
                print(msg);
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
        this.messages.insert(
            0, 'SYSTEM INFO: JOINED ' + this._targetChannelController.text);
      });
    });
  }

  String getBannerAdUnitId() {
    if (Platform.isIOS) {
      // return 'ca-app-pub-4857445195385762/4153361605';
      return 'ca-app-pub-3940256099942544/2934735716'; // test
    } else if (Platform.isAndroid) {
      // return 'ca-app-pub-4857445195385762/2461554721';
      return 'ca-app-pub-3940256099942544/6300978111'; // test
    }
    return null;
  }

  void handleAdEvent(
      AdmobAdEvent event, Map<String, dynamic> args, String adType) {
    switch (event) {
      case AdmobAdEvent.loaded:
        print('New Admob $adType Ad loaded!');
        break;
      case AdmobAdEvent.opened:
        print('Admob $adType Ad opened!');
        break;
      case AdmobAdEvent.closed:
        print('Admob $adType Ad closed!');
        break;
      case AdmobAdEvent.failedToLoad:
        print('Admob $adType failed to load. :(');
        break;
      case AdmobAdEvent.rewarded:
        print('rewarded');
        break;
      default:
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('state = $state');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Container(
          padding: const EdgeInsets.all(10),
          child: Column(children: <Widget>[
            FutureBuilder(
                future: adInitialize(),
                builder: (BuildContext context,
                    AsyncSnapshot<Map<String, dynamic>> snapshot) {
                  if (snapshot.hasData) {
                    if (snapshot.data['ads'].length == 1) {
                      final info = snapshot.data['ads'][0];
                      return GestureDetector(
                          onTap: () {
                            launch(info['uri']);
                          },
                          child: this._disableSelfAd
                              ? Container()
                              : Image(image: NetworkImage(info['imgURL'])));
                    } else {
                      return this._disableSelfAd
                          ? Container()
                          : CarouselSlider(
                              options: CarouselOptions(
                                  autoPlay: true,
                                  height: 64,
                                  autoPlayInterval: Duration(seconds: 60)),
                              items: snapshot.data['ads']
                                  .map((info) {
                                    return Builder(
                                      builder: (context) {
                                        return Container(
                                            width: MediaQuery.of(context)
                                                .size
                                                .width,
                                            margin: EdgeInsets.symmetric(
                                                horizontal: 5.0),
                                            decoration: BoxDecoration(
                                                color: Colors.transparent),
                                            child: GestureDetector(
                                                onTap: () {
                                                  launch(info['uri']);
                                                },
                                                child: Image(
                                                    image: NetworkImage(
                                                        info['imgURL']))));
                                      },
                                    );
                                  })
                                  .toList()
                                  .cast<Widget>());
                    }
                  } else {
                    return Text('loading');
                  }
                }),
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
            this._disableAd
                ? Container()
                : AdmobBanner(
                    adUnitId: getBannerAdUnitId(),
                    adSize: AdmobBannerSize.BANNER,
                    listener: (AdmobAdEvent event, Map<String, dynamic> args) {
                      handleAdEvent(event, args, 'Banner');
                    },
                    onBannerCreated: (AdmobBannerController controller) {
                      // Dispose is called automatically for you when Flutter removes the banner from the widget tree.
                      // Normally you don't need to worry about disposing this yourself, it's handled.
                      // If you need direct access to dispose, this is your guy!
                      // controller.dispose();
                    }),
            Padding(padding: EdgeInsets.all(5)),
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
                onPressed: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ConfigPage(),
                      ));
                  // print(result);
                  final SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  setState(() {
                    this._disableAd = prefs.getBool('disableAd') ?? false;
                    this._disableSelfAd =
                        prefs.getBool('disableSelfAd') ?? false;
                  });
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
                  ),
            Padding(
                padding: EdgeInsets.all(40),
                child: Container(color: Colors.red))
          ],
        ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
