import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:screen/screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<List<Nft>> fetchNfts(String address,Settings sett) async {
  final _authority = "api.opensea.io";
  final _path = "/api/v1/assets";
  final _params = { "owner" : address };
  final _uri =  Uri.https(_authority, _path, _params);
  final response = await http.get(_uri);

  if (response.statusCode == 200) {
    // If the server did return a 200 OK response,
    // then parse the JSON.
    List<Nft> nfts = [];
    Map<String, dynamic> jsonMap = jsonDecode(response.body);
    List<dynamic> assets = jsonMap["assets"];
    assets.forEach((asset) {
      nfts.add(Nft.fromJson(asset));
    });
    return nfts;
  } else {
    // If the server did not return a 200 OK response,
    // then throw an exception.
    sett.setWallet(null);
    throw Exception('Wallet not found');
  }
}

String parseTraits(List data) {
  String traits = "";
  for(var i = 0; i < data.length; i++){
    if(i!=0){traits += " ,";}
    traits += data[i]["value"].toString();
  }
  return traits;
}

class Settings{
  String wallet = '';
  bool showTitle = true;
  bool showOwner = true;
  bool showPrice = true;
  bool showTraits = true;
  bool showQrcode = true;
  bool showArtist = true;
  int imgDuration = 10000;

  Settings({this.wallet = '0x5fcf4f5cd39bb519b142d3d4541f67bbe056bc81', this.showArtist = true, this.imgDuration = 10000,this.showTitle = true, this.showOwner = true, this.showTraits = true, this.showPrice = true, this.showQrcode = true});

  void loadAll(){
    SharedPreferences.getInstance().then((prefs) =>{
      this.wallet = prefs.getString("wallet") ?? '',
      this.showArtist = prefs.getBool("showArtist") ?? '',
      this.showTitle = prefs.getBool("showTitle") ?? '',
      this.showTraits = prefs.getBool("showTraits") ?? '',
      this.showOwner = prefs.getBool("showOwner") ?? '',
      this.showPrice = prefs.getBool("showPrice") ?? '',
      this.showQrcode = prefs.getBool("showQrcode") ?? '',
      this.imgDuration = prefs.getBool("imgDuration") ?? '',
      print(this.wallet)});
  }

  Future<String> getWallet() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString("wallet") ?? '0x5fcf4f5cd39bb519b142d3d4541f67bbe056bc81';
  }
  Future<bool> setWallet(String value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString("wallet", value);
  }

  Future<bool> getShowTitle() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool("showTitle") ?? true;
  }
  Future<bool> setShowTitle(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setBool("showTitle", value);
  }

  Future<bool> getShowOwner() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool("showOwner") ?? true;
  }
  Future<bool> setShowOwner(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setBool("showOwner", value);
  }

  Future<bool> getShowPrice() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool("showPrice") ?? true;
  }
  Future<bool> setShowPrice(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setBool("showPrice", value);
  }

  Future<bool> getShowTraits() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool("showTraits") ?? true;
  }
  Future<bool> setShowTraits(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setBool("showTraits", value);
  }

  Future<bool> getShowQrcode() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool("showQrcode") ?? true;
  }
  Future<bool> setShowQrcode(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setBool("showQrcode", value);
  }

  Future<bool> getShowArtist() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool("showArtist") ?? true;
  }
  Future<bool> setShowArtist(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setBool("showArtist", value);
  }

  Future<bool> getImgDuration() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt("imgDuration") ?? true;
  }
  Future<bool> setImgDuration(int value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setInt("imgDuration", value);
  }

}

class Nft {
  final int id;
  final String name;
  final String owner;
  final String traits;
  final String qr;
  final String lastSale;
  final String animUrl;
  final String imgUrl;
  final String thumbUrl;
  final String type;
  final String artist;
  bool enabled;

  Nft({this.id, this.name,this.artist, this.owner, this.traits, this.qr, this.lastSale, this.animUrl, this.imgUrl, this.thumbUrl, this.type, this.enabled});

