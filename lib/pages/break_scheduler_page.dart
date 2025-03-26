import 'package:flutter/material.dart';
import '../models/pool_schedule.dart';
import '../models/break_schedule.dart';
import '../services/break_schedule_service.dart';

enum ShiftType {
  fullDay, // 8:45 - 20:15
  morning, // 5:30 - 13:15
  afternoon // 13:15 - 21:15
}

class Break {
  final DateTime startTime;
  final DateTime endTime;
  final String lifeguardName;
  final PoolType assignedPool;

  Break({
    required this.startTime,
    required this.endTime,
    required this.lifeguardName,
    required this.assignedPool,
  });
}

class Lifeguard {
  final String name;
  final ShiftType shiftType;
  List<Break> breaks;
  late final TimeOfDay shiftStart;
  late final TimeOfDay shiftEnd;

  Lifeguard({
    required this.name,
    required this.shiftType,
  }) : breaks = [] {
    switch (shiftType) {
      case ShiftType.morning:
        shiftStart = const TimeOfDay(hour: 5, minute: 30);
        shiftEnd = const TimeOfDay(hour: 13, minute: 15);
        break;
      case ShiftType.afternoon:
        shiftStart = const TimeOfDay(hour: 13, minute: 15);
        shiftEnd = const TimeOfDay(hour: 21, minute: 15);
        break;
      case ShiftType.fullDay:
        shiftStart = const TimeOfDay(hour: 8, minute: 45);
        shiftEnd = const TimeOfDay(hour: 20, minute: 15);
        break;
    }
  }

  bool isAvailableAt(DateTime time) {
    final timeOfDay = TimeOfDay(hour: time.hour, minute: time.minute);
    final currentMinutes = timeOfDay.hour * 60 + timeOfDay.minute;
    final startMinutes = shiftStart.hour * 60 + shiftStart.minute;
    final endMinutes = shiftEnd.hour * 60 + shiftEnd.minute;

    // ranni smena
    if (shiftType == ShiftType.morning) {
      return currentMinutes >= 6 * 60 && currentMinutes < 13 * 60;
    }

    // odpoledni smena
    if (shiftType == ShiftType.afternoon) {
      return currentMinutes >= 13 * 60 + 15 && currentMinutes < 21 * 60 + 15;
    }

    // celodenni smena
    if (shiftType == ShiftType.fullDay) {
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    }

    return false;
  }

  bool isOnBreakAt(DateTime time) {
    return breaks.any((breakTime) =>
        breakTime.startTime.isBefore(time.add(const Duration(minutes: 1))) &&
        breakTime.endTime.isAfter(time.subtract(const Duration(minutes: 1))));
  }

  bool canTakeBreakAt(DateTime time) {
    return false;
  }
}

class BreakSchedulerPage extends StatefulWidget {
  const BreakSchedulerPage({super.key});

  @override
  State<BreakSchedulerPage> createState() => _BreakSchedulerPageState();
}

