import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:obj_cam/camera.dart';

Future<void> main() async {
  // Ensure that plugin services are initialized so that `availableCameras()`
  // can be called before `runApp()`
  WidgetsFlutterBinding.ensureInitialized();

  // Get a list of available cameras on the device.
  final cameras = await availableCameras();
  // Get a specific camera from the list of available cameras
  final CameraDescription firstCamera = cameras.first; //_cameras[0]

  runApp(MyApp(
    camera: firstCamera,
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.camera});

  final CameraDescription camera;

  // This widget is the root of the application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Obj Cam',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrangeAccent,
        ),
        useMaterial3: true,
      ),
      home: ObjCamPage(
        title: 'Obj Cam Demo Page',
        // Pass the primary/back camera to the ObjCamPage widget.
        camera: camera,
      ),
    );
  }
}
