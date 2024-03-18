import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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

class ObjCamPage extends StatefulWidget {
  const ObjCamPage({super.key, required this.title, required this.camera});

  // This widget is the home page of the application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;
  final CameraDescription camera;

  @override
  State<ObjCamPage> createState() => _ObjCamPageState();
}

class _ObjCamPageState extends State<ObjCamPage> with WidgetsBindingObserver {
  int _timeCounter = 0;

  late CameraController _controller;
  late Future<void> _initializeCameraControllerFuture;

  String cameraErrorMessage = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSelectedCamera();
  }

  Future<void> _initializeSelectedCamera(
      [CameraDescription? description/*= widget.camera */]) async {
    // To display the current output from the Camera, create a CameraController.
    _controller = CameraController(
      // Use a specific camera - primary camera as default - from the list of
      // available cameras.
      widget.camera,
      // Define the resolution to use here.
      ResolutionPreset.max,
    );

    // TODO: ADD a try/catch?
    try {
      // Initialize the controller. This returns a Future.
      _initializeCameraControllerFuture = _controller.initialize();
    } on CameraException catch (e) {
      if (kDebugMode) {
        print("CameraException: ${e.code}; ${e.description}");
      }
      switch (e.code) {
        case 'CameraAccessDenied':
          // Handle access errors here.
          cameraErrorMessage = "Camera access permission was denied.";
          showInSnackBar('You have denied camera access.');
          break;
        case 'CameraAccessRestricted': // iOS only
          showInSnackBar('Camera access is restricted.');
          break;
        case 'CameraAccessDeniedWithoutPrompt': // iOS only
          showInSnackBar('Please go to Settings app to enable camera access.');
        case 'AudioAccessDenied':
          showInSnackBar('You have denied audio access.');
        case 'AudioAccessDeniedWithoutPrompt': // iOS only
          showInSnackBar('Please go to Settings app to enable audio access.');
        case 'AudioAccessRestricted': // iOS only
          showInSnackBar('Audio access is restricted.');
        default:
          // Handle other errors here.
          cameraErrorMessage = "Camera not yet initialized.";
          break;
      }
      if (mounted) {
        setState(() {});
      }
    }

    // If the controller is updated then update the UI.
    _controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
      if (_controller.value.hasError) {
        print('Camera error ${_controller.value.errorDescription}');
      }
    });
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    // Clean up the stateful widget whenever the app is minimized or killed.
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the ObjCamPage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      // You must wait until the controller is initialized before displaying the
      // camera preview. Use a FutureBuilder to display a loading spinner until the
      // controller has finished initializing.
      body: FutureBuilder<void>(
        future: _initializeCameraControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              _controller != null &&
              _controller.value.isInitialized) {
            // TODO: check if audio permission is also enabled.
            // If the Future is complete, display the preview.
            return Center(
              // Center is a layout widget. It takes a single child and positions it
              // in the middle of the parent.
              child: Column(
                // Column is also a layout widget. It takes a list of children and
                // arranges them vertically. By default, it sizes itself to fit its
                // children horizontally, and tries to be as tall as its parent.
                //
                // Column has various properties to control how it sizes itself and
                // how it positions its children. Here we use mainAxisAlignment to
                // center the children vertically; the main axis here is the vertical
                // axis because Columns are vertical (the cross axis would be
                // horizontal).
                //
                // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
                // action in the IDE, or press "p" in the console), to see the
                // wireframe for each widget.
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Live Camera Preview',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  CameraPreview(_controller),
                ],
              ),
            );
          } else {
            // Otherwise, display a message and a loading indicator. Display a
            // message if the camera is not initialized.
            // if (!_controller.value.isInitialized)
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  cameraErrorMessage,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const CircularProgressIndicator(),
              ],
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        // An onPressed callback to capture the image in frame.
        onPressed: () async {
          // Take the Picture in a try / catch block. If anything goes wrong,
          // catch the error.
          try {
            // Ensure that the camera is initialized.
            await _initializeCameraControllerFuture;

            // Attempt to take a picture and get the file `image` where it was
            // saved.
            final image = await _controller.takePicture();
            showInSnackBar('Picture saved to ${image.path}');
            print('Picture saved to ${image.path}');
            // if (!context.mounted) return;

            // If the picture was taken, display it on a new screen.
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => DisplayImageScreen(
                  // Pass the automatically generated path to
                  // the DisplayPictureScreen widget.
                  imagePath: image.path,
                ),
              ),
            );
          } catch (e) {
            // If an error occurs, log the error to the console.
            if (kDebugMode) {
              print(e);
            }
          }
        },
        tooltip: 'Capture',
        child: const Icon(Icons.camera),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController cameraController = _controller;

    // App state changed before we got the chance to initialize.
    if (!cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // Free up memory when camera not active
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      // Reinitialize the camera with same properties
      _initializeSelectedCamera(cameraController.description);
    }
  }

  void showInSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 7),
    ));
  }
}

// A widget that displays the picture taken by the user.
class DisplayImageScreen extends StatelessWidget {
  final String imagePath;

  const DisplayImageScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Display the Picture')),
      // The image is stored as a file on the device. Use the `Image.file`
      // constructor with the given path to display the image.
      body: Image.file(File(imagePath)),
    );
  }
}