  factory Nft.fromJson(Map<String, dynamic> json) {
    String tempOwner = '';
    String tempCreator = '';
    String tempLastSale = '';
    String type = 'animated';
    String imgUrl = '';

    if(json['animation_original_url'] == null){type = "image";}

    if(json['image_original_url'] == null){imgUrl = json['image_url'];}else{imgUrl = json['image_original_url'];}

    if(json['owner'] != null) {
      if(json['owner']['user']!=null){
        tempOwner = json['owner']['user']['username'];}else{tempOwner='no username';}
    }else{tempOwner='no username';}

    if(json['creator'] != null) {
      if(json['creator']['user']!=null){tempCreator = json['creator']['user']['username'];}else{tempCreator='no artist name';}
    }else{tempCreator = 'no artist name';}

    if(json['last_sale']!=null){tempLastSale = json['last_sale']['payment_token']['usd_price'].toString();}else{tempLastSale='no last sale';}

    return Nft(
      id: json['id'],
      name: json['name']??'',
      owner: tempOwner,
      artist: tempCreator.toString(),
      traits: parseTraits(json['traits']),
      qr: json['permalink']??'',
      lastSale: tempLastSale.toString().split(".")[0],
      animUrl: json['animation_original_url']??'',
      imgUrl: imgUrl,
      thumbUrl: json['image_thumbnail_url']??'',
      type: type,
      enabled: true,
    );
  }
}

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  MyApp({Key key}) : super(key: key);
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NFTV',
      theme: ThemeData(
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.black),
          hintStyle: TextStyle(color: Colors.grey),
        ),
        fontFamily: 'Roboto',
        primarySwatch: MyColors.salmon,
        iconTheme: IconThemeData(color: Colors.white),
        primaryTextTheme: TextTheme(
          headline6: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w300,
          ),
        ),
      ),
      home: MyHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}
class MyColors {
  static const MaterialColor salmon = MaterialColor(
    0xFFFF8A65,
    <int, Color>{
      50: Color(0xFFFF8A65),
      100: Color(0xFFFF8A65),
      200: Color(0xFFFF8A65),
      300: Color(0xFFFF8A65),
      400: Color(0xFFFF8A65),
      500: Color(0xFFFF8A65),
      600: Color(0xFFFF8A65),
      700: Color(0xFFFF8A65),
      800: Color(0xFFFF8A65),
      900: Color(0xFFFF8A65),
    },
  );
}
class MyHome extends StatefulWidget {
  MyHome({Key key}) : super(key: key);
  @override
  _MyHomeState createState() => _MyHomeState();
}
class _MyHomeState extends State<MyHome> {
  Future<List<Nft>> futureNfts;
  Settings sett;
  bool showTitle = true;
  bool showOwner = true;
  bool showPrice = true;
  bool showTraits = true;
  bool showQrcode = true;
  bool showArtist = true;
  List <bool> enabled;
  TextEditingController _controller;
  TextEditingController _imgholdctrl;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  void _openEndDrawer() {
    _scaffoldKey.currentState.openEndDrawer();
  }

