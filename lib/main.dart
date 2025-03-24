import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:file_selector/file_selector.dart';
// import 'package:excel/excel.dart';
import 'package:guardsys/pages/chat_list_page.dart';
import 'package:guardsys/pages/break_scheduler_page.dart';
// import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:guardsys/widgets/cleaning_schedule_widget.dart';
import 'services/notifications.dart';
import 'package:guardsys/pages/UserProfileScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final logger = Logger();

Future<void> initializeApp() async {
  try {
    // nacitani .env souboru
    print('🔄 Načítám .env soubor...');
    try {
      await dotenv.load();
      print('✅ .env soubor načten (výchozí cesta)');
    } catch (e) {
      print(
          '⚠️ Nepodařilo se načíst .env z výchozí cesty, zkouším alternativní cesty...');

      try {
        await dotenv.load(fileName: ".env");
        print('✅ .env soubor načten (relativní cesta)');
      } catch (e) {
        print(
            '⚠️ Nepodařilo se načíst .env z relativní cesty, zkouším absolutní...');

        final String path = Directory.current.path;
        await dotenv.load(fileName: "$path/.env");
        print('✅ .env soubor načten (absolutní cesta: $path/.env)');
      }
    }

    // kontrola encryption klice
    final encryptionKey = dotenv.env['ENCRYPTION_KEY'];
    final encryptionIv = dotenv.env['ENCRYPTION_IV'];

    if (encryptionKey == null || encryptionKey.isEmpty) {
      throw Exception('ENCRYPTION_KEY není nastaven v .env souboru');
    }
    if (encryptionIv == null || encryptionIv.isEmpty) {
      throw Exception('ENCRYPTION_IV není nastaven v .env souboru');
    }

    print('✅ Šifrovací klíče jsou nastaveny');
    print('🔑 Délka ENCRYPTION_KEY: ${encryptionKey.length}');
    print('🔑 Délka ENCRYPTION_IV: ${encryptionIv.length}');

    // inicializace firebase
    print('🔄 Inicializace Firebase...');
    await Firebase.initializeApp();
    print('✅ Firebase Core inicializován');

    // inicializace firebase app check
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
    );
    print('✅ Firebase AppCheck inicializován');

    await Future.delayed(const Duration(milliseconds: 500));
    await FirebaseAuth.instance.authStateChanges().first;
    print('✅ Firebase Auth inicializován');

    print('✅ Všechny služby úspěšně inicializovány');
  } catch (e) {
    print('⛔ Chyba při inicializaci: $e');
    print('⛔ Stack trace: ${StackTrace.current}');
    rethrow; //  prace s chybou
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // inicializace notifikaci
  final notifications = Notifications();
  await notifications.initialize();

  await initializeApp();
  runApp(const MyApp());
}

// Definice barev aplikace
const primaryColor = Color(0xFF1565C0); // prime barva
const secondaryColor = Color(0xFF1565C0); // 2nd barva
const backgroundColor = Color(0xFFF5F6F8); // bg barva
const surfaceColor = Colors.white;
const accentColor = Color(0xFF1565C0);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GuardSys',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: backgroundColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          secondary: secondaryColor,
          background: backgroundColor,
          surface: surfaceColor,
          tertiary: accentColor,
          brightness: Brightness.light,
        ),
        cardTheme: CardTheme(
          color: surfaceColor,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: secondaryColor.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: secondaryColor.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: primaryColor),
          ),
        ),
      ),
      home: const MainPage(),
      routes: {
        '/breaks': (context) => const BreakSchedulerPage(),
      },
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 2; // default index - chatpage
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stranky aplikace
  final List<Widget> _pages = const [
    TimerPage(),
    HomePage(),
    ChatPage(),
  ];

  //prechod mezi strankama
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _openUserProfile() async {
    User? user = _auth.currentUser;
    if (user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ChatListPage()),
      );
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    final userData = userDoc.data();
    if (userData != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserProfileScreen(
            name: userData["name"] ?? "Neznámý uživatel",
            email: userData["email"] ?? user.email!,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Guard System',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: _openUserProfile,
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.timer, size: 30),
            label: 'Pauzovačka',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home, size: 30),
            label: 'Domů',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat, size: 30),
            label: 'Zprávy',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        backgroundColor: primaryColor,
        onTap: _onItemTapped,
      ),
    );
  }
}

