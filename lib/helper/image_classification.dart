/*
 * Copyright 2023 The TensorFlow Authors. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *             http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:obj_cam/helper/isolate_inference.dart';
import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

class ImageClassification {
  // static const modelPath = 'assets/efficientdet.tflite';
  static const modelPath = 'assets/mobilenet_quant.tflite';
  static const labelsPath = 'assets/labels.txt';

  // late final List<String> labels = [];
  late final List<String> labels;

  late final IsolateInference isolateInference;
  late final tfl.Interpreter interpreter;
  late tfl.Tensor inputTensor;
  late tfl.Tensor outputTensor;
  final options = tfl.InterpreterOptions();

  Future<void> init() async {
    loadLabels();
    loadModel();

    isolateInference = IsolateInference();
    await isolateInference.start();
  }

  // Load labels from assets
  Future<void> loadLabels() async {
    final labelTxt = await rootBundle.loadString(labelsPath);
    labels = labelTxt.split('\n');
  }

  Future<void> loadModel() async {
    // Use XNNPACK Delegate
    if (Platform.isAndroid) {
      options.addDelegate(tfl.XNNPackDelegate());
    }

    // Use Metal Gpu Delegate
    if (Platform.isIOS) {
      options.addDelegate(tfl.GpuDelegate());
    }

    // Load model from assets dir
    interpreter = await tfl.Interpreter.fromAsset(
      modelPath,
      options: options,
    );
    // Get tensor input shape [1, 224, 224, 3]
    inputTensor = interpreter.getInputTensors().toList().first;
    // Get tensor output shape [1, 1001]
    outputTensor = interpreter.getOutputTensors().first;

    if (kDebugMode) {
      print(
          "LOG -- InputTensors: ${inputTensor}; OutputTensor: ${outputTensor}");
      print("Log -- Interpreter loaded successfully");
    }

    /**
    final isolateInterpreter = await tfl.IsolateInterpreter.create(
      address: interpreter.address,
    );
    isolateInterpreter.run(Icons.image, 'detection_classes');
    print("LOG -- $isolateInterpreter");
     */

    // final interpreter =
//     await tfl.loadModelFromAsset('assets/efficientdet.tflite');
  }

  Future<Map<String, double>> _inference(InferenceModel inferenceModel) async {
    ReceivePort responsePort = ReceivePort();
    isolateInference.sendPort
        .send(inferenceModel..responsePort = responsePort.sendPort);
    // get inference result.
    var results = await responsePort.first;
    if (kDebugMode) {
      print("LOG -- Results: $results");
    }
    return results;
  }

  // inference camera frame
  Future<Map<String, double>> inferenceCameraFrame(
      CameraImage cameraImage) async {
    var isolateModel = InferenceModel(cameraImage, null, interpreter.address,
        labels, inputTensor.shape, outputTensor.shape);
    return _inference(isolateModel);
  }

  Future<void> close() async {
    isolateInference.close();
  }
}