  void _closeEndDrawer() {
    Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    sett = new Settings();
    sett.getWallet().then((value) => {
      _controller = new TextEditingController(text: value),
      futureNfts = fetchNfts(value, sett),
      print("loaded old wallet:"),
      print(value),
      sett.loadAll(),
      setState(() {}),
    });
  }
  @override
  Widget build(BuildContext context) {
    double width=MediaQuery.of(context).size.width;
    int widthCard= 300;
    int countRow=width~/widthCard;
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text('NFTV'),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.grey,
      floatingActionButton: FutureBuilder<List<Nft>>(
        future: futureNfts,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return FloatingActionButton(
              tooltip: "Display NFTs",
              onPressed: () {
                // Add your onPressed code here!
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => MyPlay(nfts: snapshot.data, sett: sett,)),
                );
              },
              child: Icon(Icons.play_arrow),
              foregroundColor: Colors.white,
            );
          }
          else if (snapshot.hasError) {
            return Text("${snapshot.error}");
          }
          // By default, show a loading spinner.
          return CircularProgressIndicator();
        }
      ),
      body:
      DefaultTextStyle(
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w300,),
        child: Column(
        children: <Widget>[
          Container(color: Colors.grey[400].withOpacity(0.2), child:Padding(padding: EdgeInsets.all(10.0), child:
            Theme(
              data: new ThemeData(
                primaryColor: Colors.white,
                primaryColorDark: Colors.white,
              ),
              child:
                TextField(
                    style: TextStyle(color: Colors.white),
                    controller: _controller,
                    onChanged: (text) {
                      sett.wallet = text;
                      sett.setWallet(text);
                      futureNfts = fetchNfts(text, sett);
                      print(sett.wallet);
                      sett.getWallet().then((value) => print(value));
                      setState(() {});
                    },
                    decoration: InputDecoration(
                          enabledBorder: const OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white,),
                          ),
                          border: OutlineInputBorder(),
                          labelText: 'NFT wallet address',
                          labelStyle: TextStyle(color:Colors.white),
                          hintStyle: TextStyle(color: Colors.white),
                        ),
                    ),
                  ),
            ),
          ),
          Expanded(child: Center(
          child:
          FutureBuilder<List<Nft>>(
            future: futureNfts,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: countRow,
                      crossAxisSpacing: 5.0,
                      mainAxisSpacing: 5.0,
                    ),
                    itemBuilder: (BuildContext context, int index) {
                    return Padding(
                        padding: const EdgeInsets.only(
                            top: 15, bottom: 15, left: 15, right: 15),
                        child: Container(width:1, child:Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Expanded(child:Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(children: <Widget>[
                                  Switch(
                                    value: snapshot.data[index].enabled,
                                    onChanged: (value){
                                      setState(() {
                                        snapshot.data[index].enabled = value;
                                      });
                                    },
                                  ),
                                  Expanded(child:Stack(children: [
                                      Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                              if(sett.showTitle == true)Text(
                                                snapshot.data[index].name,
                                                style: TextStyle(
                                                    fontSize: 18,
                                                    height: 1.5),
                                              ),
                                              if(sett.showArtist == true)Text(
                                              "artist: " + snapshot.data[index].artist,
                                              style: TextStyle(
                                                  fontSize: 12),
                                               ),
                                              if(sett.showOwner == true)Text(
                                                "owner: " + snapshot.data[index].owner,
                                                style: TextStyle(
                                                    fontSize: 12),
                                              ),
                                              if(sett.showPrice == true)Text(
                                                "last sale: " + snapshot.data[index].lastSale.toString(),
                                                style: TextStyle(
                                                    fontSize: 12),
                                              ),
                                              if(sett.showTraits == true)Text(
                                                  "traits: " + snapshot.data[index].traits,
                                                  style: TextStyle(
                                                      fontSize: 12),
                                                ),
                                      ]),
                                      if(sett.showQrcode == true)
                                        Positioned(
                                            top: 0,
                                            right: 0,
                                            child:
                                                Image.network("https://api.qrserver.com/v1/create-qr-code/?bgcolor=999999&size=100x100&data="+snapshot.data[index].qr,
                                                width: 50,height: 50,)
                                            ),
                                    ]),),
                                ]),
                                Expanded(child:Padding(padding: const EdgeInsets.only(top: 10, bottom: 10, left: 0, right: 0)
                                      ,child:Center(child:Image.network(snapshot.data[index].thumbUrl)),),),
                              ],
                            ),
                            ),
                          ],
                        ),
                        ),
                    );
                  },
                  itemCount: snapshot.data == null ? 0 : snapshot.data.length,
                );
              } else if (snapshot.hasError) {
                return Text("${snapshot.error}");
              }

              // By default, show a loading spinner.
              return CircularProgressIndicator();
            },
          ),
        ),
    ),
    ]),),
      endDrawer: Container(
      width: 300,
      child: Drawer(
        child: SafeArea(child:Container(
          color: Colors.grey,
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Column(
                children: <Widget>[
                  Text("Settings",
                    style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w300,
                      fontSize: 22),
                  ),
                  SwitchListTile(
                    title: Text('Show Artist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w300)),
                    value: sett.showArtist,
                    onChanged: (value){
                      setState(() {
                        sett.showArtist = value;
                        sett.setShowArtist(value);
                        print(sett.showArtist);
                      });
                    },
                  ),
                  SwitchListTile(
                    title: Text('Show Owner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w300)),
                    value: sett.showOwner,
                    onChanged: (value){
                      setState(() {
                        sett.showOwner = value;
                        sett.setShowOwner(value);
                        print(sett.showOwner);
                      });
                    },
                  ),
                  SwitchListTile(
                    title: Text('Show Price', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w300)),
                    value: sett.showPrice,
                    onChanged: (value){
                      setState(() {
                        sett.showPrice = value;
                        sett.setShowPrice(value);
                        print(sett.showPrice);
                      });
                    },
                  ),
                  SwitchListTile(
                    title: Text('Show QR code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w300)),
                    value: sett.showQrcode,
                    onChanged: (value){
                      setState(() {
                        sett.showQrcode = value;
                        sett.setShowQrcode(value);
                        print(sett.showQrcode);
                      });
                    },
                  ),
                  SwitchListTile(
                    title: Text('Show Title', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w300)),
                    value: sett.showTitle,
                    onChanged: (value){
                      setState(() {
                        sett.showTitle = value;
                        sett.setShowTitle(value);
                        print(sett.showTitle);
                      });
                    },
                  ),
                  SwitchListTile(
                    title: Text('Show Traits', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w300)),
                    value: sett.showTraits,
                    onChanged: (value){
                      setState(() {
                        sett.showTraits = value;
                        sett.setShowTraits(value);
                        print(sett.showTraits);
                      });
                    },
                  ),
                  Padding(padding: const EdgeInsets.only(top: 15, bottom: 15, left: 15, right: 15),child:TextField(
                    style: TextStyle(color: Colors.white),
                    controller: TextEditingController()..text = sett.imgDuration.toString(),
                    decoration: InputDecoration(
                      enabledBorder: const OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white,),
                      ),
                      border: OutlineInputBorder(),
                      labelText: 'Image Hold Duration',
                      labelStyle: TextStyle(color:Colors.white),
                      hintStyle: TextStyle(color: Colors.white),
                    ),
                    onChanged: (text) {
                      setState(() {
                        sett.imgDuration = int.parse(text);
                        sett.setImgDuration(int.parse(text));
                        print(sett.imgDuration);
                      });
                    },
                  ),),
                  ElevatedButton(
                    onPressed: (){ _closeEndDrawer();},
                    child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w300)),
                  ),
                ],

            ),
          ),
        ),),
      ),
      ),
    );
  }
}
class MyPlay extends StatefulWidget {
  final List<Nft> nfts;
  final Settings sett;
  MyPlay({Key key, @required this.nfts,@required this.sett}) : super(key: key);
  @override
  _MyPlayState createState() => _MyPlayState();
}
class _MyPlayState extends State<MyPlay> {
  VideoPlayerController _controller;
  Future<void> _initializeVideoPlayerFuture;
  bool showTitle = true;
  bool showOwner = true;
  bool showPrice = true;
  bool showTraits = true;
  bool showQrcode = true;
  bool showArtist = true;
  List <bool> enabled;

