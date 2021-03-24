import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_strategy/url_strategy.dart';
import 'dart:io' show File, Platform;
import 'package:device_info/device_info.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock/wakelock.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path/path.dart' as path;
import 'package:native_video_view/native_video_view.dart';

Future<List<Nft>> fetchNfts(String rawaddress, Settings sett) async {
  List<String> adresses = rawaddress.split("+");
  List<Nft> nfts = [];
  int maxLength = 24;
  try {
    for (String address in adresses) {
      address = address.replaceAll(' ', '');
      if (address.contains("0x")) {
        //opensea request
        final _authority = "api.opensea.io";
        final _path = "/api/v1/assets";
        final _params = {"owner": address};
        final _uri = Uri.https(_authority, _path, _params);
        final response = await http.get(_uri);

        if (response.statusCode == 200) {
          // If the server did return a 200 OK response,
          // then parse the JSON.

          Map<String, dynamic> jsonMap = jsonDecode(utf8.decode(response.bodyBytes));
          List<dynamic> assets = jsonMap["assets"];
          assets.forEach((asset) {
            if (nfts.length < maxLength) {
              nfts.add(Nft.fromJson(asset));
            }
          });
        } else {
          // If the server did not return a 200 OK response,
          // then throw an exception.
          sett.setWallet(null);
          throw Exception('Wallet not found');
        }
      } else {
        //nifty gateway request
        String _authority = '';
        String _path = '';
        Map<String, dynamic> _params = new Map();
        if (kIsWeb) {
          _authority = "us-central1-nftv-306020.cloudfunctions.net";
          _path = "cors";
          _params = {"url": "https://api.niftygateway.com/user/profile-and-offchain-nifties-by-url/?profile_url=" + address};
        } else {
          _authority = "api.niftygateway.com";
          _path = "/user/profile-and-offchain-nifties-by-url";
          _params = {"profile_url": address};
        }
        final _uri = Uri.https(_authority, _path, _params);
        final response = await http.get(_uri);
        if (response.statusCode == 200) {
          // If the server did return a 200 OK response,
          // then parse the JSON.
          Map<String, dynamic> jsonMap = jsonDecode(utf8.decode(response.bodyBytes));
          String owner = address;
          List<dynamic> assets = jsonMap["userProfileAndNifties"]["nifties"];
          assets.forEach((asset) {
            if (nfts.length < maxLength) {
              nfts.add(Nft.fromNiftyJson(asset, owner));
            }
          });
        } else {
          // If the server did not return a 200 OK response,
          // then throw an exception.
          sett.setWallet(null);
          throw Exception('Nifty user not found');
        }
      }
    }
    if (nfts.length > 40) {}
    sett.setNfts(nfts);
    sett.setOnline();
  } on Exception catch (exception) {
    if (exception.toString() == 'Exception: Nifty user not found') {
      throw Exception('Nifty user not found');
    } else if (exception.toString() == 'Exception: Wallet not found') {
      throw Exception('Wallet not found');
    } else {
      nfts = await sett.getNfts();
      if (nfts == null) {
        throw Exception('offline');
      }
      sett.setOffline();
    }
  } catch (error) {
    nfts = await sett.getNfts();
    sett.setOffline();
  }
  return nfts;
}

String parseTraits(List data) {
  String traits = "";
  for (var i = 0; i < data.length; i++) {
    if (i != 0) {
      traits += " ,";
    }
    traits += data[i]["value"].toString();
  }
  return traits;
}

class Settings {
  String wallet = '';
  bool showTitle = true;
  bool showOwner = true;
  bool showPrice = true;
  bool showTraits = true;
  bool showQrcode = true;
  bool showArtist = true;
  bool online = true;
  int imgDuration = 20000;

  Settings({
    this.wallet = '0x5fcf4f5cd39bb519b142d3d4541f67bbe056bc81',
    this.showArtist = true,
    this.imgDuration = 20000,
    this.showTitle = true,
    this.showOwner = true,
    this.showTraits = true,
    this.showPrice = true,
    this.showQrcode = true,
  });

  void loadAll() {
    SharedPreferences.getInstance().then((prefs) => {
          this.wallet = prefs.getString("wallet") ?? '',
          this.showArtist = prefs.getBool("showArtist") ?? true,
          this.showTitle = prefs.getBool("showTitle") ?? true,
          this.showTraits = prefs.getBool("showTraits") ?? true,
          this.showOwner = prefs.getBool("showOwner") ?? true,
          this.showPrice = prefs.getBool("showPrice") ?? true,
          this.showQrcode = prefs.getBool("showQrcode") ?? true,
          this.imgDuration = prefs.getInt("imgDuration") ?? 20000,
        });
  }

  void setOffline() {
    this.online = false;
  }

  void setOnline() {
    this.online = true;
  }

