import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_compass/flutter_map_compass.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png'; // Default to OpenStreetMap
  AnimationController? _controller;
  StreamSubscription<Position>? _positionStreamSubscription;
  List<Map<String, dynamic>> _alerts = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    fetchAlerts();
    _timer = Timer.periodic(Duration(minutes: 2), (Timer t) => fetchAlerts());
    _determinePosition();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _listenToPosition();
  }

  Future<void> fetchAlerts() async {
    const url =
        'https://bipadportal.gov.np/api/v1/alert/?rainBasin=&rainStation=&riverBasin=&riverStation=&hazard=&started_on__gt=2024-05-08T00%3A00%3A00%2B05%3A45&started_on__lt=2024-05-15T23%3A59%3A59%2B05%3A45&expand=event&ordering=-started_on';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        setState(() {
          _alerts = List<Map<String, dynamic>>.from(data['results']);
        });
      } else {
        throw Exception('Failed to load alerts');
      }
    } catch (e) {
      print('Error fetching alerts: $e');
    }
  }

  List<Marker> _generateMarkers() {
    return _alerts.map((alert) {
      Color markerColor;
      switch (alert['referenceType']) {
        case 'fire':
          markerColor = Colors.red;
          break;
        case 'rain':
          markerColor = Colors.blue;
          break;
        case 'flood':
          markerColor = Colors.black;
          break;
        case 'pollution':
          markerColor = Colors.yellow;
          break;
        default:
          markerColor = Colors.grey; // Default color for undefined types
      }

      return Marker(
        width: 15.0,
        height: 15.0,
        point: LatLng(
            alert['point']['coordinates'][1], alert['point']['coordinates'][0]),
        child: Container(
          decoration: BoxDecoration(
            color: markerColor,
            shape: BoxShape.circle,
          ),
        ),
      );
    }).toList();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _positionStreamSubscription?.cancel();
    _timer?.cancel();
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

  void _showAlertMessage(BuildContext context) {
    if (_alerts.isEmpty) {
      // Show a loading indicator or a message indicating data is being fetched
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Fetching Alerts..."),
            content: CircularProgressIndicator(),
            actions: [
              TextButton(
                child: Text("Cancel"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          String titleText = "${_alerts.length} Alerts";
          return AlertDialog(
            title: Text(titleText),
            content: SingleChildScrollView(
              child: Column(
                children: _alerts.map((alert) {
                  return Column(
                    children: [
                      Text("${alert['title']} - ${alert['description']}"),
                      Divider(),
                    ],
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                child: Text("Close"),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          );
        },
      );
    }
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
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                  ? Icon(Icons
                      .check) // This line adds the checkmark if StreetView is the current layer
                  : null,
              onTap: () {
                setState(() {
                  currentMapUrlTemplate =
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.terrain),
              title: Text('TopoView'),
              trailing: currentMapUrlTemplate ==
                      'https://tile.opentopomap.org/{z}/{x}/{y}.png'
                  ? Icon(Icons
                      .check) // This line adds the checkmark if TopoView is the current layer
                  : null,
              onTap: () {
                setState(() {
                  currentMapUrlTemplate =
                      'https://tile.opentopomap.org/{z}/{x}/{y}.png';
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
        title: Stack(
          alignment: Alignment.centerLeft,
          children: <Widget>[
            IconButton(
              icon: Icon(Icons.notification_important,
                  color: Colors.grey
                      .withOpacity(0.9)), // Semi-transparent icon behind text
              onPressed: () => _showAlertMessage(context),
            ),
            Center(child: Text('Nepal Maps')), // Centered text
          ],
        ),
      ),
      body: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          center: currentLocation,
          zoom: 13.0,
          minZoom: 7,
          maxZoom: 18,
        ),
        children: [
          TileLayer(
            urlTemplate: currentMapUrlTemplate,
            //subdomains: ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: _generateMarkers(),
          ),
          MapCompass.cupertino(hideIfRotatedNorth: true),
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