  var index = -1;
  var _disposed = false;
  var _isFullScreen = false;
  var _isEndOfClip = false;
  var _progress = 0.0;
  var _showingDialog = false;
  Timer _timerVisibleControl;
  double _controlAlpha = 1.0;

  var _playing = false;
  bool get _isPlaying {
    return _playing;
  }

  set _isPlaying(bool value) {
    _playing = value;
    _timerVisibleControl?.cancel();
    if (value) {
      _timerVisibleControl = Timer(Duration(seconds: 2), () {
        if (_disposed) return;
        setState(() {
          _controlAlpha = 0.0;
        });
      });
    } else {
      _timerVisibleControl = Timer(Duration(milliseconds: 200), () {
        if (_disposed) return;
        setState(() {
          _controlAlpha = 1.0;
        });
      });
    }
  }

  void _onTapVideo() {
    print("_onTapVideo $_controlAlpha");
    _toggleFullscreen();
    setState(() {
      _controlAlpha = _controlAlpha > 0 ? 0 : 1;
    });
    _timerVisibleControl?.cancel();
    _timerVisibleControl = Timer(Duration(seconds: 2), () {
      if (_isPlaying) {
        setState(() {
          _controlAlpha = 0.0;
        });
      }
    });
  }

  @override
  void initState() {
    Screen.keepOn(true);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    index = 0;
    while(widget.nfts[index].enabled == false) {
      index++;
      print("skipped disabled nft");
      if(index >= widget.nfts.length){
        print("loop end");
        index =0;
      }
    }
    print("startig "+ widget.nfts[index].type +" "+ index.toString() + " " + widget.nfts[index].imgUrl);
    _initializeAndPlay();
    _enterFullScreen();
    super.initState();
    //widget.nfts[0].animUrl
  }

