import 'dart:core';
import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:intellizoom/views/view_pictures.dart';

import 'package:path_provider/path_provider.dart';

import '../main.dart';
import '../constant/constants.dart';
import 'gallery_view.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({Key? key}) : super(key: key);

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  CameraController? _cameraController;
  CameraImage? _cameraImage;
  bool _isCameraInitialized = false;
  ResolutionPreset currentResolution = ResolutionPreset.max;

  String output = '';
  String label = '';
  List? _recognitions = [];
  bool isRearCamera = true;
  double currentZoomLevel = 1.0;
  double maxZoom = 1.0;
  bool canStartStream = false;
  FlashMode? _currentFlashMode;
  File? _cameraImageFile;
  List<DetectedObject>? objects;
  int currIconPosition = -1;
  bool canAutoFocus = false;
  bool isDetectingObjects = false;
  List<File> allFileList = [];
  int frame = 0;
  List<String> imagePaths = [];
  Icon exposeIcon = exposure[4][1];
  late AnimationController _animationControllerFocus;
  late Animation<double> _animationFocus;
  late AnimationController _animationControllerZoom;
  late Animation<double> _animationZoom;

  @override
  void initState() {
    initCamera(cameras[0]);
    loadModel();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    refreshCapturedImages();
    _animationControllerZoom = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animationControllerFocus = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animationFocus =
        Tween<double>(begin: 0, end: 1).animate(_animationControllerFocus);
    _animationZoom =
        Tween<double>(begin: 0, end: 1).animate(_animationControllerZoom);
    super.initState();
  }

  @override
  void dispose() {
    _cameraController!.dispose();
    _animationControllerZoom.dispose();
    _animationControllerFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      initCamera(_cameraController!.description);
      loadModel();
    }
  }

  void onViewFinderTap(TapDownDetails details) {
    if (_cameraController == null) {
      return;
    }
    final offset = Offset(
      details.globalPosition.dx / MediaQuery.of(context).size.width,
      details.globalPosition.dy / MediaQuery.of(context).size.height,
    );

    _cameraController!.setExposurePoint(offset);
    _cameraController!.setFocusPoint(offset);
  }

  initCamera(CameraDescription cameraDescription) async {
    final previousCameraController = _cameraController;

    final CameraController _controller = CameraController(
      cameraDescription,
      currentResolution,
    );

    await previousCameraController?.dispose();

    if (mounted) {
      setState(() {
        _cameraController = _controller;
      });
    }

    _controller.addListener(() {
      if (mounted) setState(() {});
    });

    _controller.initialize().then((_) {
      if (!mounted) {
        return;
      }

      _cameraController!.getMaxZoomLevel().then((value) => maxZoom = value);

      setState(() {
        _isCameraInitialized = _controller.value.isInitialized;
        _currentFlashMode = _controller.value.flashMode;
      });

      _controller.setExposureOffset(0);
    });
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = WriteBuffer();
    for (Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  void startImageStream() {
    if (canStartStream) {
      _cameraController!.startImageStream((imageFromStream) {
        frame++;
        if (frame % 30 == 0 && canStartStream) {
          frame = 0;
          if (!isDetectingObjects) {
            isDetectingObjects = true;
            _cameraImage = imageFromStream;
            detectObjectOnCamera();
            isDetectingObjects = false;
          }
        } else if (!canStartStream) {
          _cameraController!.stopImageStream();
        }
      });
    } else {
      _cameraController!.stopImageStream();
    }
  }

  Future<void> loadModel() async {
    // Tflite.close();
    await Tflite.loadModel(
            model: 'assets/ssd_mobilenet.tflite',
            labels: 'assets/labels.txt',
            numThreads: 1, // defaults to 1
            isAsset:
                true, // defaults to true, set to false to load resources outside assets
            useGpuDelegate:
                false // defaults to false, set to true to use GPU delegate
            )
        .then((result) {});
  }

  void detectObjectOnCamera() async {
    Tflite.detectObjectOnFrame(
            bytesList: _cameraImage!.planes.map((plane) {
              return plane.bytes;
            }).toList(), // required
            model: "SSDMobileNet",
            imageHeight: _cameraImage!.height,
            imageWidth: _cameraImage!.width,
            imageMean: 127.5, // defaults to 127.5
            imageStd: 127.5, // defaults to 127.5
            rotation: 90, // defaults to 90, Android only
            numResultsPerClass: 5, // defaults to 5
            threshold: 0.3, // defaults to 0.1
            asynch: true // defaults to true
            )
        .then((recognitions) {
      // setState(() {});

      isDetectingObjects = false;

      // print(recognitions.runtimeType);   // List<Object?>

      setState(() {
        _recognitions = recognitions;
      });

      // setState(() {});
    });

    if (_recognitions != null && _recognitions!.isNotEmpty) {
      setState(() {
        output = _recognitions![0]['detectedClass'];

        isDetectingObjects = false;
        final boundingBox = Rect.fromLTWH(
            _recognitions![0]['rect']['x'],
            _recognitions![0]['rect']['y'],
            _recognitions![0]['rect']['w'],
            _recognitions![0]['rect']['h']);
        zoomToDetectedObject(boundingBox);
        canStartStream = false;
        canAutoFocus = false;
        objects;
      });
    } else {
      setState(() {
        output = "No Object detected";
        isDetectingObjects = false;
        canStartStream = true;
        canAutoFocus = true;
        objects;
      });
    }
  }

  void zoomToDetectedObject(Rect boundingBox) async {
    double objectHeight = boundingBox.height;
    double objectWidth = boundingBox.width;
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;
    double minZoom = await _cameraController!.getMinZoomLevel();
    double maxZoom = await _cameraController!.getMaxZoomLevel();
    double currentZoom = currentZoomLevel;

    double scaleY = objectHeight / screenHeight * screenWidth;
    double scaleX = objectWidth / screenWidth * screenHeight;

    double scale = max(scaleY, scaleX);
    scale = min(scale * 1.5, 2.0);

    double newZoom = scale * currentZoom + minZoom;

    if (currentZoom != newZoom) {
      if (newZoom > maxZoom && currentZoom == maxZoom) {
        showSnackBar("Max zoom reached");
      } else {
        final _animationController = AnimationController(
          duration: const Duration(milliseconds: 500),
          vsync: this,
        );
        final _zoomTween = Tween<double>(
            begin: currentZoom, end: min(max(newZoom, minZoom), maxZoom));
        _animationController.forward();
        _animationController.addListener(() async {
          double newZoom = _zoomTween.evaluate(_animationController);
          await _cameraController!.setZoomLevel(newZoom);
          setState(() {
            currentZoomLevel = newZoom;
          });
        });
      }
    }
  }

  Future takePicture() async {
    if (!_cameraController!.value.isInitialized) {
      return null;
    }
    if (_cameraController!.value.isTakingPicture) {
      return null;
    }
    try {
      await _cameraController!.setFlashMode(FlashMode.off);
      final rawImage = await _cameraController!.takePicture();
      File imageFile = File(rawImage.path);

      try {
        final Directory? directory = await getExternalStorageDirectory();
        String fileFormat = imageFile.path.split('.').last;
        int currentUnix = DateTime.now().millisecondsSinceEpoch;

        final path = '${directory!.path}/$currentUnix.$fileFormat';
        await rawImage.saveTo(path);

        refreshCapturedImages();

        _cameraController!.setZoomLevel(currentZoomLevel = 1.0);
      } catch (e) {
        debugPrint(e.toString());
      }

      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => PreviewPage(
                    image: rawImage,
                  )));
    } on CameraException catch (e) {
      debugPrint('Error occured while taking picture: $e');
      return null;
    }
  }

  void refreshCapturedImages() async {
    final directory = await getExternalStorageDirectory();
    List<FileSystemEntity> fileList = await directory!.list().toList();
    allFileList.clear();
    List<Map<int, dynamic>> fileNames = [];

    for (var file in fileList.reversed.toList()) {
      if (file.path.contains('.jpg')) {
        if (!imagePaths.contains(file.path)) {
          imagePaths.add(file.path);
        }

        allFileList.add(File(file.path));

        String name = file.path.split('/').last.split('.').first;
        fileNames.add({0: int.parse(name), 1: file.path.split('/').last});
      }
    }

    if (fileNames.isEmpty) {
      setState(() {
        imagePaths.clear();
        allFileList.clear();
        _cameraImageFile = null;
      });
    }

    if (fileNames.isNotEmpty) {
      final recentFile =
          fileNames.reduce((curr, next) => curr[0] > next[0] ? curr : next);
      String recentFileName = recentFile[1];
      _cameraImageFile = File('${directory.path}/$recentFileName');
      setState(() {
        imagePaths;
        allFileList;
        _cameraImageFile;
      });
    }
  }

  void showSnackBar(text) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        clipBehavior: Clip.antiAlias,
        elevation: 0.0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 10, left: 90, right: 90),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        content: Center(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black38,
      body: SingleChildScrollView(
        child: SafeArea(
            child: _isCameraInitialized
                ? Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(
                                top: 10, left: 8, right: 8),
                            height: MediaQuery.of(context).size.height * 0.7,
                            width: double.infinity,
                            child: CameraPreview(
                              _cameraController!,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (details) =>
                                    onViewFinderTap(details),
                              ),
                            ),
                          ),
                          Visibility(
                            visible: currentZoomLevel != 1.0 ||
                                    exposeIcon != exposure[4][1]
                                ? true
                                : false,
                            child: Positioned(
                              bottom: MediaQuery.of(context).size.height * 0.0,
                              left: MediaQuery.of(context).size.width * 0.37,
                              right: MediaQuery.of(context).size.width * 0.37,
                              child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white),
                                  onPressed: () {
                                    setState(() {
                                      _cameraController!
                                          .setZoomLevel(currentZoomLevel = 1.0);
                                      currIconPosition = 4;
                                      exposeIcon =
                                          exposure[currIconPosition][1];
                                      _cameraController!.setExposureOffset(
                                          exposure[currIconPosition][0]);
                                    });
                                  },
                                  child: Text(
                                    'Reset',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(color: Colors.black),
                                  )),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            GestureDetector(
                              onDoubleTap: () {
                                _animationControllerZoom.reset();
                                _animationControllerZoom.forward();
                                setState(() {
                                  currentZoomLevel = currentZoomLevel - 1;
                                  if (currentZoomLevel < 1) {
                                    currentZoomLevel = 1;
                                  }
                                  _cameraController!
                                      .setZoomLevel(currentZoomLevel);
                                });
                              },
                              onTap: () {
                                _animationControllerZoom.reset();
                                _animationControllerZoom.forward();
                                setState(() {
                                  currentZoomLevel = currentZoomLevel + 1;
                                  if (currentZoomLevel > maxZoom) {
                                    currentZoomLevel = 1;
                                  }
                                  _cameraController!
                                      .setZoomLevel(currentZoomLevel);
                                });
                              },
                              child: AnimatedBuilder(
                                animation: _animationZoom,
                                builder: (BuildContext context, Widget? child) {
                                  return Transform.scale(
                                    scale: _animationZoom.value * 0.2 + 1,
                                    child: Text(
                                      currentZoomLevel.toInt().toString() + "x",
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  );
                                },
                              ),
                            ),
                            IconButton(
                              onPressed: () async {
                                setState(() {
                                  if (_currentFlashMode == FlashMode.off ||
                                      _currentFlashMode == FlashMode.auto) {
                                    _currentFlashMode = FlashMode.torch;
                                    showSnackBar("Flash On");
                                  } else if (_currentFlashMode ==
                                      FlashMode.torch) {
                                    _currentFlashMode = FlashMode.off;
                                    showSnackBar("Flash Off");
                                  }
                                });

                                await _cameraController!
                                    .setFlashMode(_currentFlashMode!);
                              },
                              icon: _currentFlashMode == FlashMode.off ||
                                      _currentFlashMode == FlashMode.auto
                                  ? const Icon(Icons.flash_off_outlined)
                                  : const Icon(Icons.flash_on),
                              color: Colors.white,
                            ),
                            IconButton(
                                onPressed: () {
                                  var ele = exposure[
                                      (currIconPosition + 1) % exposure.length];
                                  setState(() {
                                    exposeIcon = ele[1];
                                    currIconPosition = currIconPosition + 1;
                                  });
                                  _cameraController!.setExposureOffset(ele[0]);
                                },
                                icon: exposeIcon),
                            IconButton(
                                onPressed: () {
                                  _animationControllerFocus.reset();
                                  _animationControllerFocus.forward();
                                  if (!canStartStream) {
                                    showSnackBar("Detecting Objects");
                                  }
                                  setState(() {
                                    canAutoFocus = !canAutoFocus;
                                    canStartStream = !canStartStream;
                                    startImageStream();
                                  });
                                },
                                icon: AnimatedBuilder(
                                    animation: _animationFocus,
                                    builder:
                                        (BuildContext context, Widget? child) {
                                      return Transform.scale(
                                        scale: _animationFocus.value * 0.1 + 1,
                                        child: Icon(
                                          canAutoFocus && canStartStream
                                              ? Icons.center_focus_weak
                                              : Icons
                                                  .center_focus_weak_outlined,
                                          color: canAutoFocus && canStartStream
                                              ? Colors.green
                                              : Colors.white,
                                        ),
                                      );
                                    })),
                          ],
                        ),
                      ),
                      SizedBox(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _isCameraInitialized = false;
                                });
                                initCamera(
                                  cameras[isRearCamera ? 1 : 0],
                                );
                                setState(() {
                                  loadModel();
                                  isRearCamera = !isRearCamera;
                                });
                              },
                              child: Container(
                                width: 65,
                                height: 65,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 1),
                                ),
                                child: Icon(
                                  isRearCamera
                                      ? Icons.camera_rear
                                      : Icons.camera_front,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                takePicture();
                              },
                              child: Stack(
                                alignment: Alignment.center,
                                children: const [
                                  Icon(
                                    Icons.circle,
                                    color: Color.fromARGB(45, 69, 68, 68),
                                    size: 100,
                                  ),
                                  Icon(
                                    Icons.circle_sharp,
                                    color: Color.fromARGB(255, 251, 250, 250),
                                    size: 80,
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                refreshCapturedImages();
                                Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) => GalleryPage(
                                                imagePaths: imagePaths)))
                                    .then((_) => refreshCapturedImages());
                              },
                              child: Container(
                                width: 65,
                                height: 65,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                  image: _cameraImageFile != null
                                      ? DecorationImage(
                                          image: FileImage(_cameraImageFile!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: Container(),
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  )
                : Container()),
      ),
    );
  }
}
