import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with TickerProviderStateMixin {
  final MapController mapController = MapController();
  LatLng? currentLocation; // Initially null, set once location is fetched.

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Handle disabled location services
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Handle denied permission
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Handle permanently denied permission
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      currentLocation = LatLng(position.latitude, position.longitude);
    });
  }

  void _animateToUser() {
    if (currentLocation == null) return; // Ensure location is not null

    final latTween = Tween<double>(
      begin: mapController.center.latitude,
      end: currentLocation!.latitude,
    );
    final lngTween = Tween<double>(
      begin: mapController.center.longitude,
      end: currentLocation!.longitude,
    );

    var controller = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    Animation<double> animation = CurvedAnimation(
      parent: controller,
      curve: Curves.fastOutSlowIn,
    );

    controller.addListener(() {
      LatLng newPos = LatLng(
        latTween.evaluate(animation),
        lngTween.evaluate(animation),
      );
      mapController.move(newPos, mapController.zoom);
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (currentLocation == null) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
              child:
                  CircularProgressIndicator()), // Show loading indicator while fetching location
        ),
      );
    }

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Nepal Maps')),
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
              urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: currentLocation!,
                  width: 80.0,
                  height: 80.0,
                  child: Container(
                    child: const Icon(Icons.location_on,
                        color: Colors.red, size: 40),
                  ),
                ),
              ],
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _animateToUser,
          child: Icon(Icons.my_location),
          backgroundColor: Colors.blue,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}