class _BreakSchedulerPageState extends State<BreakSchedulerPage>
    with WidgetsBindingObserver {
  final List<Lifeguard> lifeguards = [];
  final TextEditingController _nameController = TextEditingController();
  ShiftType _selectedShift = ShiftType.fullDay;
  WeekDay? _selectedDay;
  bool _isGenerating = false;
  late DateTime _shiftStartTime;
  late DateTime _shiftEndTime;
  final Duration breakDuration = const Duration(minutes: 34);
  bool is50mOpen = true; // vychozi hodnota,  aktualizovana podle  stavu
  final BreakScheduleService _breakScheduleService = BreakScheduleService();
  String? _currentScheduleId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shiftStartTime = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day, 6, 0);
    _shiftEndTime = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day, 20, 15);
    _loadActiveBreakSchedule();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadActiveBreakSchedule();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadActiveBreakSchedule();
  }

  Future<void> _loadActiveBreakSchedule() async {
    print('\n=== KONTROLA STAVU PAUZ ===');
    final now = DateTime.now();
    print('Aktuální čas: ${now.hour}:${now.minute}');

    try {
      final activeSchedules = await _breakScheduleService
          .getActiveBreakSchedules()
          .catchError((error) {
        print('❌ Chyba při načítání rozvrhů: $error');
        return <BreakSchedule>[]; // prazdny seznam
      });

      print('Počet aktivních rozvrhů: ${activeSchedules.length}');

      if (activeSchedules.isEmpty) {
        print(
            'ℹ️ Žádný aktivní rozvrh nenalezen - to je normální stav při prvním spuštění');
        _clearScheduleState();
        return;
      }

      // hledani platneho vygenerovaneho rozvrhu
      BreakSchedule? todaySchedule;
      for (var schedule in activeSchedules) {
        if (!_isValidSchedule(schedule)) {
          print('❌ Neplatný formát rozvrhu');
          continue;
        }

        print('\nKontroluji rozvrh:');
        print('- ID: ${schedule.id}');
        print('- Den v týdnu: ${schedule.weekDay}');
        print(
            '- Platnost do: ${schedule.validUntil.hour}:${schedule.validUntil.minute}');
        print(
            '- Datum: ${schedule.date.day}.${schedule.date.month}.${schedule.date.year}');

        if (!_isScheduleForToday(schedule, now)) {
          print('❌ Rozvrh neodpovídá dnešnímu dni');
          print('Schedule datum: ${schedule.date}');
          print('Aktuální datum: $now');
          continue;
        }

        final validUntilMinutes =
            schedule.validUntil.hour * 60 + schedule.validUntil.minute;
        final currentMinutes = now.hour * 60 + now.minute;

        if (currentMinutes > validUntilMinutes) {
          print('❌ Rozvrh již není platný - vypršel čas platnosti');
          print('- Aktuální čas: $currentMinutes minut');
          print('- Platný do: $validUntilMinutes minut');
          continue;
        }

        print('✅ Rozvrh je platný pro dnešní den a čas!');
        todaySchedule = schedule;
        break;
      }

      if (todaySchedule == null) {
        print('\n❌ Žádný aktivní rozvrh pro dnešní den nebyl nalezen');
        _clearScheduleState();
        return;
      }

      // Validace vsedniho dne
      if (!_isValidWeekDay(todaySchedule.weekDay)) {
        print('❌ Neplatná hodnota WeekDay: ${todaySchedule.weekDay}');
        _clearScheduleState();
        return;
      }

      print('\n=== NAČÍTÁM PLATNÝ ROZVRH PAUZ ===');
      print('ID rozvrhu: ${todaySchedule.id}');
      print('Počet pauz: ${todaySchedule.breaks.length}');
      print('Platnost do: ${_formatDateTime(todaySchedule.validUntil)}');

      // serazeni pauz podle plavciku id
      final Map<String, List<BreakScheduleItem>> breaksByLifeguard = {};
      for (var breakItem in todaySchedule.breaks) {
        if (!breaksByLifeguard.containsKey(breakItem.lifeguardName)) {
          breaksByLifeguard[breakItem.lifeguardName] = [];
        }
        breaksByLifeguard[breakItem.lifeguardName]!.add(breakItem);
      }

      setState(() {
        _currentScheduleId = todaySchedule!.id;
        _selectedDay = todaySchedule.weekDay;
        lifeguards.clear();

        // Vytvoreni plavciku a pauz
        for (var entry in breaksByLifeguard.entries) {
          if (entry.value.isEmpty) {
            print('⚠️ Varování: Prázdný seznam pauz pro plavčíka ${entry.key}');
            continue;
          }

          final firstBreak = entry.value.first;

          final lifeguard = Lifeguard(
            name: entry.key,
            shiftType: firstBreak.shiftType,
          );

          for (var breakItem in entry.value) {
            lifeguard.breaks.add(Break(
              startTime: breakItem.startTime,
              endTime: breakItem.endTime,
              lifeguardName: breakItem.lifeguardName,
              assignedPool: breakItem.assignedPool,
            ));
          }

          lifeguards.add(lifeguard);
          _logLifeguardInfo(lifeguard);
        }
      });

      print('\n=== ROZVRH ÚSPĚŠNĚ NAČTEN ===\n');
    } catch (e, stackTrace) {
      print('❌ CHYBA PŘI NAČÍTÁNÍ ROZVRHU: $e');
      print('Stack trace: $stackTrace');
      _clearScheduleState();
    }
  }

  void _clearScheduleState() {
    setState(() {
      lifeguards.clear();
      _currentScheduleId = null;
      _selectedDay = null;
    });
  }

  bool _isValidSchedule(BreakSchedule? schedule) {
    if (schedule == null) return false;
    return true;
  }

  bool _isScheduleForToday(BreakSchedule schedule, DateTime now) {
    return schedule.date.year == now.year &&
        schedule.date.month == now.month &&
        schedule.date.day == now.day;
  }

  bool _isValidWeekDay(WeekDay? weekDay) {
    if (weekDay == null) return false;
    try {
      WeekDay.values.firstWhere((day) => day == weekDay);
      print('✅ WeekDay je platná hodnota: $weekDay');
      return true;
    } catch (e) {
      print('❌ WeekDay není platná hodnota: $weekDay');
      return false;
    }
  }

  void _logLifeguardInfo(Lifeguard lifeguard) {
    print('\nPlavčík: ${lifeguard.name}');
    print('Typ směny: ${lifeguard.shiftType}');
    print(
        'Směna: ${_formatTimeOfDay(lifeguard.shiftStart)} - ${_formatTimeOfDay(lifeguard.shiftEnd)}');
    print('Počet pauz: ${lifeguard.breaks.length}');
    for (var break_ in lifeguard.breaks) {
      print(
          '- ${_formatDateTime(break_.startTime)} - ${_formatDateTime(break_.endTime)}');
    }
  }

  Future<void> _saveBreakSchedule() async {
    if (_selectedDay == null || lifeguards.isEmpty) return;

    final now = DateTime.now();
    final schedule = BreakSchedule(
      id: _currentScheduleId ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      date: now,
      weekDay: _selectedDay!,
      breaks: lifeguards
          .expand((guard) => guard.breaks.map((break_) => BreakScheduleItem(
                lifeguardName: guard.name,
                startTime: break_.startTime,
                endTime: break_.endTime,
                assignedPool: break_.assignedPool,
                shiftType: guard.shiftType,
              )))
          .toList(),
      createdAt: now,
      validUntil: _selectedDay == WeekDay.saturday ||
              _selectedDay == WeekDay.sunday ||
              _selectedDay == WeekDay.holiday
          ? DateTime(now.year, now.month, now.day, 20, 15)
          : DateTime(now.year, now.month, now.day, 21, 15),
    );

    print('\n=== UKLÁDÁNÍ ROZVRHU PAUZ ===');
    print('ID rozvrhu: ${schedule.id}');
    print('Den: ${schedule.weekDay}');
    print(
        'Platnost do: ${schedule.validUntil.hour}:${schedule.validUntil.minute}');
    print('Počet pauz: ${schedule.breaks.length}');
    print('Pauzy:');
    for (var breakItem in schedule.breaks) {
      print(
          '- ${breakItem.lifeguardName}: ${breakItem.startTime.hour}:${breakItem.startTime.minute} - ${breakItem.endTime.hour}:${breakItem.endTime.minute} (${breakItem.shiftType})');
    }

    await _breakScheduleService.saveBreakSchedule(schedule);
    setState(() {
      _currentScheduleId = schedule.id;
    });
    print('=== ROZVRH ÚSPĚŠNĚ ULOŽEN ===\n');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SingleChildScrollView(
        child: Container(
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              // horni widget
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                      color: theme.colorScheme.secondary.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // vyber dne
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 300,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  left: -25,
                                  child: Container(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: const Text('Den:',
                                        style: TextStyle(fontSize: 16)),
                                  ),
                                ),
                                Container(
                                  width: 280,
                                  margin: const EdgeInsets.only(left: 20),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(4),
                                    color: Colors.white,
                                  ),
                                  child: DropdownButton<WeekDay>(
                                    value: _selectedDay,
                                    isExpanded: true,
                                    hint: const Text('Vyberte den'),
                                    items: WeekDay.values.map((day) {
                                      String label;
                                      switch (day) {
                                        case WeekDay.monday:
                                          label = 'Pondělí';
                                          break;
                                        case WeekDay.tuesday:
                                          label = 'Úterý';
                                          break;
                                        case WeekDay.wednesday:
                                          label = 'Středa';
                                          break;
                                        case WeekDay.thursday:
                                          label = 'Čtvrtek';
                                          break;
                                        case WeekDay.friday:
                                          label = 'Pátek';
                                          break;
                                        case WeekDay.saturday:
                                          label = 'Sobota';
                                          break;
                                        case WeekDay.sunday:
                                          label = 'Neděle';
                                          break;
                                        case WeekDay.holiday:
                                          label = 'Svátek';
                                          break;
                                      }
                                      return DropdownMenuItem(
                                        value: day,
                                        child: Text(label),
                                      );
                                    }).toList(),
                                    onChanged: (WeekDay? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          _selectedDay = newValue;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(
                      color: Colors.grey,
                    ),
                    // pridani plavcika
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 300,
                              child: TextField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: 'Jméno plavčíka',
                                  border: const OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.grey),
                                  ),
                                  enabledBorder: const OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.grey),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 300,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                  color: Colors.white,
                                ),
                                child: DropdownButton<ShiftType>(
                                  value: _selectedShift,
                                  isExpanded: true,
                                  items: ShiftType.values.map((shift) {
                                    String label;
                                    switch (shift) {
                                      case ShiftType.fullDay:
                                        label = 'Celý den (8:45 - 20:15)';
                                        break;
                                      case ShiftType.morning:
                                        label = 'Ranní (5:30 - 13:15)';
                                        break;
                                      case ShiftType.afternoon:
                                        label = 'Odpolední (13:15 - 21:15)';
                                        break;
                                    }
                                    return DropdownMenuItem(
                                      value: shift,
                                      child: Text(label),
                                    );
                                  }).toList(),
                                  onChanged: (ShiftType? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _selectedShift = newValue;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _addLifeguard,
                              icon: const Icon(Icons.add),
                              label: const Text('Přidat'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // seznam pridanych plavciku
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: lifeguards.length,
                              itemBuilder: (context, index) {
                                final guard = lifeguards[index];
                                String shiftLabel;
                                switch (guard.shiftType) {
                                  case ShiftType.fullDay:
                                    shiftLabel = 'Celý den';
                                    break;
                                  case ShiftType.morning:
                                    shiftLabel = 'Ranní';
                                    break;
                                  case ShiftType.afternoon:
                                    shiftLabel = 'Odpolední';
                                    break;
                                }

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: ListTile(
                                    title: Text(guard.name),
                                    subtitle: Text(
                                        '$shiftLabel (${_formatTimeOfDay(guard.shiftStart)} - ${_formatTimeOfDay(guard.shiftEnd)})'),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _removeLifeguard(guard),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (lifeguards.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed:
                                        _isGenerating ? null : _generateBreaks,
                                    icon: const Icon(Icons.schedule),
                                    label: Text(_isGenerating
                                        ? 'Generuji...'
                                        : 'Vygenerovat pauzy'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Theme.of(context).colorScheme.primary,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // spodni widget
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                      color: theme.colorScheme.secondary.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.schedule, color: Colors.black, size: 28),
                        SizedBox(width: 10),
                        Text(
                          'Rozpis pauz',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 400),
                      child: _buildBreakSchedule(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreakSchedule() {
    final theme = Theme.of(context);

    if (lifeguards.isEmpty) {
      return const Center(
        child: Text(
          'Přidejte plavčíky pro vygenerování rozpisu pauz',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    // ziskani pauz a serazeni podle casu
    final allBreaks = lifeguards
        .expand((guard) =>
            guard.breaks.map((breakTime) => MapEntry(guard, breakTime)))
        .toList()
      ..sort((a, b) {
        // serazeni cas
        int timeCompare = a.value.startTime.compareTo(b.value.startTime);
        if (timeCompare != 0) return timeCompare;

        // serazeni index
        int guardIndexA = lifeguards.indexOf(a.key);
        int guardIndexB = lifeguards.indexOf(b.key);
        return guardIndexA.compareTo(guardIndexB);
      });

    if (allBreaks.isEmpty) {
      return const Center(
        child: Text(
          'Klikněte na "Vygenerovat pauzy" pro vytvoření rozpisu',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: allBreaks.length,
      itemBuilder: (context, index) {
        final entry = allBreaks[index];
        final guard = entry.key;
        final breakTime = entry.value;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              child: Text(
                '${index + 1}',
                style: TextStyle(color: theme.colorScheme.onPrimary),
              ),
            ),
            title: Text(guard.name),
            subtitle: Text(
              '${_formatDateTime(breakTime.startTime)} - ${_formatDateTime(breakTime.endTime)}',
            ),
            trailing: Text(
              guard.shiftType == ShiftType.fullDay
                  ? 'Celý den'
                  : guard.shiftType == ShiftType.morning
                      ? 'Ranní'
                      : 'Odpolední',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  void _addLifeguard() {
    if (_nameController.text.trim().isEmpty) return;

    setState(() {
      lifeguards.add(Lifeguard(
        name: _nameController.text.trim(),
        shiftType: _selectedShift,
      ));
      _nameController.clear();
    });
  }

  void _removeLifeguard(Lifeguard guard) {
    setState(() {
      lifeguards.remove(guard);
    });
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDateTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  DateTime? _getFixedBreakTime(DateTime currentTime) {
    final currentMinutes = currentTime.hour * 60 + currentTime.minute;

    // Specialne utery
    if (_selectedDay == WeekDay.tuesday) {
      if (currentMinutes >= 15 * 60 + 30 && currentMinutes < 18 * 60) {
        // pevne pauzy
        if (currentMinutes < 16 * 60 + 10) {
          return DateTime(
            currentTime.year,
            currentTime.month,
            currentTime.day,
            15,
            35,
          );
        } else if (currentMinutes < 16 * 60 + 45) {
          return DateTime(
            currentTime.year,
            currentTime.month,
            currentTime.day,
            16,
            10,
          );
        } else if (currentMinutes < 17 * 60 + 20) {
          return DateTime(
            currentTime.year,
            currentTime.month,
            currentTime.day,
            16,
            45,
          );
        } else if (currentMinutes < 18 * 60) {
          return DateTime(
            currentTime.year,
            currentTime.month,
            currentTime.day,
            17,
            20,
          );
        }
      }
    }

    // Specialne streda ctvrtek patek
    if (_selectedDay == WeekDay.wednesday ||
        _selectedDay == WeekDay.thursday ||
        _selectedDay == WeekDay.friday) {
      if (currentMinutes >= 16 * 60 && currentMinutes < 18 * 60) {
        // Pevne pauzy
        if (currentMinutes < 16 * 60 + 45) {
          return DateTime(
            currentTime.year,
            currentTime.month,
            currentTime.day,
            16,
            10,
          );
        } else if (currentMinutes < 17 * 60 + 20) {
          return DateTime(
            currentTime.year,
            currentTime.month,
            currentTime.day,
            16,
            45,
          );
        } else if (currentMinutes < 18 * 60) {
          return DateTime(
            currentTime.year,
            currentTime.month,
            currentTime.day,
            17,
            20,
          );
        }
      }
    }

    return null;
  }

  bool _isKidsPoolClosed(WeekDay day, TimeOfDay time) {
    final minutes = time.hour * 60 + time.minute;

    if (day == WeekDay.tuesday) {
      // 15:30 - 18:00 pauzy navic protoze zavreno
      return minutes >= 15 * 60 + 30 && minutes < 18 * 60;
    }

    if (day == WeekDay.wednesday ||
        day == WeekDay.thursday ||
        day == WeekDay.friday) {
      // Ve stredu ctvrtek a patek je detsky bazen zavreny od 16:00 do 18:00
      return minutes >= 16 * 60 && minutes < 18 * 60;
    }

    return false;
  }

  int _getRequiredLifeguardsCount(DateTime time) {
    // Zakladni pocet pozadovanych plavciku
    int requiredGuards = 3;

    // Pokud je detsky bazen zavreny v urcenych casech muzeme snizit pocet pozadovanych plavciku
    if (_selectedDay != null &&
        _isKidsPoolClosed(
            _selectedDay!, TimeOfDay(hour: time.hour, minute: time.minute))) {
      requiredGuards--;
    }

    return requiredGuards;
  }

  int _getNextGuardIndex(List<Lifeguard> availableGuards, DateTime time) {
    if (availableGuards.isEmpty) {
      print('❌ Žádní dostupní plavčíci pro pauzu');
      return -1;
    }

    // hledani plavcika s nejmensim poctem pauz
    return lifeguards.indexOf(availableGuards.reduce((a, b) {
      if (a.breaks.length != b.breaks.length) {
        return a.breaks.length < b.breaks.length ? a : b;
      }
      // pokud maji stejny pocet, vybirame podle indexu
      return lifeguards.indexOf(a) < lifeguards.indexOf(b) ? a : b;
    }));
  }

  void _addFixedBreak(DateTime time) {
    // hledani dostupnych plavciku pro dany cas
    final availableGuards = lifeguards
        .where((guard) => guard.isAvailableAt(time) && !guard.isOnBreakAt(time))
        .toList();

    if (availableGuards.isEmpty) {
      print(
          '❌ Žádní dostupní plavčíci pro fixní pauzu v čase ${_formatDateTime(time)}');
      return;
    }

    // hledani indexu dalsiho plavcika v poradi
    var nextGuardIndex = _getNextGuardIndex(availableGuards, time);
    if (nextGuardIndex == -1) {
      print('❌ Nepodařilo se najít vhodného plavčíka pro pauzu');
      return;
    }

    var availableGuard = lifeguards[nextGuardIndex];
    availableGuard.breaks.add(Break(
      startTime: time,
      endTime: time.add(breakDuration),
      lifeguardName: availableGuard.name,
      assignedPool: is50mOpen ? PoolType.pool50m : PoolType.pool25m,
    ));

    print(
        '✅ Přidělena fixní pauza: ${availableGuard.name} (${_formatDateTime(time)} - ${_formatDateTime(time.add(breakDuration))})');
  }

  Future<void> _generateBreaks() async {
    if (_selectedDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nejdřív vyberte den'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      // reset existujicic pauz
      for (var guard in lifeguards) {
        guard.breaks.clear();
      }

      // kontrola vikendova/celodenni smena
      bool isWeekendFullDay = (_selectedDay == WeekDay.saturday ||
              _selectedDay == WeekDay.sunday ||
              _selectedDay == WeekDay.holiday) &&
          lifeguards.every((guard) => guard.shiftType == ShiftType.fullDay);

      if (isWeekendFullDay) {
        // implementace pro vikendove smeny
        var currentTime = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
          9,
          0,
        );

        final endTime = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
          19,
          10, // konec 19:10
        );

        print('\n=== ZAČÁTEK GENEROVÁNÍ PAUZ PRO VIKEND ===');
        print('Počet plavčíků: ${lifeguards.length}');
        print('Začátek generování: ${_formatDateTime(currentTime)}');
        print('Koncový čas: ${_formatDateTime(endTime)}');
        print('Pořadí plavčíků: ${lifeguards.map((g) => g.name).join(' -> ')}');

        const breakDuration = Duration(minutes: 34);
        const changeoverDuration = Duration(minutes: 1);
        int currentGuardIndex = 0;

        while (currentTime.isBefore(endTime)) {
          print('\n=== PAUZA ${_formatDateTime(currentTime)} ===');
          print('Aktuální čas: ${_formatDateTime(currentTime)}');
          print('Koncový čas: ${_formatDateTime(endTime)}');
          print(
              'Zbývající čas: ${endTime.difference(currentTime).inMinutes} minut');

          final bool is25mOpen = await PoolSchedules.isPoolOpenAt(
            PoolType.pool25m,
            _selectedDay!,
            TimeOfDay(hour: currentTime.hour, minute: currentTime.minute),
          );

          final bool is50mOpen = await PoolSchedules.isPoolOpenAt(
            PoolType.pool50m,
            _selectedDay!,
            TimeOfDay(hour: currentTime.hour, minute: currentTime.minute),
          );

          final bool isKidsPoolOpen = await PoolSchedules.isPoolOpenAt(
            PoolType.kids,
            _selectedDay!,
            TimeOfDay(hour: currentTime.hour, minute: currentTime.minute),
          );

          print('Stav bazénů:');
          print('- 50m: ${is50mOpen ? "otevřený" : "zavřený"}');
          print('- 25m: ${is25mOpen ? "otevřený" : "zavřený"}');
          print('- Dětský: ${isKidsPoolOpen ? "otevřený" : "zavřený"}');

          int requiredGuards = 0;
          if (is50mOpen) requiredGuards += 2;
          if (is25mOpen) requiredGuards += 1;
          if (isKidsPoolOpen && (is50mOpen || is25mOpen)) requiredGuards += 1;

          print('Potřebný počet plavčíků: $requiredGuards');

          var availableGuards = lifeguards
              .where((guard) =>
                  guard.isAvailableAt(currentTime) &&
                  !guard.isOnBreakAt(currentTime))
              .toList();

          print(
              'Dostupní plavčíci: ${availableGuards.map((g) => "${g.name}(${g.breaks.length}p)").join(', ')}');

          var returningGuards = lifeguards
              .where((guard) => guard.breaks.any(
                  (break_) => break_.endTime.isAtSameMomentAs(currentTime)))
              .toList();

          print(
              'Plavčíci vracející se z pauzy: ${returningGuards.map((g) => g.name).join(', ')}');

          availableGuards.addAll(returningGuards);
          availableGuards = availableGuards.toSet().toList();

          print('Celkový počet dostupných plavčíků: ${availableGuards.length}');

          int maxBreaksNow = availableGuards.length - requiredGuards;

          // specialni case pro sobotu pred tim nez se otevre 25
          if (_selectedDay == WeekDay.saturday &&
              currentTime.hour == 10 &&
              currentTime.minute == 45 &&
              !is25mOpen) {
            maxBreaksNow = 1; // 1 povolena pauza navic
            print(
                'Speciální případ: Před otevřením 25m bazénu - povolena pouze jedna pauza');
          }

          print(
              'Může jít na pauzu: $maxBreaksNow plavčíků (${availableGuards.length} dostupných - $requiredGuards požadovaných)');

          if (maxBreaksNow > 0) {
            var guardsForBreak = <Lifeguard>[];
            var tempIndex = currentGuardIndex;
            var count = 0;

            print('Hledám plavčíky pro pauzu od indexu: $currentGuardIndex');
            print('Aktuální plavčík: ${lifeguards[currentGuardIndex].name}');

            while (count < maxBreaksNow) {
              var guard = lifeguards[tempIndex];
              print('Kontroluji plavčíka: ${guard.name} (index: $tempIndex)');
              if (availableGuards.contains(guard)) {
                guardsForBreak.add(guard);
                count++;
                print('Přidán plavčík na pauzu: ${guard.name}');
              }
              tempIndex = (tempIndex + 1) % lifeguards.length;
            }

            print(
                'Plavčíci jdoucí na pauzu: ${guardsForBreak.map((g) => g.name).join(', ')}');

            for (var guard in guardsForBreak) {
              guard.breaks.add(Break(
                startTime: currentTime,
                endTime: currentTime.add(breakDuration),
                lifeguardName: guard.name,
                assignedPool: is50mOpen ? PoolType.pool50m : PoolType.pool25m,
              ));
              print(
                  'Přidělena pauza: ${guard.name} (${_formatDateTime(currentTime)} - ${_formatDateTime(currentTime.add(breakDuration))})');
            }

            currentGuardIndex = tempIndex;
            print('Nový index pro další pauzu: $currentGuardIndex');

            currentTime =
                currentTime.add(breakDuration).add(changeoverDuration);
            print('Posunut čas na: ${_formatDateTime(currentTime)}');
          } else {
            print('Není dostupný dostatek plavčíků pro pauzu');
            currentTime =
                currentTime.add(breakDuration).add(changeoverDuration);
            print('Posunut čas na: ${_formatDateTime(currentTime)}');
          }
        }
      } else {
        // implementace pro vsedni dny
        DateTime currentTime = _shiftStartTime;
        final shiftEndTime = _shiftEndTime;

        // fixni pauzy kdyz je zavreny decak
        if (_selectedDay == WeekDay.tuesday) {
          _addFixedBreakAtTime(DateTime(
            currentTime.year,
            currentTime.month,
            currentTime.day,
            15,
            35,
          ));
          _addFixedBreakAtTime(DateTime(
            currentTime.year,
            currentTime.month,
            currentTime.day,
            16,
            10,
          ));
          _addFixedBreakAtTime(DateTime(
            currentTime.year,
            currentTime.month,
            currentTime.day,
            16,
            45,
          ));
          _addFixedBreakAtTime(DateTime(
            currentTime.year,
            currentTime.month,
            currentTime.day,
            17,
            20,
          ));
        } else if (_selectedDay == WeekDay.wednesday ||
            _selectedDay == WeekDay.thursday ||
            _selectedDay == WeekDay.friday) {
          _addFixedBreakAtTime(DateTime(
            currentTime.year,
            currentTime.month,
            currentTime.day,
            16,
            10,
          ));
          _addFixedBreakAtTime(DateTime(
            currentTime.year,
            currentTime.month,
            currentTime.day,
            16,
            45,
          ));
          _addFixedBreakAtTime(DateTime(
            currentTime.year,
            currentTime.month,
            currentTime.day,
            17,
            20,
          ));
        }

        // generovani normalnich pauz
        while (currentTime.isBefore(shiftEndTime)) {
          // Kontrola přechodu mezi směnami
          if (currentTime.hour == 12 && currentTime.minute >= 30) {
            // Ukončení ranní směny v 12:59
            currentTime = DateTime(
              currentTime.year,
              currentTime.month,
              currentTime.day,
              12,
              59,
            );
          } else if (currentTime.hour == 13 && currentTime.minute < 35) {
            // Přeskočení na začátek odpolední směny v 13:35
            currentTime = DateTime(
              currentTime.year,
              currentTime.month,
              currentTime.day,
              13,
              35,
            );
          }

          is50mOpen = await PoolSchedules.isPoolOpenAt(
            PoolType.pool50m,
            _selectedDay!,
            TimeOfDay(hour: currentTime.hour, minute: currentTime.minute),
          );

          final availableGuards = lifeguards
              .where((guard) =>
                  guard.isAvailableAt(currentTime) &&
                  !guard.isOnBreakAt(currentTime))
              .toList();

          final requiredGuards = _getRequiredLifeguardsCount(currentTime);

          print('Celkový počet dostupných plavčíků: ${availableGuards.length}');

          final maxBreaksNow = availableGuards.length - requiredGuards;
          print(
              'Může jít na pauzu: $maxBreaksNow plavčíků (${availableGuards.length} dostupných - $requiredGuards požadovaných)');

          if (maxBreaksNow > 0 && availableGuards.isNotEmpty) {
            var nextGuardIndex =
                _getNextGuardIndex(availableGuards, currentTime);
            var availableGuard = lifeguards[nextGuardIndex];

            availableGuard.breaks.add(Break(
              startTime: currentTime,
              endTime: currentTime.add(breakDuration),
              lifeguardName: availableGuard.name,
              assignedPool: is50mOpen ? PoolType.pool50m : PoolType.pool25m,
            ));

            print(
                'Přidělena pauza: ${availableGuard.name} (${_formatDateTime(currentTime)} - ${_formatDateTime(currentTime.add(breakDuration))})');
          }

          currentTime = currentTime.add(const Duration(minutes: 35));
        }
      }

      // ulozeni rozvrhu
      await _saveBreakSchedule();

      // nacteni vygenerovaneho rozvrhu
      await _loadActiveBreakSchedule();

      // lognuti
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pauzy byly vygenerovány a uloženy'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Chyba při generování pauz: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chyba při generování pauz: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  void _addFixedBreakAtTime(DateTime time) {
    // hledani dostupnych plavciku pro ten dany cas
    final availableGuards = lifeguards
        .where((guard) => guard.isAvailableAt(time) && !guard.isOnBreakAt(time))
        .toList();

    if (availableGuards.isNotEmpty) {
      // hledani plavcika s nejmin poctem pauz
      var guardWithLeastBreaks = availableGuards.reduce((a, b) {
        if (a.breaks.length != b.breaks.length) {
          return a.breaks.length <= b.breaks.length ? a : b;
        }
        // pick podle indexu
        return lifeguards.indexOf(a) <= lifeguards.indexOf(b) ? a : b;
      });

      guardWithLeastBreaks.breaks.add(Break(
        startTime: time,
        endTime: time.add(breakDuration),
        lifeguardName: guardWithLeastBreaks.name,
        assignedPool: is50mOpen ? PoolType.pool50m : PoolType.pool25m,
      ));

      print(
          'Přidělena fixní pauza: ${guardWithLeastBreaks.name} (${_formatDateTime(time)} - ${_formatDateTime(time.add(breakDuration))})');
    }
  }
}