  Future<String> getWallet() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString("wallet") ?? '0x5fcf4f5cd39bb519b142d3d4541f67bbe056bc81';
  }

  Future<bool> setWallet(String value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString("wallet", value);
  }

  Future<List<Nft>> getNfts() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> nftsJson = prefs.getStringList("nfts");
    if (nftsJson != null) {
      return prefs.getStringList("nfts").map((e) => Nft.fromCache(jsonDecode(e))).toList();
    } else {
      return (null);
    }
  }

  Future<bool> setNfts(List<Nft> nfts) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> nftsEncoded = nfts.map((nft) => jsonEncode(nft.toJson())).toList();
    return prefs.setStringList("nfts", nftsEncoded);
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
    return prefs.setInt("imgDuration", value) ?? 20000;
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

  Nft({this.id, this.name, this.artist, this.owner, this.traits, this.qr, this.lastSale, this.animUrl, this.imgUrl, this.thumbUrl, this.type, this.enabled});

  factory Nft.fromJson(Map<String, dynamic> json) {
    String tempOwner = '';
    String tempCreator = '';
    String tempLastSale = '';
    String type = 'animated';
    String imgUrl = '';

    if (json['animation_original_url'] == null) {
      type = "image";
    }

    if (json['image_original_url'] == null) {
      imgUrl = json['image_url'];
    } else {
      imgUrl = json['image_original_url'];
    }

    if (json['owner'] != null) {
      if (json['owner']['user'] != null) {
        tempOwner = json['owner']['user']['username'];
      } else {
        tempOwner = 'no username';
      }
    } else {
      tempOwner = 'no username';
    }

    if (json['creator'] != null) {
      if (json['creator']['user'] != null) {
        tempCreator = json['creator']['user']['username'];
      } else {
        tempCreator = 'Unknown';
      }
    } else {
      tempCreator = 'Unknown';
    }

    if (json['last_sale'] != null) {
      tempLastSale = json['last_sale']['payment_token']['usd_price'].toString();
    } else {
      tempLastSale = 'Unknown';
    }

    return Nft(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      owner: tempOwner,
      artist: tempCreator.toString(),
      traits: parseTraits(json['traits']),
      qr: json['permalink'] ?? '',
      lastSale: tempLastSale.toString().split(".")[0],
      animUrl: json['animation_original_url'] ?? '',
      imgUrl: imgUrl,
      thumbUrl: json['image_thumbnail_url'].toString().replaceAll("=s128", "=s200") ?? '',
      type: type,
      enabled: true,
    );
  }

  factory Nft.fromCache(Map<String, dynamic> json) {
    return Nft(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      owner: json['owner'] ?? '',
      artist: json['artist'] ?? '',
      traits: json['traits'] ?? '',
      qr: json['qr'] ?? '',
      lastSale: json['lastSale'] ?? '',
      animUrl: json['animUrl'] ?? '',
      imgUrl: json['imgUrl'] ?? '',
      thumbUrl: json['thumbUrl'] ?? '',
      type: json['type'] ?? '',
      enabled: json['enabled'] ?? '',
    );
  }

  factory Nft.fromNiftyJson(Map<String, dynamic> json, String owner) {
    String type = 'animated';
    String sdImgUrl = '';
    if (json['image_url'].toString().toLowerCase().contains(".mp4") || json['image_url'].toString().toLowerCase().contains(".mov")) {
      type = 'animated';
      sdImgUrl = json['image_url'].replaceAll('/upload/', '/upload/q_auto:good,w_500/');
    } else {
      type = 'image';
      sdImgUrl = json['image_preview_url'];
    }
    String animUrl = json['image_url'].toString().replaceFirst('upload/', 'upload/q_auto:good,h_2160/');

    return Nft(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      owner: owner,
      artist: json['creator_info']['name'] ?? '',
      traits: json['description'] ?? '',
      qr: json['contractAddress'] ?? '',
      lastSale: "Unknown",
      animUrl: animUrl ?? '',
      imgUrl: json['image_url'] ?? '',
      thumbUrl: sdImgUrl ?? '',
      type: type ?? '',
      enabled: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": this.id,
      "name": this.name,
      "owner": this.owner,
      "artist": this.artist,
      "traits": this.traits,
      "qr": this.qr,
      "lastSale": this.lastSale,
      "animUrl": this.animUrl,
      "imgUrl": this.imgUrl,
      "thumbUrl": this.thumbUrl,
      "type": this.type,
      "enabled": this.enabled,
    };
  }
}

void main() {
  setPathUrlStrategy();
  final String wallet_url = Uri.base.queryParameters["wallet"] ?? '';
  runApp(MyApp(wallet_url: wallet_url));
}

Future<File> getThumbnail(String url) async {
  String filepath = (await getTemporaryDirectory()).path + "/" + path.basenameWithoutExtension(url) + '.jpg';
  if (await File(filepath).exists()) {
    return File(filepath);
  } else {
    return File(await VideoThumbnail.thumbnailFile(video: url, maxWidth: 300, imageFormat: ImageFormat.JPEG, quality: 85, thumbnailPath: (await getTemporaryDirectory()).path));
  }
}