class TimerPage extends StatelessWidget {
  const TimerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const BreakSchedulerPage();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? pdfPath;
  bool _isLoading = true;
  String _errorMessage = '';
  final TransformationController _transformationController =
      TransformationController();
  double _currentScale = 1.0; // snizeni def priblizeni
  PdfControllerPinch? _pdfController;

  @override
  void initState() {
    super.initState();
    logger.d('Inicializace HomePage');
    loadPdfFromFirebase();
    _transformationController.value = Matrix4.identity()..scale(_currentScale);
  }

  @override
  void dispose() {
    logger.d('Dispose HomePage');
    _transformationController.dispose();
    _pdfController?.dispose(); // cisteni pdf controlleru
    super.dispose();
  }

  void _zoomIn() {
    setState(() {
      if (_currentScale < 3.5) {
        _currentScale = (_currentScale + 0.5).clamp(1.0, 3.5);
        logger.d('Přiblížení na: $_currentScale');
        _updateTransformation();
      }
    });
  }

  void _zoomOut() {
    setState(() {
      if (_currentScale > 1.0) {
        _currentScale = (_currentScale - 0.5).clamp(1.0, 3.5);
        logger.d('Oddálení na: $_currentScale');
        _updateTransformation();
      }
    });
  }

  void _updateTransformation() {
    _transformationController.value = Matrix4.identity()..scale(_currentScale);
  }

  Future<void> loadPdfFromFirebase() async {
    try {
      final ref = FirebaseStorage.instance.ref().child('rozvrh.pdf');
      final url = await ref.getDownloadURL();

      // ulozeni pdf do local pameti
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/rozvrh.pdf');

      await Dio().download(url, tempFile.path);

      if (mounted) {
        setState(() {
          pdfPath = tempFile.path;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e.toString().contains('Permission denied')) {
            _errorMessage =
                'Tento dokument může vidět pouze přihlášený uživatel.';
          } else {
            _errorMessage = 'Chyba při načítání PDF: $e';
          }
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Column(
              children: [
                // PDF viewer sekce
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(15),
                            topRight: Radius.circular(15),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_month,
                                color: Colors.white, size: 28),
                            SizedBox(width: 12),
                            Text(
                              'Měsíční rozvrh',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 500,
                        child: _buildPdfView(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Sekce s uklidama
                const SizedBox(
                  height: 520,
                  child: CleaningScheduleWidget(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPdfView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Tento dokument může vidět pouze přihlášený uživatel',
              style: TextStyle(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ChatListPage()),
                );
              },
              icon: const Icon(Icons.login),
              label: const Text('Přihlásit se'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } else if (pdfPath != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          _pdfController ??= PdfControllerPinch(
            document: PdfDocument.openFile(pdfPath!),
          );

          return Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(15),
                    bottomRight: Radius.circular(15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromARGB(25, 0, 0, 0),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(15),
                    bottomRight: Radius.circular(15),
                  ),
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    boundaryMargin: const EdgeInsets.all(20),
                    minScale: 1.0,
                    maxScale: 3.5,
                    panEnabled: true,
                    onInteractionEnd: (details) {
                      final scale =
                          _transformationController.value.getMaxScaleOnAxis();
                      if (scale != _currentScale) {
                        setState(() => _currentScale = scale.clamp(1.0, 3.5));
                        logger.d('Nové měřítko po interakci: $_currentScale');
                      }
                    },
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 2.5,
                          height: MediaQuery.of(context).size.height * 1.5,
                          child: PdfViewPinch(controller: _pdfController!),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.zoom_in, color: Colors.white),
                        onPressed: _zoomIn,
                        tooltip: 'Přiblížit',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.zoom_out, color: Colors.white),
                        onPressed: _zoomOut,
                        tooltip: 'Oddálit',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    } else {
      return const Center(child: Text('PDF nenalezeno.'));
    }
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  @override
  Widget build(BuildContext context) {
    return const ChatListPage();
  }
}
