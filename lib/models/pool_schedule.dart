import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum PoolType {
  kids, // Dětský bazén
  pool25m, // 25m bazén
  pool50m // 50m bazén
}

enum WeekDay {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday,
  holiday,
}

class TimeSlot {
  final TimeOfDay start;
  final TimeOfDay end;

  const TimeSlot({
    required this.start,
    required this.end,
  });

  bool includesTime(TimeOfDay time) {
    final currentMinutes = time.hour * 60 + time.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  }

  // konverze pro firestore
  Map<String, dynamic> toMap() {
    return {
      'start': '${start.hour}:${start.minute}',
      'end': '${end.hour}:${end.minute}',
    };
  }

  // vytvoreni rozvrhu z firestore dat
  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    final startParts = (map['start'] as String).split(':');
    final endParts = (map['end'] as String).split(':');
    return TimeSlot(
      start: TimeOfDay(
        hour: int.parse(startParts[0]),
        minute: int.parse(startParts[1]),
      ),
      end: TimeOfDay(
        hour: int.parse(endParts[0]),
        minute: int.parse(endParts[1]),
      ),
    );
  }
}

class DailySchedule {
  final List<TimeSlot> timeSlots;

  const DailySchedule(this.timeSlots);

  bool isOpenAt(TimeOfDay time) {
    return timeSlots.any((slot) => slot.includesTime(time));
  }

  // konverze pro Firestore
  Map<String, dynamic> toMap() {
    return {
      'timeSlots': timeSlots.map((slot) => slot.toMap()).toList(),
    };
  }

  // vytvoreni z firebase dat
  factory DailySchedule.fromMap(Map<String, dynamic> map) {
    final slots = (map['timeSlots'] as List)
        .map((slot) => TimeSlot.fromMap(slot as Map<String, dynamic>))
        .toList();
    return DailySchedule(slots);
  }
}

class PoolSchedules {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static Map<PoolType, Map<WeekDay, DailySchedule>>? _cachedSchedules;

  // nacteni rozvrhu z firestore
  static Future<Map<PoolType, Map<WeekDay, DailySchedule>>>
      getSchedules() async {
    if (_cachedSchedules != null) {
      return _cachedSchedules!;
    }

    final schedules = <PoolType, Map<WeekDay, DailySchedule>>{};

    for (var poolType in PoolType.values) {
      final poolDoc = await _firestore
          .collection('pool_schedules')
          .doc(poolType.toString().split('.').last)
          .get();

      if (!poolDoc.exists) {
        // pokud neexistuje, vytvari se rozvrh
        await _createDefaultSchedule(poolType);
        continue;
      }

      final poolData = poolDoc.data()!;
      final weekSchedule = <WeekDay, DailySchedule>{};

      for (var day in WeekDay.values) {
        final dayKey = day.toString().split('.').last;
        if (poolData.containsKey(dayKey)) {
          weekSchedule[day] =
              DailySchedule.fromMap(poolData[dayKey] as Map<String, dynamic>);
        }
      }

      schedules[poolType] = weekSchedule;
    }

    _cachedSchedules = schedules;
    return schedules;
  }

  // vychozi rozvrh z databaze
  static Future<void> _createDefaultSchedule(PoolType poolType) async {
    final defaultSchedule = _getDefaultSchedule(poolType);

    final Map<String, dynamic> scheduleMap = {};
    defaultSchedule.forEach((day, schedule) {
      scheduleMap[day.toString().split('.').last] = schedule.toMap();
    });

    await _firestore
        .collection('pool_schedules')
        .doc(poolType.toString().split('.').last)
        .set(scheduleMap);
  }

