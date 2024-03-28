import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:obj_cam/ui/display_image.dart';

import 'package:obj_cam/models/recognition.dart';
import 'package:obj_cam/models/screen_params.dart';
import 'package:obj_cam/service/detector_service.dart';
import 'package:obj_cam/ui/box_widget.dart';
import 'package:obj_cam/ui/stats_widget.dart';

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
  int _frameCounter = 0;
  double _confidence = 0.0;
  double _minAvailableZoom = 1.0, _maxAvailableZoom = 1.0, _zoomLevel = 1.0;

  String cameraErrorMessage = "";
  String _detectedObject = "";

  /// Results to draw bounding boxes
  List<Recognition>? results;

  /// Realtime stats
  Map<String, String>? stats;

  StreamSubscription? _subscription;

  CameraController? _cameraController;

  // use only when initialized; rarely null
  get _controller => _cameraController;

  /// Object Detector is running on a background [Isolate]. This is nullable
  /// because acquiring a [Detector] is an asynchronous operation. This value is
  /// `null` until the detector is initialized.
  Detector? _detector;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSelectedCamera();
    _initDetectorAsync();
  }

  /// Initializes the camera by setting [_cameraController] to [description] --
  /// the back camera on most devices.
  Future<void> _initializeSelectedCamera(
      [CameraDescription? description/*= widget.camera */]) async {
    try {
      // To display the current output from the Camera, create a CameraController.
      _cameraController = CameraController(
        // Use a specific camera - primary camera as default - from the list of
        // available cameras.
        widget.camera,
        // Define the resolution to use here.
        ResolutionPreset.medium,
        // Image Format
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
        enableAudio: false,
      )..initialize().then((value) async {
          await _controller.startImageStream(imageAnalysis);
          setState(() {});

          /// previewSize is size of each image frame captured by controller
          ///
          /// 352x288 on iOS, 240p (320x240) on Android with ResolutionPreset.low
          /// ~480p on Android with Resolution.medium
          ScreenParams.previewSize = _controller.value.previewSize!;
          _controller.getMaxZoomLevel().then((double value) => setState(() {
                _maxAvailableZoom = value;
              }));
          _controller.getMinZoomLevel().then((double value) => setState(() {
                _minAvailableZoom = value;
              }));
        });
    } on CameraException catch (e) {
      if (kDebugMode) {
        print("LOG -- CameraException: ${e.code}; ${e.description}");
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
    }
  }

  /// Launch background service to run model on frames of image stream captured
  /// by the camera.
  /// [Recognition] instances - which comprise [label], [location], and
  /// confidence [score] of the detected object - are returned in a [List] of [results].
  void _initDetectorAsync() async {
    // Spawn a new isolate
    Detector.start().then((instance) {
      setState(() {
        _detector = instance;
        _subscription = instance.resultsStream.stream.listen((values) {
          setState(() {
            results = values['recognitions'];
            stats = values['stats'];
            if (results!.isNotEmpty) {
              zoomIntoDetectedObject();
            }
            if (kDebugMode) {
              print("Results: $results");
            }
          });
        });
      });
    });
  }

  /// Filter detections from the model output and zoom in on object with high
  /// confidence score.
  void zoomIntoDetectedObject() {
    // Loop through detections from the model output
    for (final detection in results!) {
      // Confidence score check
      if (detection.score >= 0.7) {
        // Calculate and update current zoom level based on
        // detection.location and desired zoom behavior
        setState(() {
          _detectedObject = detection.label;
          _confidence = detection.score * 100;
          _zoomLevel = calculateZoomLevel(detection.location);
          _controller.setZoomLevel(_zoomLevel);
        });
      }
    }
  }

  /// Implementation of logic to calculate the zoom level based on [location] of
  /// the bounding box and desired zoom behavior (e.g., ensure object fills a certain
  /// percentage of frame)
  double calculateZoomLevel(Rect location) {
    // Example: 0.5 -- Object fills half the frame
    const desiredObjectAreaRatio = 0.70;

    final objectArea = location.width * location.height;
    final frameArea = ScreenParams.screenPreviewSize.width *
        ScreenParams.screenPreviewSize.height;

    final zoomLevel = sqrt(frameArea / (objectArea * desiredObjectAreaRatio));
    // Ensure zoom stays within limits
    return zoomLevel.clamp(_minAvailableZoom, _maxAvailableZoom);
  }

  @override
  void dispose() {
    // Clean up the stateful widget whenever the app is minimized or killed.
    WidgetsBinding.instance.removeObserver(this);
    // Dispose of the controller when the widget is disposed.
    _cameraController?.dispose();
    _detector?.stop();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Display a message and a loading indicator if the camera is not initialized.
    if (_cameraController == null || !_controller.value.isInitialized) {
      // TODO: check if audio permission is also enabled.
      return Column(
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
        // mainAxisAlignment: MainAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            cameraErrorMessage,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const CircularProgressIndicator(),
        ],
      );
    }

    ScreenParams.screenSize = MediaQuery.sizeOf(context);
    var aspect = 1 / _controller.value.aspectRatio;

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
      // camera preview. Display a loading spinner until the controller has
      // finished initializing.
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: aspect,
                child: CameraPreview(_controller),
              ),
              AspectRatio(
                aspectRatio: aspect,
                child: _boundingBoxes(),
              ),
            ],
          ),
          Text(
            'Live Camera Preview',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Row(
            children: [
              Slider(
                value: _zoomLevel,
                min: _minAvailableZoom,
                max: _maxAvailableZoom,
                // Adjust the max value as per your requirement
                onChanged: (double value) {
                  setState(() {
                    _zoomLevel = value;
                    _controller.setZoomLevel(_zoomLevel);
                  });
                },
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _zoomLevel = _minAvailableZoom; // Reset the zoom level
                    _controller.setZoomLevel(_zoomLevel);
                  });
                },
                child: const Text('Reset Zoom'),
              ),
            ],
          ),
          _detectedObjWidget(),
          _statsWidget(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        // An onPressed callback to capture the image in frame.
        onPressed: () async {
          // Take the Picture in a try / catch block. If anything goes wrong,
          // catch the error.
          try {
            // Ensure that the camera is initialized.
            await _cameraController;

            // Attempt to take a picture and get the file `image` where it was saved.
            final image = await _controller.takePicture();
            showInSnackBar('Picture saved to ${image.path}');
            if (kDebugMode) {
              print("LOG -- Picture saved to ${image.path}");
            }
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
              print("LOG -- $e");
            }
          }
        },
        tooltip: 'Capture',
        child: const Icon(Icons.camera),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation
          .centerFloat, // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  /// Returns [Stack] of bounding boxes
  Widget _boundingBoxes() {
    if (results == null) {
      return const SizedBox.shrink();
    }
    return Stack(
        children: results!.map((box) => BoxWidget(result: box)).toList());
  }

  /// Returns a widget that displays the label and confidence score of the
  /// detected object.
  Widget _detectedObjWidget() => _detectedObject.isNotEmpty
      ? Text(
          "Detected $_detectedObject with $_confidence% confidence",
          style: const TextStyle(
            color: Colors.greenAccent,
            // Theme.of(context).textTheme.bodyMedium,
          ),
          textAlign: TextAlign.start,
        )
      : const SizedBox.shrink();

  /// Returns [stats] of detected objects
  Widget _statsWidget() => (stats != null)
      ? Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            color: Colors.white.withAlpha(150),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: stats!.entries
                    .map((e) => StatsWidget(e.key, e.value))
                    .toList(),
              ),
            ),
          ),
        )
      : const SizedBox.shrink();

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    // App state changed before we got the chance to initialize.
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // Free up memory when camera not active
      _cameraController?.stopImageStream();
      _detector?.stop();
      _subscription?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      // Reinitialize the camera with same properties
      _initializeSelectedCamera(widget.camera);
      _initDetectorAsync();
    } else if (state == AppLifecycleState.paused) {
      _cameraController?.stopImageStream();
    }
  }

  void showInSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 7),
    ));
  }

  /// Callback to receive each frame [CameraImage] perform inference on it
  Future<void> imageAnalysis(CameraImage cameraImage) async {
    _frameCounter++;
    if (_frameCounter % 20 == 0) {
      _frameCounter = 0;
      _detector?.processFrame(cameraImage);
      if (mounted) {
        setState(() {});
      }
    }
  }
}

// TODO: refactor widgets and methods to make this file shorter.