  @override
  void dispose() {
    _disposed = true;
    _timerVisibleControl?.cancel();
    Screen.keepOn(false);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _exitFullScreen();
    _controller?.pause(); // mute instantly
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  void _toggleFullscreen() async {
    if (_isFullScreen) {
      _exitFullScreen();
    } else {
      _enterFullScreen();
    }
  }

  void _enterFullScreen() async {
    print("enterFullScreen");
    await SystemChrome.setEnabledSystemUIOverlays([]);
    if (_disposed) return;
    setState(() {
      _isFullScreen = true;
    });
  }

  void _exitFullScreen() async {
    print("exitFullScreen");
    await SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
    if (_disposed) return;
    setState(() {
      _isFullScreen = false;
    });
  }

  void _initializeAndPlay() async {
    print("_initializeAndPlay ---------> $index");
    if(index >= widget.nfts.length){index = 0;}
    print(widget.nfts[index].type);
    if(widget.nfts[index].type=="animated") {
      final clip = widget.nfts[index].animUrl;
      final controller = VideoPlayerController.network(clip);
      print("making new anim controller");
      final old = _controller;
      _controller = controller;
      if (old != null) {
        old.removeListener(_onControllerUpdated);
        old.pause();
        print("---- old contoller paused.");
      }
      print("---- controller changed.");
      setState(() {});

      controller
        ..initialize().then((_) {
          print("---- controller initialized");
          old?.dispose();
          _duration = null;
          _position = null;
          controller.addListener(_onControllerUpdated);
          controller.play();
          setState(() {});
        });
    }
    else if(widget.nfts[index].type=="image"){
      final old = _controller;
      if (old != null) {
        old.removeListener(_onControllerUpdated);
        old.pause();
        print("---- old contoller paused.");
      }
      print("---- starting image with timer");
      print("image:");
      print(widget.nfts[index].imgUrl);

      Future.delayed(Duration(milliseconds: widget.sett.imgDuration), () {
        if (_disposed) return;
        index += 1;
        if(index >= widget.nfts.length){index = 0;}
        print("timer finishes, switching art");
        while(widget.nfts[index].enabled == false) {
          index++;
          print("skipped disabled nft");
          if (index >= widget.nfts.length) {
            print("loop end");
            index = 0;
          }
        }
          print("startig "+ widget.nfts[index].type +" "+ index.toString() + " " + widget.nfts[index].imgUrl);
          _initializeAndPlay();
        setState(() {});
      });
    }
  }

  var _updateProgressInterval = 0.0;
  Duration _duration;
  Duration _position;

  void _onControllerUpdated() async {
    if (_disposed) return;
    // blocking too many updation
    // important !!
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_updateProgressInterval > now) {
      return;
    }
    _updateProgressInterval = now + 500.0;

    final controller = _controller;
    if (controller == null) return;
    if (!controller.value.initialized) return;
    if (_duration == null) {
      _duration = _controller.value.duration;
    }
    var duration = _duration;
    if (duration == null) return;

    var position = await controller.position;
    _position = position;
    final playing = controller.value.isPlaying;
    final isEndOfClip = position.inMilliseconds > 0 && position.inSeconds + 1 >= duration.inSeconds;
    if (playing) {
      // handle progress indicator
      if (_disposed) return;
      setState(() {
        _progress = position.inMilliseconds.ceilToDouble() / duration.inMilliseconds.ceilToDouble();
      });
    }

    // handle clip end
    if (_isPlaying != playing || _isEndOfClip != isEndOfClip) {
      _isPlaying = playing;
      _isEndOfClip = isEndOfClip;
      print("updated -----> isPlaying=$playing / isEndOfClip=$isEndOfClip");
      if (isEndOfClip) {
        print("========================== End of Clip / Handle NEXT ========================== ");
        final isComplete = index == widget.nfts.length - 1;
        if (isComplete) {
          print("played all!!");
          index = 0;
          while(widget.nfts[index].enabled == false) {
            index++;
            print("skipped disabled nft");
            if(index >= widget.nfts.length){
              print("no enabled NFTS");
              index = 0;
            }
          }
          print("startig "+ widget.nfts[index].type +" "+ index.toString() + " " + widget.nfts[index].imgUrl);
          _initializeAndPlay();
        } else {
          index = index + 1;
          while(widget.nfts[index].enabled == false) {
             index++;
             print("skipped disabled nft");
             if(index >= widget.nfts.length){
               print("loop end");
               index = 0;
             }
          }
          print("startig "+ widget.nfts[index].type +" "+ index.toString() + " " + widget.nfts[index].imgUrl);
          _initializeAndPlay();
        }
      }
    }
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _isFullScreen
          ? null
          : AppBar(
        title: Text("NFTV"),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isFullScreen
          ? Container(
        child: Center(child: _playView(context)),
      )
          : Container(
                child: Center(child: _playView(context)),
            ),
    );
  }

