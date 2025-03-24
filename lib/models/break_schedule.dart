import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pool_schedule.dart';
import '../pages/break_scheduler_page.dart';

class BreakSchedule {
  final String id;
  final DateTime date;
  final WeekDay weekDay;
  final List<BreakScheduleItem> breaks;
  final DateTime createdAt;
  final DateTime validUntil;

  BreakSchedule({
    required this.id,
    required this.date,
    required this.weekDay,
    required this.breaks,
    required this.createdAt,
    required this.validUntil,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': Timestamp.fromDate(date),
      'weekDay': weekDay.toString().split('.').last,
      'breaks': breaks.map((b) => b.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'validUntil': Timestamp.fromDate(validUntil),
    };
  }

  factory BreakSchedule.fromMap(Map<String, dynamic> map) {
    try {
      final weekDayStr = map['weekDay'] as String;
      WeekDay weekDay;
      try {
        final cleanWeekDay =
            weekDayStr.contains('.') ? weekDayStr.split('.').last : weekDayStr;

        weekDay = WeekDay.values.firstWhere(
          (e) =>
              e.toString().split('.').last.toLowerCase() ==
              cleanWeekDay.toLowerCase(),
          orElse: () {
            print(
                '❌ Neplatná hodnota WeekDay v databázi: $weekDayStr, používám výchozí hodnotu');
            return WeekDay.monday;
          },
        );
      } catch (e) {
        print('❌ Chyba při zpracování WeekDay: $e');
        weekDay = WeekDay.monday;
      }

      List<BreakScheduleItem> breaksList = [];
      try {
        final breaksData = map['breaks'] as List<dynamic>;
        if (breaksData.isNotEmpty) {
          if (breaksData[0] is Map<String, dynamic>) {
            breaksList = breaksData
                .map((b) =>
                    BreakScheduleItem.tryFromMap(b as Map<String, dynamic>))
                .where((item) => item != null)
                .cast<BreakScheduleItem>()
                .toList();
          } else {
            print('❌ Neplatný formát dat pauz v databázi');
          }
        }
      } catch (e) {
        print('❌ Chyba při zpracování seznamu pauz: $e');
      }

      return BreakSchedule(
        id: map['id']?.toString() ?? '',
        date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        weekDay: weekDay,
        breaks: breaksList,
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        validUntil:
            (map['validUntil'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    } catch (e, stackTrace) {
      print('❌ Chyba při deserializaci rozvrhu: $e');
      print('Stack trace: $stackTrace');
      print('Data z databáze: $map');
      rethrow;
    }
  }
}

class BreakScheduleItem {
  final String lifeguardName;
  final DateTime startTime;
  final DateTime endTime;
  final PoolType assignedPool;
  final ShiftType shiftType;

  BreakScheduleItem({
    required this.lifeguardName,
    required this.startTime,
    required this.endTime,
    required this.assignedPool,
    required this.shiftType,
  });

  Map<String, dynamic> toMap() {
    return {
      'lifeguardName': lifeguardName,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'assignedPool': assignedPool.toString().split('.').last,
      'shiftType': shiftType.toString().split('.').last,
    };
  }

  static BreakScheduleItem? tryFromMap(Map<String, dynamic> map) {
    try {
      final poolTypeStr = map['assignedPool'] as String;
      final cleanPoolType =
          poolTypeStr.contains('.') ? poolTypeStr.split('.').last : poolTypeStr;

      final assignedPool = PoolType.values.firstWhere(
        (e) =>
            e.toString().split('.').last.toLowerCase() ==
            cleanPoolType.toLowerCase(),
        orElse: () => PoolType.pool50m,
      );

      final shiftTypeStr = map['shiftType'] as String;
      final cleanShiftType = shiftTypeStr.contains('.')
          ? shiftTypeStr.split('.').last
          : shiftTypeStr;

      final shiftType = ShiftType.values.firstWhere(
        (e) =>
            e.toString().split('.').last.toLowerCase() ==
            cleanShiftType.toLowerCase(),
        orElse: () => ShiftType.fullDay,
      );

      return BreakScheduleItem(
        lifeguardName: map['lifeguardName']?.toString() ?? '',
        startTime: (map['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
        endTime: (map['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
        assignedPool: assignedPool,
        shiftType: shiftType,
      );
    } catch (e) {
      print('❌ Chyba při deserializaci položky rozvrhu: $e');
      print('Data položky: $map');
      return null;
    }
  }

  factory BreakScheduleItem.fromMap(Map<String, dynamic> map) {
    final item = tryFromMap(map);
    if (item == null) {
      throw FormatException('Neplatná data pro BreakScheduleItem: $map');
    }
    return item;
  }
}
