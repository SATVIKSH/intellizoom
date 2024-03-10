import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:intellizoom/views/camera_view.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error in fetching the cameras: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'IntelliZoom',
      debugShowCheckedModeBanner: false,
      home: CameraPage(),
    );
  }
}
