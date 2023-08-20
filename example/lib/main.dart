import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:example/firebase_options.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

Future<void> main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Explicit Content Extension Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.blue,
          ),
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Explicit Content Extension Demo'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const _Description(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  width: 1,
                  height: double.infinity,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                ),
              ),
              const _Demo(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Demo extends StatefulWidget {
  const _Demo();

  @override
  State<_Demo> createState() => _DemoState();
}

class _DemoState extends State<_Demo> {
  bool isLoading = false;
  Uint8List? imageBytes;
  String? sessionId;
  String? downloadUrl;
  String? status;
  String? firestoreDocData;
  StreamSubscription? firestoreSubscription;

  /// Sign in anonymously if the user is not signed in.
  ///
  /// Returns the user id.
  Future<String> maybeSignIn() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      final credentials = await FirebaseAuth.instance.signInAnonymously();
      return credentials.user!.uid;
    }
    return user.uid;
  }

  Future<void> uploadImage() async {
    try {
      sessionId = const Uuid().v4();
      final userId = await maybeSignIn();

      setState(() {
        status = 'Uploading image...';
      });

      final task = await FirebaseStorage.instance
          .ref('images/$userId/$sessionId')
          .putData(
            imageBytes!,
          );

      final downloadUrl = await task.ref.getDownloadURL();

      setState(() {
        this.downloadUrl = downloadUrl;
        isLoading = false;
        status =
            'Image uploaded. Checking for explicit content... If the image is not blurred in the next 15 seconds, it does not contain explicit content.';
      });

      FirebaseFirestore firestore = FirebaseFirestore.instance;
      firestoreSubscription = firestore
          .collection('ExplicitImages')
          .where(
            'fileName',
            isEqualTo: 'images/$userId/$sessionId',
          )
          .limit(1)
          .snapshots()
          .listen((event) {
        if (event.docs.isNotEmpty) {
          final doc = event.docs.single;
          setState(() {
            firestoreDocData = doc.get('safeSearchAnnotation').toString();
            status = 'Explicit content detected.';
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        status = 'Error: ${e.toString()}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    }
  }

  void reset() {
    setState(() {
      isLoading = false;
      imageBytes = null;
      sessionId = const Uuid().v4();
      firestoreSubscription?.cancel();
      downloadUrl = null;
      status = null;
      firestoreDocData = null;
    });
  }

  @override
  void dispose() {
    super.dispose();
    firestoreSubscription?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 600,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Demo',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Let\'s try it out! Upload an image or use the example and see what happens.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Tooltip(
                  message: 'File limit: 10 MB',
                  child: ElevatedButton(
                    onPressed: () async {
                      reset();

                      final file = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                        allowMultiple: false,
                      );

                      if (!mounted || file == null) {
                        return;
                      }

                      setState(() {
                        isLoading = true;
                        imageBytes = file.files.single.bytes;
                      });

                      await uploadImage();
                    },
                    child: const Text('Upload Image'),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    reset();

                    final exampleImageBytes = await rootBundle
                        .load('assets/adult-content-edit.png')
                        .then((value) => value.buffer.asUint8List());
                    setState(() {
                      isLoading = true;
                      imageBytes = exampleImageBytes;
                    });

                    await uploadImage();
                  },
                  child: const Text('Use Example'),
                ),
                const SizedBox(width: 12),
                if (imageBytes != null)
                  ElevatedButton(
                    onPressed: () => reset(),
                    child: const Text('Reset'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (imageBytes != null && downloadUrl == null)
              Image.memory(
                imageBytes!,
                height: 512,
              ),
            if (downloadUrl != null)
              Image.network(
                '${downloadUrl!}${firestoreDocData == null ? '' : '&reload'}',
                height: 512,
              ),
            if (isLoading) const Center(child: CircularProgressIndicator()),
            if (status != null) Text(status!),
            if (firestoreDocData != null) Text(firestoreDocData!),
          ],
        ),
      ),
    );
  }
}

class _Description extends StatelessWidget {
  const _Description();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 600,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What is the "Explicit Content Extension"?',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            MarkdownBody(
              data: '''
The explicit content extension detects explicit content in images. If explicit content is detected, the image will be blurred.

## What problem does it solve?

When building an app that allows users to upload images, you might want to prevent users from uploading explicit content. This extension helps you to do that without having to write any code.

## How does it work?

When the user uploads an image to Cloud Storage, a cloud function get's triggered. This cloud function sends the image to [Google Cloud Vision API](https://cloud.google.com/vision/docs/detecting-safe-search). If the image contains explicit content, it replaces the existing image and keeps the metadata (e.g. download URL, content disposition, etc.) of the original image. Additionally, it adds the metadata of the explicit image to a Firestore document. The Firestore document can be used to perform additional actions, e.g. to notify the user that the image was rejected, send a Slack/Discord notification to the admin, etc.

## How can I use it?

Just install the extension and it will work automatically.
''',
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                  fontSize: 16,
                ),
              ),
              onTapLink: (text, href, title) => launchUrl(Uri.parse(href!)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => launchUrl(
                Uri.parse(
                    'https://github.com/nilsreichardt/explicit-content-extension'),
              ),
              child: const Text('GitHub'),
            )
          ],
        ),
      ),
    );
  }
}