  // Rozvrhy pro jednotlive bazeny
  static Map<WeekDay, DailySchedule> _getDefaultSchedule(PoolType poolType) {
    switch (poolType) {
      case PoolType.kids:
        return {
          WeekDay.monday: const DailySchedule([
            TimeSlot(
              start: TimeOfDay(hour: 14, minute: 0),
              end: TimeOfDay(hour: 20, minute: 0),
            ),
          ]),
          WeekDay.tuesday: const DailySchedule([
            TimeSlot(
              start: TimeOfDay(hour: 14, minute: 0),
              end: TimeOfDay(hour: 15, minute: 30),
            ),
            TimeSlot(
              start: TimeOfDay(hour: 18, minute: 0),
              end: TimeOfDay(hour: 20, minute: 0),
            ),
          ]),
          WeekDay.wednesday: const DailySchedule([
            TimeSlot(
              start: TimeOfDay(hour: 14, minute: 0),
              end: TimeOfDay(hour: 16, minute: 0),
            ),
            TimeSlot(
              start: TimeOfDay(hour: 18, minute: 0),
              end: TimeOfDay(hour: 20, minute: 0),
            ),
          ]),
          WeekDay.thursday: const DailySchedule([
            TimeSlot(
              start: TimeOfDay(hour: 14, minute: 0),
              end: TimeOfDay(hour: 16, minute: 0),
            ),
            TimeSlot(
              start: TimeOfDay(hour: 18, minute: 0),
              end: TimeOfDay(hour: 20, minute: 0),
            ),
          ]),
          WeekDay.friday: const DailySchedule([
            TimeSlot(
              start: TimeOfDay(hour: 13, minute: 30),
              end: TimeOfDay(hour: 16, minute: 0),
            ),
            TimeSlot(
              start: TimeOfDay(hour: 18, minute: 0),
              end: TimeOfDay(hour: 20, minute: 0),
            ),
          ]),
          WeekDay.saturday: const DailySchedule([
            TimeSlot(
              start: TimeOfDay(hour: 9, minute: 0),
              end: TimeOfDay(hour: 19, minute: 0),
            ),
          ]),
          WeekDay.sunday: const DailySchedule([
            TimeSlot(
              start: TimeOfDay(hour: 9, minute: 0),
              end: TimeOfDay(hour: 19, minute: 0),
            ),
          ]),
          WeekDay.holiday: const DailySchedule([
            TimeSlot(
              start: TimeOfDay(hour: 9, minute: 0),
              end: TimeOfDay(hour: 19, minute: 0),
            ),
          ]),
        };
      case PoolType.pool25m:
        return {
          WeekDay.monday: const DailySchedule([]),
          WeekDay.tuesday: const DailySchedule([]),
          WeekDay.wednesday: const DailySchedule([]),
          WeekDay.thursday: const DailySchedule([]),
          WeekDay.friday: const DailySchedule([]),
          WeekDay.saturday: const DailySchedule([
            TimeSlot(
              start: TimeOfDay(hour: 11, minute: 0),
              end: TimeOfDay(hour: 19, minute: 0),
            ),
          ]),
          WeekDay.sunday: const DailySchedule([
            TimeSlot(
              start: TimeOfDay(hour: 9, minute: 0),
              end: TimeOfDay(hour: 18, minute: 0),
            ),
          ]),
          WeekDay.holiday: const DailySchedule([
            TimeSlot(
              start: TimeOfDay(hour: 11, minute: 0),
              end: TimeOfDay(hour: 19, minute: 0),
            ),
          ]),
        };
      case PoolType.pool50m:
        return {
          WeekDay.monday: const DailySchedule([
            TimeSlot(
              start: TimeOfDay(hour: 6, minute: 0),
              end: TimeOfDay(hour: 21, minute: 0),
            ),
          ]),
          WeekDay.tuesday: const DailySchedule([
            TimeSlot(
              start: TimeOfDay(hour: 6, minute: 0),
              end: TimeOfDay(hour: 21, minute: 0),
            ),
          ]),
          WeekDay.wednesday: const DailySchedule([
            TimeSlot(
              start: TimeOfDay(hour: 6, minute: 0),
              end: TimeOfDay(hour: 21, minute: 0),
            ),
          ]),
          WeekDay.thursday: const DailySchedule([
            TimeSlot(
              start: TimeOfDay(hour: 6, minute: 0),
              end: TimeOfDay(hour: 21, minute: 0),
            ),
          ]),
          WeekDay.friday: const DailySchedule([
            TimeSlot(
              start: TimeOfDay(hour: 6, minute: 0),
              end: TimeOfDay(hour: 21, minute: 0),
            ),
          ]),
          WeekDay.saturday: const DailySchedule([
            TimeSlot(
              start: TimeOfDay(hour: 9, minute: 0),
              end: TimeOfDay(hour: 20, minute: 0),
            ),
          ]),
          WeekDay.sunday: const DailySchedule([
            TimeSlot(
              start: TimeOfDay(hour: 9, minute: 0),
              end: TimeOfDay(hour: 20, minute: 0),
            ),
          ]),
          WeekDay.holiday: const DailySchedule([
            TimeSlot(
              start: TimeOfDay(hour: 9, minute: 0),
              end: TimeOfDay(hour: 20, minute: 0),
            ),
          ]),
        };
    }
  }

  static Future<bool> isPoolOpenAt(
      PoolType pool, WeekDay day, TimeOfDay time) async {
    final schedules = await getSchedules();
    return schedules[pool]?[day]?.isOpenAt(time) ?? false;
  }

  static Future<TimeOfDay> getEarliestOpeningTime(WeekDay day) async {
    final schedules = await getSchedules();
    TimeOfDay earliest = const TimeOfDay(hour: 23, minute: 59);

    for (var pool in PoolType.values) {
      final schedule = schedules[pool]?[day];
      if (schedule != null) {
        for (var slot in schedule.timeSlots) {
          final slotStart = slot.start;
          if (_compareTimeOfDay(slotStart, earliest) < 0) {
            earliest = slotStart;
          }
        }
      }
    }

    return earliest;
  }

  static Future<TimeOfDay> getLatestClosingTime(WeekDay day) async {
    final schedules = await getSchedules();
    TimeOfDay latest = const TimeOfDay(hour: 0, minute: 0);

    for (var pool in PoolType.values) {
      final schedule = schedules[pool]?[day];
      if (schedule != null) {
        for (var slot in schedule.timeSlots) {
          final slotEnd = slot.end;
          if (_compareTimeOfDay(slotEnd, latest) > 0) {
            latest = slotEnd;
          }
        }
      }
    }

    return latest;
  }

  static int _compareTimeOfDay(TimeOfDay a, TimeOfDay b) {
    final aMinutes = a.hour * 60 + a.minute;
    final bMinutes = b.hour * 60 + b.minute;
    return aMinutes - bMinutes;
  }
}