class MyGrid extends StatefulWidget {
  final Future<List<Nft>> nfts;
  final Settings sett;
  final ValueChanged<int> update;

  MyGrid({Key key, this.update, @required this.nfts, @required this.sett}) : super(key: key);

  @override
  _MyGridState createState() => _MyGridState();
}

class _MyGridState extends State<MyGrid> {
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    int widthCard = 300;
    int countRow = width ~/ widthCard;

    String truncate(int cutoff, String myString) {
      return (myString.length <= cutoff) ? myString : '${myString.substring(0, cutoff)}...';
    }

    return (FutureBuilder<List<Nft>>(
      future: widget.nfts,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: countRow,
              crossAxisSpacing: 5.0,
              mainAxisSpacing: 5.0,
            ),
            itemBuilder: (BuildContext context, int index) {
              //Future<File> image = DefaultCacheManager().getSingleFile(snapshot.data[index].imgUrl);
              //Future<File> video = DefaultCacheManager().getSingleFile(snapshot.data[index].animUrl);
              //get thumbnail
              Future<File> thumbnail;
              if (snapshot.data[index].type == "animated") {
                if (kIsWeb) {
                  thumbnail = DefaultCacheManager().getSingleFile(snapshot.data[index].animUrl);
                } else {
                  thumbnail = getThumbnail(snapshot.data[index].animUrl);
                }
              } else {
                thumbnail = DefaultCacheManager().getSingleFile(snapshot.data[index].thumbUrl);
              }
              Future<File> qr = DefaultCacheManager().getSingleFile("https://api.qrserver.com/v1/create-qr-code/?bgcolor=ffffff&size=100x100&data=" + snapshot.data[index].qr);
              return Padding(
                padding: const EdgeInsets.only(top: 15, bottom: 15, left: 15, right: 15),
                child: Container(
                  width: 1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(children: <Widget>[
                              Switch(
                                value: snapshot.data[index].enabled,
                                activeTrackColor: Color(0xFFC4C4C4),
                                inactiveTrackColor: Color(0xFF777777),
                                activeColor: Color(0xFF000000),
                                inactiveThumbColor: Color(0xFFE0E0E0),
                                onChanged: (value) {
                                  widget.update(1);
                                  setState(() {
                                    snapshot.data[index].enabled = value;
                                    widget.sett.setNfts(snapshot.data);
                                  });
                                },
                              ),
                              Expanded(
                                child: Stack(children: [
                                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    if (widget.sett.showTitle == true)
                                      RichText(
                                        text: TextSpan(
                                          text: snapshot.data[index].name,
                                          style: TextStyle(color: Colors.black.withOpacity(0.8), fontSize: 16, height: 1.5, fontFamily: "BigJohnProThin"),
                                        ),
                                      ),
                                    if (widget.sett.showArtist == true)
                                      RichText(
                                        text: TextSpan(
                                          text: 'Artist: '.toUpperCase(),
                                          style: TextStyle(color: Colors.black.withOpacity(0.8), fontSize: 8, fontFamily: "BigJohnPro"),
                                          children: <TextSpan>[
                                            TextSpan(text: snapshot.data[index].artist, style: TextStyle(fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                    if (widget.sett.showOwner == true)
                                      RichText(
                                        text: TextSpan(
                                          text: 'Owner: '.toUpperCase(),
                                          style: TextStyle(color: Colors.black.withOpacity(0.8), fontSize: 8, fontFamily: "BigJohnPro"),
                                          children: <TextSpan>[
                                            TextSpan(text: snapshot.data[index].owner, style: TextStyle(fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                    if (widget.sett.showPrice == true)
                                      RichText(
                                        text: TextSpan(
                                          text: 'Last Sale: '.toUpperCase(),
                                          style: TextStyle(color: Colors.black.withOpacity(0.8), fontSize: 8, fontFamily: "BigJohnPro"),
                                          children: <TextSpan>[
                                            TextSpan(text: snapshot.data[index].lastSale, style: TextStyle(fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                    if (widget.sett.showTraits == true)
                                      RichText(
                                        text: TextSpan(
                                          text: 'Traits: '.toUpperCase(),
                                          style: TextStyle(color: Colors.black.withOpacity(0.8), fontSize: 8, fontFamily: "BigJohnPro"),
                                          children: <TextSpan>[
                                            TextSpan(text: truncate(30, snapshot.data[index].traits), style: TextStyle(fontSize: 10)),
                                          ],
                                        ),
                                      ),
                                  ]),
                                  if (widget.sett.showQrcode == true)
                                    Positioned(
                                        top: 0,
                                        right: 0,
                                        child: FutureBuilder(
                                          future: qr,
                                          builder: (context, snapshotImg) {
                                            if (snapshotImg.hasData) {
                                              return (Container(width: 50.0, height: 50.0, child: Center(child: Image.file(snapshotImg.data, width: 50, height: 50))));
                                            }
                                            return Center(
                                                child: Opacity(
                                              opacity: 0.2,
                                              child: CircularProgressIndicator(),
                                            ));
                                          },
                                        )),
                                ]),
                              ),
                            ]),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => MyDisplay(
                                              nfts: snapshot.data,
                                              start: index,
                                              sett: widget.sett,
                                            )),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 10, bottom: 10, left: 0, right: 0),
                                  child: Center(
                                    child: FutureBuilder(
                                        future: thumbnail,
                                        builder: (context, snapshotImg) {
                                          if (snapshotImg.hasData) {
                                            if (kIsWeb && snapshot.data[index].type == "animated") {
                                              VideoPlayerController _controller = VideoPlayerController.network(snapshot.data[index].animUrl);
                                              Future<void> _initializeVideoPlayerFuture = _controller.initialize();
                                              return FutureBuilder(
                                                  future: _initializeVideoPlayerFuture,
                                                  builder: (context, snapshotvid) {
                                                    if (snapshotvid.connectionState == ConnectionState.done) {
                                                      return (AbsorbPointer(child:VideoPlayer(_controller)));
                                                    }
                                                    return Center(
                                                        child: Opacity(
                                                      opacity: 0.2,
                                                      child: CircularProgressIndicator(),
                                                    ));
                                                  });
                                            } else {
                                              return (Image.file(snapshotImg.data));
                                            }
                                          } else {
                                            return Center(
                                                child: Opacity(
                                              opacity: 0.2,
                                              child: CircularProgressIndicator(),
                                            ));
                                          }
                                        }),
                                  ),
                                ),
                              ),
                            ),
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
          return (CircularProgressIndicator());
        }
        // By default, show a loading spinner.
        return Center(
            child: Opacity(
          opacity: 0.2,
          child: CircularProgressIndicator(),
        ));
      },
    ));
  }
}

class MyApp extends StatefulWidget {
  final String wallet_url;

  MyApp({Key key, @required this.wallet_url}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        },
        child: MaterialApp(
          title: 'NFTV',
          theme: ThemeData(
            inputDecorationTheme: const InputDecorationTheme(
              labelStyle: TextStyle(color: Colors.black),
              hintStyle: TextStyle(color: Colors.grey),
            ),
            fontFamily: 'BigJohnProBold',
            primarySwatch: MyColors.salmon,
            iconTheme: IconThemeData(color: Colors.black),
          ),
          home: MyHome(
            wallet_url: widget.wallet_url,
          ),
          debugShowCheckedModeBanner: false,
        ));
  }
}

class MyColors {
  static const MaterialColor salmon = MaterialColor(
    0xFFCFCFCF,
    <int, Color>{
      50: Color(0xFFCFCFCF),
      100: Color(0xFFCFCFCF),
      200: Color(0xFFCFCFCF),
      300: Color(0xFFCFCFCF),
      400: Color(0xFFCFCFCF),
      500: Color(0xFFCFCFCF),
      600: Color(0xFFCFCFCF),
      700: Color(0xFFCFCFCF),
      800: Color(0xFFCFCFCF),
      900: Color(0xFFCFCFCF),
    },
  );
}

class MyHome extends StatefulWidget {
  final String wallet_url;

  MyHome({Key key, @required this.wallet_url}) : super(key: key);

  @override
  _MyHomeState createState() => _MyHomeState();
}

class _MyHomeState extends State<MyHome> {
  Future<List<Nft>> futureNfts;
  Future<bool> androidTv;
  Settings sett;
  String code;
  bool showTitle = true;
  bool showOwner = true;
  bool showPrice = true;
  bool showTraits = true;
  bool showQrcode = true;
  bool showArtist = true;
  List<bool> enabled;
  TextEditingController _controller;
  TextEditingController imgHldController;
  final ValueNotifier<int> refresh = ValueNotifier<int>(0);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void update(int) {
    setState(() {});
  }

  Future<bool> checkTv() async {
    if (kIsWeb) {
      return false;
    } else if (Platform.isAndroid) {
      AndroidDeviceInfo androidDeviceInfo = await DeviceInfoPlugin().androidInfo;
      return androidDeviceInfo.systemFeatures.contains('android.software.leanback');
    } else {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    const _chars = 'abcdefghijklmnopqrstuvwxyz1234567890';
    Random _rnd = Random();
    int length = 4;
    code = String.fromCharCodes(Iterable.generate(length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));
    androidTv = checkTv();
    sett = new Settings();
    if (widget.wallet_url != '') {
      sett.loadAll();
      sett.wallet = widget.wallet_url;
      sett.setWallet(widget.wallet_url);
      _controller = new TextEditingController(text: widget.wallet_url);
      futureNfts = fetchNfts(widget.wallet_url, sett);
      setState(() {});
    } else {
      sett.getWallet().then((value) => {
            _controller = new TextEditingController(text: value),
            futureNfts = fetchNfts(value, sett),
            sett.loadAll(),
            setState(() {}),
          });
    }
    imgHldController = new TextEditingController(text: (sett.imgDuration ~/ 1000).toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(
          "NFTV",
          style: TextStyle(fontSize: 25, fontFamily: 'BigJohnProThin'),
        ),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        backgroundColor: Color(0xFFEFEFEF),
      ),
      backgroundColor: Color(0xFFEFEFEF),
      floatingActionButton: FutureBuilder<bool>(
          future: androidTv,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              if (snapshot.data == false) {
                return (FutureBuilder<List<Nft>>(
                    future: futureNfts,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return FloatingActionButton(
                          elevation: 0,
                          tooltip: "Display NFTs",
                          onPressed: () {
                            // Add your onPressed code here!
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => MyDisplay(
                                        nfts: snapshot.data,
                                        start: 0,
                                        sett: sett,
                                      )),
                            );
                          },
                          child: Icon(Icons.play_arrow),
                          foregroundColor: Colors.black,
                        );
                      } else if (snapshot.hasError) {
                        //return Text("Error");
                      }
                      // By default, show a loading spinner.
                      return Opacity(
                        opacity: 0.2,
                        child: CircularProgressIndicator(),
                      );
                    }));
              } else {
                return (Container(width: 0.0, height: 0.0));
              }
            }
            return Center(
                child: Opacity(
              opacity: 0.2,
              child: CircularProgressIndicator(),
            ));
          }),
      body: DefaultTextStyle(
        style: TextStyle(
          color: Colors.black,
        ),
        child: FutureBuilder<bool>(
            future: androidTv, // a previously-obtained Future
            builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
              if (snapshot.hasData) {
                if (snapshot.data == true) {
                  try {
                    Future initialized = Firebase.initializeApp();
                    return (FutureBuilder<FirebaseApp>(
                        future: initialized,
                        builder: (BuildContext context, AsyncSnapshot<FirebaseApp> snapshot) {
                          if (snapshot.hasData == true) {
                            DocumentReference inputData = FirebaseFirestore.instance.collection('codes').doc(code);
                            return (StreamBuilder<DocumentSnapshot>(
                                stream: inputData.snapshots(),
                                builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
                                  if (snapshot.hasData) {
                                    if (snapshot.data.data() != null) {
                                      _controller.text = snapshot.data.data()['value'];
                                      sett.wallet = snapshot.data.data()['value'];
                                      sett.setWallet(snapshot.data.data()['value']);
                                      futureNfts = fetchNfts(snapshot.data.data()['value'], sett);
                                    }
                                  }
                                  return (Column(children: <Widget>[
                                    Container(
                                        color: Color(0xFFD7D7D7),
                                        child: Padding(
                                            padding: EdgeInsets.all(10.0),
                                            child: Theme(
                                                data: new ThemeData(
                                                  primaryColor: Colors.black,
                                                  primaryColorDark: Colors.black,
                                                ),
                                                child: Row(children: [
                                                  Expanded(
                                                      child: TextField(
                                                    enabled: false,
                                                    style: TextStyle(color: Colors.black, fontFamily: "BigJohnProThin"),
                                                    controller: _controller,
                                                    decoration: InputDecoration(
                                                      enabledBorder: const OutlineInputBorder(
                                                        borderRadius: BorderRadius.zero,
                                                        borderSide: const BorderSide(
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                      disabledBorder: const OutlineInputBorder(
                                                        borderRadius: BorderRadius.zero,
                                                        borderSide: const BorderSide(
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                      border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                                                      labelText: 'go to nftv.app/$code to connect your NFT wallet',
                                                      hintText: "use + to add multiple",
                                                      labelStyle: TextStyle(color: Colors.black, fontFamily: "BigJohnProThin"),
                                                      hintStyle: TextStyle(color: Colors.black, fontFamily: "BigJohnProThin"),
                                                    ),
                                                  )),
                                                  FutureBuilder<List<Nft>>(
                                                      future: futureNfts,
                                                      builder: (context, snapshot) {
                                                        if (snapshot.hasData) {
                                                          return Padding(
                                                              padding: EdgeInsets.only(left: 10.0),
                                                              child: SizedBox(
                                                                  height: 59,
                                                                  child: ElevatedButton(
                                                                    autofocus: true,
                                                                    style: ElevatedButton.styleFrom(
                                                                        textStyle: TextStyle(fontFamily: "BigJohnProThin"),
                                                                        primary: Colors.black,
                                                                        elevation: 0,
                                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
                                                                    onPressed: () {
                                                                      // Add your onPressed code here!
                                                                      Navigator.push(
                                                                        context,
                                                                        MaterialPageRoute(
                                                                            builder: (context) => MyDisplay(
                                                                                  nfts: snapshot.data,
                                                                                  start: 0,
                                                                                  sett: sett,
                                                                                )),
                                                                      );
                                                                    },
                                                                    child: Row(children: [
                                                                      Icon(Icons.play_arrow),
                                                                      Text(
                                                                        " Start Display".toUpperCase(),
                                                                      )
                                                                    ]),
                                                                  )));
                                                        } else if (snapshot.hasError) {
                                                          return Text("${snapshot.error}");
                                                        }
                                                        // By default, show a loading spinner.
                                                        return Padding(
                                                            padding: EdgeInsets.all(10.0),
                                                            child: SizedBox(
                                                                height: 59,
                                                                child: ElevatedButton(
                                                                  onPressed: null,
                                                                  autofocus: true,
                                                                  style: ElevatedButton.styleFrom(
                                                                      textStyle: TextStyle(fontFamily: "BigJohnProThin"),
                                                                      primary: Colors.white,
                                                                      elevation: 0,
                                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
                                                                  child: Row(children: [
                                                                    Icon(Icons.play_arrow),
                                                                    Text(
                                                                      " Start Display",
                                                                    )
                                                                  ]),
                                                                )));
                                                      }),
                                                ])))),
                                    renderGrid(context)
                                  ]));
                                }));
                          }
                          return Center(
                              child: Opacity(
                            opacity: 0.2,
                            child: CircularProgressIndicator(),
                          ));
                        }));
                  } catch (error) {}
                }
              }
              return (Column(children: <Widget>[
                Container(
                  color: Color(0xFFD7D7D7),
                  child: Padding(
                    padding: EdgeInsets.all(10.0),
                    child: Theme(
                      data: new ThemeData(
                        primaryColor: Colors.black,
                        primaryColorDark: Colors.black,
                      ),
                      child: TextField(
                        style: TextStyle(color: Colors.black, fontFamily: "BigJohnProThin"),
                        controller: _controller,
                        onChanged: (text) {
                          setState(() {
                            futureNfts = fetchNfts(text, sett);
                          });
                        },
                        decoration: InputDecoration(
                            enabledBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: const BorderSide(
                                color: Colors.black,
                              ),
                            ),
                            border: OutlineInputBorder(),
                            labelText: 'NFT wallet address or Nifty Username',
                            hintText: "use + to add multiple".toUpperCase(),
                            labelStyle: TextStyle(color: Colors.black, fontFamily: "BigJohnProThin"),
                            hintStyle: TextStyle(color: Colors.black),
                            suffixIcon: IconButton(
                              onPressed: _controller?.clear,
                              icon: Icon(Icons.clear, color: Colors.black),
                            )),
                      ),
                    ),
                  ),
                ),
                renderGrid(context)
              ]));
            }),
      ),
      endDrawer: Container(
        width: 300,
        color: Color(0xFFFFFFFF),
        child: Drawer(
          elevation: 0,
          child: SafeArea(
            child: Container(
              color: Color(0xFFFFFFFF),
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  children: <Widget>[
                    Text(
                      "SETTINGS",
                      style: TextStyle(color: Colors.black, fontFamily: "BigJohnProThin", fontSize: 22),
                    ),
                    SwitchListTile(
                      title: Text('Show Artist'.toUpperCase(), style: TextStyle(color: Colors.black, fontFamily: "BigJohnProThin")),
                      value: sett.showArtist,
                      activeColor: Colors.black,
                      onChanged: (value) {
                        setState(() {
                          sett.showArtist = value;
                          sett.setShowArtist(value);
                        });
                      },
                    ),
                    SwitchListTile(
                      title: Text('Show Owner'.toUpperCase(), style: TextStyle(color: Colors.black, fontFamily: "BigJohnProThin")),
                      value: sett.showOwner,
                      activeColor: Colors.black,
                      onChanged: (value) {
                        setState(() {
                          sett.showOwner = value;
                          sett.setShowOwner(value);
                        });
                      },
                    ),
                    SwitchListTile(
                      title: Text('Show Price'.toUpperCase(), style: TextStyle(color: Colors.black, fontFamily: "BigJohnProThin")),
                      value: sett.showPrice,
                      activeColor: Colors.black,
                      onChanged: (value) {
                        setState(() {
                          sett.showPrice = value;
                          sett.setShowPrice(value);
                        });
                      },
                    ),
                    SwitchListTile(
                      title: Text('Show QR code'.toUpperCase(), style: TextStyle(color: Colors.black, fontFamily: "BigJohnProThin")),
                      value: sett.showQrcode,
                      activeColor: Colors.black,
                      onChanged: (value) {
                        setState(() {
                          sett.showQrcode = value;
                          sett.setShowQrcode(value);
                        });
                      },
                    ),
                    SwitchListTile(
                      title: Text('Show Title'.toUpperCase(), style: TextStyle(color: Colors.black, fontFamily: "BigJohnProThin")),
                      value: sett.showTitle,
                      activeColor: Colors.black,
                      onChanged: (value) {
                        setState(() {
                          sett.showTitle = value;
                          sett.setShowTitle(value);
                        });
                      },
                    ),
                    SwitchListTile(
                      title: Text('Show Traits'.toUpperCase(), style: TextStyle(color: Colors.black, fontFamily: "BigJohnProThin")),
                      value: sett.showTraits,
                      activeColor: Colors.black,
                      onChanged: (value) {
                        setState(() {
                          sett.showTraits = value;
                          sett.setShowTraits(value);
                        });
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 15, bottom: 15, left: 15, right: 15),
                      child: TextField(
                        style: TextStyle(color: Colors.black),
                        keyboardType: TextInputType.number,
                        controller: imgHldController,
                        decoration: InputDecoration(
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: const BorderSide(
                              color: Colors.black,
                            ),
                          ),
                          border: OutlineInputBorder(),
                          labelText: 'Image Hold Duration',
                          labelStyle: TextStyle(color: Colors.black),
                          hintStyle: TextStyle(color: Colors.black),
                        ),
                        onChanged: (text) {
                          setState(() {
                            sett.imgDuration = int.parse(text) * 1000;
                            sett.setImgDuration(sett.imgDuration);
                          });
                        },
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget renderGrid(BuildContext context) {
    return (Expanded(
        child: Row(children: [
      FutureBuilder(
          future: futureNfts,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              int count = 0;
              for (Nft nft in snapshot.data) {
                if (nft.enabled) {
                  count++;
                }
              }
              return (sideText(context, "DISPLAYING " + count.toString() + "/" + snapshot.data.length.toString() + " NFTS", -1));
            } else {
              return (sideText(context, "LOADING NFTS...", -1));
            }
          }),
      Expanded(child: Center(child: MyGrid(update: update, nfts: futureNfts, sett: sett))),
      sideText(context, "Use + to combine multiple wallets".toUpperCase(), 1)
    ])));
  }

  Widget sideText(BuildContext context, String value, int turns) {
    return (Padding(padding: const EdgeInsets.only(left: 4, right: 4), child: RotatedBox(quarterTurns: turns, child: Text(value, style: TextStyle(fontSize: 14, fontFamily: "BigJohnProThin")))));
  }
}

class MyDisplay extends StatefulWidget {
  final List<Nft> nfts;
  final Settings sett;
  final int start;

  MyDisplay({Key key, @required this.nfts, @required this.sett, @required this.start}) : super(key: key);

  @override
  _MyDisplayState createState() => _MyDisplayState();
}

class _MyDisplayState extends State<MyDisplay> {
  var _isFullScreen = true;
  var _disposed = false;

  @override
  void initState() {
    super.initState();
    _enterFullScreen();
    Wakelock.enable();
  }

  @override
  void dispose() async {
    _disposed = true;
    Wakelock.disable();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _exitFullScreen();
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
    await SystemChrome.setEnabledSystemUIOverlays([]);
    if (_disposed) return;
    _isFullScreen = true;
  }

  void _exitFullScreen() async {
    await SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
    if (_disposed) return;
    _isFullScreen = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          child: Container(child: Center(child: playView(context))),
          onTap: _toggleFullscreen,
        ));
  }

  Widget playView(BuildContext context) {
    final double height = MediaQuery.of(context).size.height;
    bool autoplay = true;
    if (widget.nfts.length == 1) {
      autoplay = false;
    }
    return CarouselSlider(
      options: CarouselOptions(
        initialPage: widget.start,
        height: height,
        viewportFraction: 1.0,
        autoPlay: autoplay,
        autoPlayInterval: Duration(milliseconds: widget.sett.imgDuration),
        autoPlayAnimationDuration: Duration(milliseconds: 1),
        onPageChanged: (index, reason) {},
      ),
      items: widget.nfts.where((element) => element.enabled == true).toList().asMap().entries.map((entry) {
        int index = entry.key;
        Nft i = entry.value;
        return Builder(
          builder: (BuildContext context) {
            Stream<FileResponse> image = DefaultCacheManager().getImageFile(i.imgUrl, withProgress: true, headers: {'Accept-Encoding': ''});
            Future<File> qr = DefaultCacheManager().getSingleFile("https://api.qrserver.com/v1/create-qr-code/?bgcolor=120-120-120&size=70x70&data=" + i.qr);
            return DefaultTextStyle(
              style: TextStyle(
                color: Colors.black.withOpacity(0.5),
                fontFamily: "BigJohnProThin",
              ),
              child: Stack(
                children: <Widget>[
                  if (i.type == "animated") Center(child: videoPlayer(context, i)),
                  if (i.type == "image")
                    Center(
                        child: Stack(children: <Widget>[
                      StreamBuilder<FileResponse>(
                          stream: image,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || snapshot.data is DownloadProgress) {
                              if (snapshot.data != null) {
                                return Center(
                                    child: Opacity(
                                        opacity: 0.2,
                                        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
                                          CircularProgressIndicator(value: (snapshot.data as DownloadProgress)?.progress),
                                          Text(
                                            "Downloading " +
                                                (((snapshot.data as DownloadProgress).downloaded) / 1000000).toStringAsFixed(1) +
                                                '/' +
                                                (((snapshot.data as DownloadProgress).totalSize) / 1000000).toStringAsFixed(1) +
                                                'MB',
                                            style: TextStyle(color: Colors.white),
                                          )
                                        ])));
                              }
                              return Center(
                                  child: Opacity(
                                opacity: 0.2,
                                child: CircularProgressIndicator(),
                              ));
                            } else {
                              return (Image.file((snapshot.data as FileInfo).file));
                            }
                          }),
                    ])),
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Container(
                        width: 200,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (widget.sett.showTitle == true)
                            RichText(
                              text: TextSpan(
                                text: i.name,
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 18, height: 1.5, fontFamily: "BigJohnProThin"),
                              ),
                            ),
                          if (widget.sett.showArtist == true)
                            RichText(
                              text: TextSpan(
                                text: 'Artist: ',
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 9, fontFamily: "BigJohnPro"),
                                children: <TextSpan>[
                                  TextSpan(text: i.artist, style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          if (widget.sett.showOwner == true)
                            RichText(
                              text: TextSpan(
                                text: 'Owner: ',
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 9, fontFamily: "BigJohnPro"),
                                children: <TextSpan>[
                                  TextSpan(text: i.owner, style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          if (widget.sett.showPrice == true)
                            RichText(
                              text: TextSpan(
                                text: 'Last Sale: ',
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 9, fontFamily: "BigJohnPro"),
                                children: <TextSpan>[
                                  TextSpan(text: i.lastSale, style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          if (widget.sett.showTraits == true)
                            RichText(
                              text: TextSpan(
                                text: 'Traits: ',
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 9, fontFamily: "BigJohnPro"),
                                children: <TextSpan>[
                                  TextSpan(text: i.traits, style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                        ])),
                  ),
                  if (widget.sett.showQrcode == true)
                    Positioned(
                        top: 0,
                        right: 0,
                        child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: FutureBuilder(
                              future: qr,
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return (Container(width: 40.0, height: 40.0, child: Center(child: Image.file(snapshot.data, width: 50, height: 50))));
                                }
                                return Center(
                                    child: Opacity(
                                  opacity: 0.2,
                                  child: CircularProgressIndicator(),
                                ));
                              },
                            ))),
                ],
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget videoPlayer(BuildContext context, Nft i) {
    if (kIsWeb) {
      if (_disposed == false) {
        Future<void> _initializeVideoPlayerFuture;
        VideoPlayerController _controller = VideoPlayerController.network(
          i.animUrl,
        );
        _controller.setLooping(true);
        _controller.play();
        _initializeVideoPlayerFuture = _controller.initialize();
        return (FutureBuilder(
          future: _initializeVideoPlayerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              // If the VideoPlayerController has finished initialization, use
              // the data it provides to limit the aspect ratio of the VideoPlayer.
              return AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                // Use the VideoPlayer widget to display the video.
                child: VideoPlayer(_controller),
              );
            } else {
              // If the VideoPlayerController is still initializing, show a
              // loading spinner.
              return Opacity(opacity: 0.05, child: CircularProgressIndicator());
            }
          },
        ));
      }
      return Opacity(opacity: 0.05, child: CircularProgressIndicator());
    } else {
      Stream<FileResponse> video = DefaultCacheManager().getFileStream(i.animUrl, withProgress: true);
      return (StreamBuilder<FileResponse>(
          stream: video,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data is FileInfo) {
              if (_disposed == false) {
                return (NativeVideoView(
                  keepAspectRatio: true,
                  showMediaController: false,
                  onCreated: (controller) {
                    controller.setVideoSource(
                      (snapshot.data as FileInfo).file.path,
                      sourceType: VideoSourceType.file,
                    );
                  },
                  onPrepared: (controller, info) {
                    controller.play();
                  },
                  onError: (controller, what, extra, message) {},
                  onCompletion: (controller) {
                    controller.play();
                  },
                  onProgress: (progress, duration) {},
                ));
              }
            } else if (snapshot.data is DownloadProgress) {
              return Center(
                  child: Opacity(
                opacity: 0.4,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [
                  CircularProgressIndicator(value: (snapshot.data as DownloadProgress).progress),
                  Text(
                      "Downloading " +
                          (((snapshot.data as DownloadProgress).downloaded) / 1000000).toStringAsFixed(1) +
                          '/' +
                          (((snapshot.data as DownloadProgress).totalSize) / 1000000).toStringAsFixed(1) +
                          'MB',
                      style: TextStyle(color: Colors.white))
                ]),
              ));
            }
            return Opacity(opacity: 0.05, child: CircularProgressIndicator());
          }));
    }
  }
}
