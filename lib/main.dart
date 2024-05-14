import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_compass/flutter_map_compass.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nepal Maps',
      home: MyHomePage(),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('en', ''), // English
        // Add other locales your app supports
      ],
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  final MapController mapController = MapController();
  LatLng? currentLocation; // Initially null, set once location is fetched.
  String currentMapUrlTemplate =
      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'; // Default to OpenStreetMap
  AnimationController? _controller;
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _listenToPosition();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      currentLocation = LatLng(position.latitude, position.longitude);
    });
  }

  void _animateToUser() {
    if (currentLocation == null || _controller == null) return;

    LatLng start = mapController.center;
    LatLng destination = currentLocation!;
    double startZoom = mapController.zoom;
    double destinationZoom = 13.0; // Set this to your preferred zoom level

    Tween<double> latTween =
        Tween<double>(begin: start.latitude, end: destination.latitude);
    Tween<double> lngTween =
        Tween<double>(begin: start.longitude, end: destination.longitude);
    Tween<double> zoomTween =
        Tween<double>(begin: startZoom, end: destinationZoom);

    _controller!.reset();
    _controller!.forward();

    _controller!.addListener(() {
      double lat = latTween.evaluate(_controller!);
      double lng = lngTween.evaluate(_controller!);
      double zoom = zoomTween.evaluate(_controller!);
      mapController.move(LatLng(lat, lng), zoom);
    });
  }

  void _listenToPosition() {
    const locationSettings =
        LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        setState(() {
          currentLocation = LatLng(position.latitude, position.longitude);
        });
      },
    );
  }

  void _showLayerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: Icon(Icons.map),
              title: Text('StreetView'),
              trailing: currentMapUrlTemplate ==
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'
                  ? Icon(Icons
                      .check) // This line adds the checkmark if StreetView is the current layer
                  : null,
              onTap: () {
                setState(() {
                  currentMapUrlTemplate =
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.terrain),
              title: Text('TopoView'),
              trailing: currentMapUrlTemplate ==
                      'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png'
                  ? Icon(Icons
                      .check) // This line adds the checkmark if TopoView is the current layer
                  : null,
              onTap: () {
                setState(() {
                  currentMapUrlTemplate =
                      'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
                });
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentLocation == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nepal Maps'),
      ),
      body: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          center: currentLocation,
          zoom: 13.0,
          minZoom: 10,
          maxZoom: 18,
        ),
        children: [
          TileLayer(
            urlTemplate: currentMapUrlTemplate,
            subdomains: ['a', 'b', 'c'],
          ),
          const MapCompass.cupertino(hideIfRotatedNorth: true),
          MarkerLayer(
            markers: [
              Marker(
                point: currentLocation!,
                width: 20.0,
                height: 20.0,
                child: Container(
                    //width: 0.2, // The diameter of the circle
                    //height: 0.2, // The diameter of the circle
                    decoration: BoxDecoration(
                      color: Colors.yellow, // Color of the circle
                      shape:
                          BoxShape.circle, // Ensures the container is circular
                    ),
                    child: Center(
                        child: Container(
                            width: 15,
                            height: 15,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            )))),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          FloatingActionButton(
            onPressed: _showLayerOptions,
            child: Icon(Icons.layers),
            backgroundColor: Colors.green,
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            onPressed: _animateToUser,
            child: Icon(Icons.my_location),
            backgroundColor: Colors.blue,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
