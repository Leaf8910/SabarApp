import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'dart:math' show pi;
import 'package:geolocator/geolocator.dart';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:permission_handler/permission_handler.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  double? _qiblaDirection;
  double? _heading;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initQiblaCompass();
  }

  Future<void> _initQiblaCompass() async {
    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted) {
      try {
        final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        final coordinates = Coordinates(position.latitude, position.longitude);
        final qiblaDirection = Qibla.qibla(coordinates);
        setState(() {
          _qiblaDirection = qiblaDirection;
        });

        FlutterCompass.events?.listen((CompassEvent event) {
          setState(() {
            _heading = event.heading;
          });
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'Could not get location or compass data: $e';
        });
      }
    } else if (status.isDenied) {
      setState(() {
        _errorMessage = 'Location permission denied. Please enable it in settings to use Qibla.';
      });
    } else if (status.isPermanentlyDenied) {
      setState(() {
        _errorMessage = 'Location permission permanently denied. Please enable it manually in settings.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Qibla Compass'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ) 
            else if (_qiblaDirection == null || _heading == null)
              const CircularProgressIndicator()
            else...
            [
              Text(
                'Rotate your device to point towards the Kaabah.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Stack(
                alignment: Alignment.center,
                children: [
                  // Compass background
                  Image.asset(
                    'assets/compass_background.png', // Placeholder, you'd need to add this asset
                    width: 250,
                    height: 250,
                  ),
                  // Qibla needle (adjust rotation to point to Qibla relative to North)
                  Transform.rotate(
                    angle: ((_qiblaDirection! - _heading!) * (pi / 180) * -1),
                    child: Image.asset(
                      'assets/qibla_needle.png', // Placeholder, you'd need to add this asset
                      width: 200,
                      height: 200,
                    ),
                  ),
                  // Device heading indicator
                  Transform.rotate(
                    angle: (_heading! * (pi / 180) * -1),
                    child: const Icon(
                      Icons.navigation,
                      size: 50,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Text(
                'Qibla Direction: ${(_qiblaDirection ?? 0).toStringAsFixed(2)}°',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'Current Heading: ${(_heading ?? 0).toStringAsFixed(2)}°',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
