import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
// import 'package:file_selector/file_selector.dart';
// import 'package:excel/excel.dart';
import 'package:guardsys/pages/chat_list_page.dart';
// import 'package:guardsys/pages/login_page.dart';
// import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

final logger = Logger();

Future<void> initializeFirebase() async {
  try {
    print('🔄 Inicializace Firebase...');

    // Inicializace Firebase Core
    await Firebase.initializeApp();
    print('✅ Firebase Core inicializován');

    // Inicializace AppCheck
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
    );
    print('✅ Firebase AppCheck inicializován');

    // Inicializace Auth a čekání na první stav
    await Future.delayed(const Duration(milliseconds: 500));
    await FirebaseAuth.instance.authStateChanges().first;
    print('✅ Firebase Auth inicializován');

    print('✅ Všechny Firebase služby úspěšně inicializovány');
  } catch (e) {
    print('⛔ Chyba při inicializaci Firebase: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebase();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF03C39);

    return MaterialApp(
      title: 'Guard System',
      theme: ThemeData(
        scaffoldBackgroundColor:
            const Color(0xFFF0F0F0), // tmavší off-white barva
        colorScheme: ColorScheme.fromSeed(
          seedColor: backgroundColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 2; // Výchozí index je 2 (ChatPage)

  // Stranky aplikace
  final List<Widget> _pages = const [
    TimerPage(),
    HomePage(),
    ChatPage(),
  ];

  // Zmena vybrane stranky
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
        backgroundColor: const Color(0xFFF03C39),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.timer, size: 30),
            label: 'Pauzovacka',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home, size: 30),
            label: 'Domov',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat, size: 30),
            label: 'Chat',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        backgroundColor: const Color(0xFFF03C39),
        onTap: _onItemTapped,
      ),
    );
  }
}

class TimerPage extends StatelessWidget {
  const TimerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Pauzovacka',
        style: TextStyle(fontSize: 24),
      ),
    );
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

  @override
  void initState() {
    super.initState();
    loadPdfFromFirebase();
  }

  Future<void> loadPdfFromFirebase() async {
    try {
      final ref = FirebaseStorage.instance.ref().child('rozvrh.pdf');
      final url = await ref.getDownloadURL();

      // Uložení PDF do lokální paměti
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
          _errorMessage = 'Chyba při načítání PDF: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 7,
          child: Container(
            color: const Color(0xFFF0F0F0), // tmavší off-white barva pozadí
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.black,
                  width: 3,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromARGB(25, 0, 0, 0),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.schedule,
                        color: Colors.black,
                        size: 28,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Rozvrh',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _errorMessage.isNotEmpty
                            ? Center(
                                child: Text(
                                  _errorMessage,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              )
                            : pdfPath != null
                                ? LayoutBuilder(
                                    builder: (context, constraints) {
                                      final pdfController = PdfControllerPinch(
                                        document:
                                            PdfDocument.openFile(pdfPath!),
                                      );

                                      ValueNotifier<int> currentPage =
                                          ValueNotifier<int>(1);

                                      if ((pdfController.pagesCount ?? 0) > 0) {
                                        pdfController.pageListenable
                                            .addListener(() {
                                          final page = pdfController.page ?? 1;
                                          currentPage.value =
                                              (page > 0) ? page : 1;
                                        });
                                      }

                                      return Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          boxShadow: const [
                                            BoxShadow(
                                              color:
                                                  Color.fromARGB(25, 0, 0, 0),
                                              blurRadius: 10,
                                              offset: Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          child: InteractiveViewer(
                                            boundaryMargin:
                                                const EdgeInsets.all(20),
                                            minScale: 1.0,
                                            maxScale: 5.0,
                                            panEnabled: true,
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: SingleChildScrollView(
                                                scrollDirection: Axis.vertical,
                                                child: SizedBox(
                                                  width: MediaQuery.of(context)
                                                          .size
                                                          .width *
                                                      2.5,
                                                  height: MediaQuery.of(context)
                                                          .size
                                                          .height *
                                                      1.5,
                                                  child: PdfViewPinch(
                                                      controller:
                                                          pdfController),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : const Center(
                                    child: Text('PDF nenalezeno.'),
                                  ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Spodni widget s tabulkou
        Expanded(
          flex: 5,
          child: Container(
            color: const Color(0xFFF0F0F0), // tmavší off-white barva pozadí
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.black,
                  width: 3,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromARGB(25, 0, 0, 0),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cleaning_services, color: Colors.black),
                      SizedBox(width: 8),
                      Text(
                        'Úklidy',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(
                                label: Text('Den',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('Dětský bazén',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('50m',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('25m',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            DataColumn(
                                label: Text('Venek',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                          ],
                          rows: const [
                            DataRow(cells: [
                              DataCell(Text('Pondělí',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text('Oplach + Dezinfekce')),
                              DataCell(Text('Oplach + Dezinfekce')),
                              DataCell(Text('Oplach + Dezinfekce + VEDA')),
                              DataCell(Text('Oplach + Dezinfekce')),
                            ]),
                            DataRow(cells: [
                              DataCell(Text('Úterý',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text('VEDA')),
                              DataCell(Text('Oplach + VEDA')),
                              DataCell(Text('Oplach + VEDA + R:Balkon')),
                              DataCell(Text('Oplach + VEDA')),
                            ]),
                            DataRow(cells: [
                              DataCell(Text('Středa',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text('Chromy + Oplach')),
                              DataCell(Text('Chromy + Oplach')),
                              DataCell(
                                  Text('Oplach + VEDA + Chromy + R:Balkon')),
                              DataCell(Text('Dezinfekce + VEDA')),
                            ]),
                            DataRow(cells: [
                              DataCell(Text('Čtvrtek',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text('Oplach + Dezinfekce')),
                              DataCell(Text('Oplach + Dezinfekce + VEDA')),
                              DataCell(Text('Oplach + Dezinfekce + VEDA')),
                              DataCell(Text('Oplach')),
                            ]),
                            DataRow(cells: [
                              DataCell(Text('Pátek',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text('Oplach')),
                              DataCell(Text('Oplach')),
                              DataCell(Text('Oplach')),
                              DataCell(Text('Dezinfekce + VEDA')),
                            ]),
                            DataRow(cells: [
                              DataCell(Text('Sobota',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text('Oplach + Dezinfekce')),
                              DataCell(Text(
                                  'Oplach + Dezinfekce + VEDA + R:Plavčíkárna')),
                              DataCell(Text(
                                  'Oplach + Dezinfekce + VEDA + R:Balkon')),
                              DataCell(Text('Oplach + VEDA')),
                            ]),
                            DataRow(cells: [
                              DataCell(Text('Neděle',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text('Oplach + VEDA')),
                              DataCell(Text('Oplach')),
                              DataCell(Text('VEDA')),
                              DataCell(Text('Oplach')),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
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
