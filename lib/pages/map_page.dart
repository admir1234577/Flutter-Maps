

import 'dart:async';

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

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getLocationUpdates().then((_) => {
      getPolylinePoints().then((coordinates) => {
        generatePolyLineFromPoints(coordinates),
      })
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentPosition == null ? const Center(child: Text("Loading..."),)
            : GoogleMap(
        onMapCreated: ((GoogleMapController controller)
        => _mapController.complete(controller)),
        initialCameraPosition: CameraPosition(
            target: _pPodgorica,
            zoom: 13),
        markers: {
          Marker(
              markerId: MarkerId("_currentlocation"),
              icon: BitmapDescriptor.defaultMarker,
              position: _currentPosition!
          ),
          Marker(
            markerId: MarkerId("_sourcelocation"),
            icon: BitmapDescriptor.defaultMarker,
            position: _pPodgorica
          ),
          Marker(
              markerId: MarkerId("_destinationlocation"),
              icon: BitmapDescriptor.defaultMarker,
              position: _pInternationalBridge
          ),
        },
        polylines: Set<Polyline>.of(polylines.values),
      ),
    );
  }

  Future<void> _cameraToPosition(LatLng pos) async {
    final GoogleMapController controller = await _mapController.future;
    CameraPosition _newCameraPosition = CameraPosition(
        target: pos,
        zoom: 13,
    );
    await controller.animateCamera(CameraUpdate.newCameraPosition(_newCameraPosition));
  }

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

        });
      }
    });
  }
  Future<List<LatLng>> getPolylinePoints() async {
    List<LatLng> polylineCoordinates = [];
    PolylinePoints polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        GOOGLE_MAPS_API_KEY,
        PointLatLng(_pPodgorica.latitude, _pPodgorica.longitude),
        PointLatLng(_pInternationalBridge.latitude, _pInternationalBridge.longitude),
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

  void generatePolyLineFromPoints(List<LatLng> polylineCoordinates) async {
    PolylineId id = PolylineId("poly");
    Polyline polyline = Polyline(polylineId: id,
    color: Colors.black,
    points: polylineCoordinates,
    width: 8);
    setState(() {
      polylines[id] = polyline;
    });
  }
}
