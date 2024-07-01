

import 'dart:async';
import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:location/location.dart';
import 'package:maps/consts.dart';

class MapPage  extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {

  Location _locationController = new Location();

  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();

  static const LatLng _pPodgorica = LatLng(42.442574, 	19.268646);
  static const LatLng _pInternationalBridge = LatLng(42.434336569143085, 19.2436259106889);
  LatLng? _currentPosition = null;

  Map<PolylineId, Polyline> polylines = {};
  double? distanceToPodgorica;
  double? distanceToInternationalBridge;
  double? distanceToUserMarker;
  bool userZoomed = false;
  List<LatLng> markers = [_pPodgorica, _pInternationalBridge];
  Set<LatLng> notifiedMarkers = {};
  LatLng? userAddedMarker;

  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;




  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    initializeNotifications();
    getLocationUpdates().then((_) => {
      getPolylinePoints(_pInternationalBridge, _pPodgorica).then((coordinates) => {
        generatePolyLineFromPoints(coordinates),
      })
    });
  }

  // Initialize notifications
  void initializeNotifications() {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        onDidReceiveLocalNotification: (int id, String? title, String? body, String? payload) async {

        });

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Create notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      '1',
      'channel',
      description: 'description',
      importance: Importance.high,
    );

    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Send a notification
  void sendNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      '1', 'channel',
      channelDescription: 'description',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
        styleInformation: BigTextStyleInformation(''),
        icon: 'ic_launcher'

    );
    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: 'item x',
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _currentPosition == null
              ? const Center(child: Text("Loading..."))
              : GoogleMap(
            onMapCreated: ((GoogleMapController controller) =>
                _mapController.complete(controller)),
            trafficEnabled: true,
            onTap: handleMapTap,
            initialCameraPosition: CameraPosition(
                target: _pPodgorica,
                zoom: 18),
            markers: buildMarkers(),
            polylines: Set<Polyline>.of(polylines.values),
            onCameraMove:  (CameraPosition position) {
              userZoomed = true;  // Korisnik kontrolise kameru
            },
          ),
    if (distanceToUserMarker != null)
    Positioned(
    bottom: 20,
    left: 10,
    child: Container(
    padding: EdgeInsets.all(10),
    decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(10),
    boxShadow: [
    BoxShadow(
    color: Colors.grey.withOpacity(0.5),
    spreadRadius: 2,
    blurRadius: 5,
    offset: Offset(0, 3),
    ),
    ],
    ),
    child: Text(
    "Distance to User Marker: ${distanceToUserMarker!.toStringAsFixed(2)} km",
    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    ),
    ),
    ),
        ],
      ),


    );
  }


  // Move camera to a specific position
  Future<void> _cameraToPosition(LatLng pos) async {
    if (!userZoomed) {  // Samo kako korisnik nije zumirao
    final GoogleMapController controller = await _mapController.future;
    CameraPosition _newCameraPosition = CameraPosition(
      target: pos,
      zoom: 18,
    );
    await controller.animateCamera(
        CameraUpdate.newCameraPosition(_newCameraPosition));
  }
  }

  // Get location updates
  Future<void> getLocationUpdates() async {
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    _serviceEnabled = await _locationController.serviceEnabled();

    if (_serviceEnabled) {
      _serviceEnabled = await _locationController.requestService();
    } else {
      return;
    }
    _permissionGranted = await _locationController.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await _locationController.requestPermission();
    
    if (_permissionGranted == PermissionStatus.granted) {
      return;
    }
    }
    _locationController.onLocationChanged.listen((LocationData currentLocation) {
      if (currentLocation.latitude != null && currentLocation.longitude != null) {
        setState(() {
          _currentPosition = LatLng(currentLocation.latitude!, currentLocation.longitude!);
          _cameraToPosition(_currentPosition!);
          updateDistances(_currentPosition!);
          if (userAddedMarker != null) {
            updatePolyline(_currentPosition!);
          }



        });
        checkProximityToMarkers(_currentPosition!);
      }
    });
  }

  // Get polyline points between two locations
  Future<List<LatLng>> getPolylinePoints(LatLng start, LatLng end) async {
    List<LatLng> polylineCoordinates = [];
    PolylinePoints polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        GOOGLE_MAPS_API_KEY,
        PointLatLng(start.latitude, start.longitude),
        PointLatLng(end.latitude, end.longitude),
    travelMode: TravelMode.driving);
    if (result.points.isNotEmpty) {
      result.points.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude,
            point.longitude));
      });
    }
    else {
      print(result.errorMessage);
    }
    return polylineCoordinates;

  }

  // Generate polyline from a list of points
  void generatePolyLineFromPoints(List<LatLng> polylineCoordinates) async {
    PolylineId id = PolylineId("poly");
    Polyline polyline = Polyline(polylineId: id,
    color: Colors.blue,
    points: polylineCoordinates,
    width: 8);
    setState(() {
      polylines[id] = polyline;
    });
  }

  // Calculate distance between two locations
  double calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371; // Zemljin radius u kilometrima
    double dLat = _degreeToRadian(end.latitude - start.latitude);
    double dLng = _degreeToRadian(end.longitude - start.longitude);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreeToRadian(start.latitude)) * cos(_degreeToRadian(end.latitude)) *
            sin(dLng / 2) * sin(dLng / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // Convert degree to radian
  double _degreeToRadian(double degree) {
    return degree * pi / 180;
  }

  // Check proximity to markers and send notification if close
  void checkProximityToMarkers(LatLng currentPosition) {
    Set<LatLng> allMarkers = {...markers, if (userAddedMarker != null) userAddedMarker!};
    for (LatLng marker in allMarkers) {
      if (!notifiedMarkers.contains(marker)) {
        double distance = calculateDistance(currentPosition, marker);
        if (distance <= 1.0) {
          sendNotification("Flutter Maps", "You are approaching your destination!");
          notifiedMarkers.add(marker);
        }
      }
    }
  }

  // Handle map tap to add user marker and update polyline
  void handleMapTap(LatLng tappedPoint) async {
    setState(() {
      userAddedMarker = tappedPoint;
    });
    if (_currentPosition != null && userAddedMarker != null) {
      List<LatLng> polylineCoordinates = await getPolylinePoints(_currentPosition!, userAddedMarker!);
      generatePolyLineFromPoints(polylineCoordinates);
      updatePolyline(_currentPosition!);
    }
  }

  // Build markers for the map
  Set<Marker> buildMarkers() {
    Set<Marker> allMarkers = {
      Marker(markerId: MarkerId("_currentlocation"), icon: BitmapDescriptor.defaultMarker, position: _currentPosition!),
      Marker(markerId: MarkerId("_sourcelocation"), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue), position: _pPodgorica,
        infoWindow: InfoWindow(
          title: "Podgorica",
          snippet: calculateDistanceLabel(_currentPosition!, _pPodgorica),
        ),),
      Marker(markerId: MarkerId("_destinationlocation"), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue), position: _pInternationalBridge,
        infoWindow: InfoWindow(
          title: "International Bridge",
          snippet: calculateDistanceLabel(_currentPosition!, _pInternationalBridge),
        ),),
    };
    if (userAddedMarker != null) {
      allMarkers.add(Marker(markerId: MarkerId("_useradded"), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen), position: userAddedMarker!,
        infoWindow: InfoWindow(
          title: "User Added Marker",
          snippet: calculateDistanceLabel(_currentPosition!, userAddedMarker!),
        ),));
    }
    return allMarkers;
  }


  // Calculate distance label for markers
  String calculateDistanceLabel(LatLng currentPosition, LatLng markerPosition) {
    double distance = calculateDistance(currentPosition, markerPosition);
    return "Distance: ${distance.toStringAsFixed(2)} km";
  }


  // Update distances to markers
  void updateDistances(LatLng currentPosition) {
    setState(() {
      distanceToPodgorica = calculateDistance(currentPosition, _pPodgorica);
      distanceToInternationalBridge = calculateDistance(currentPosition, _pInternationalBridge);
      if (userAddedMarker != null) {
        distanceToUserMarker = calculateDistance(currentPosition, userAddedMarker!);
      }
    });
  }

  // Update polyline dynamically as user moves
  void updatePolyline(LatLng currentLocation) async {
    if (userAddedMarker != null) {
      List<LatLng> polylineCoordinates = await getPolylinePoints(currentLocation, userAddedMarker!);
      generatePolyLineFromPoints(polylineCoordinates);
    }
  }
}