  void _onTapCard(int index) {
    print("startig "+ widget.nfts[index].type +" "+ index.toString() + " " + widget.nfts[index].imgUrl);
    _initializeAndPlay();
  }

  Widget _playView(BuildContext context) {
    bool loaded = false;
    final controller = _controller;
    if(widget.nfts[index].type == "image"){loaded = true;}
    else if(widget.nfts[index].type == "animated"){
      if(controller != null && controller.value.initialized) {
        loaded = true;
      }
    }

    if (loaded) {
      return
      DefaultTextStyle(
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w300,),
      child: Stack(children: <Widget>[
      if(widget.nfts[index].type == "animated")
      Center(
          child:
          AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: Center(child:Stack(
              children: <Widget>[
                GestureDetector(
                  child: Center(child:VideoPlayer(controller)),
                  onTap: _onTapVideo,
                ),
              ],
            ),),
          )
      ),
      if(widget.nfts[index].type == "image")
      Center(
              child:Stack(
                children: <Widget>[
                  GestureDetector(
                  child:Image.network(widget.nfts[index].imgUrl.toString(),
                      key: ValueKey(widget.nfts[index].imgUrl.toString())),
                  onTap: _onTapVideo,
                )
                ]
              )
      ),
      Padding(padding: EdgeInsets.all(16.0),child:Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if(widget.sett.showTitle == true)Text(
                widget.nfts[index].name,
                style: TextStyle(
                    fontSize: 18,
                    height: 1.5),
              ),
              if(widget.sett.showArtist == true)Text(
                "artist: " + widget.nfts[index].artist,
                style: TextStyle(
                    fontSize: 12),
              ),
              if(widget.sett.showOwner == true)Text(
                "owner: " + widget.nfts[index].owner,
                style: TextStyle(
                    fontSize: 12),
              ),
              if(widget.sett.showPrice == true)Text(
                "last sale: " + widget.nfts[index].lastSale.toString(),
                style: TextStyle(
                    fontSize: 12),
              ),
              if(widget.sett.showTraits == true)Text(
                "traits: " + widget.nfts[index].traits,
                style: TextStyle(
                    fontSize: 12),
              ),
            ]),),
          if(widget.sett.showQrcode == true)
          Positioned(
          top: 0,
          right: 0,
          child:Padding(padding: EdgeInsets.all(16.0),child:
          Image.network("https://api.qrserver.com/v1/create-qr-code/?bgcolor=999999&size=100x100&data="+widget.nfts[index].qr,
            width: 80,height: 80,)
        ),),
      ],
      ),
      );
    } else {
      //return Center(child: CircularProgressIndicator());
    }
  }
}