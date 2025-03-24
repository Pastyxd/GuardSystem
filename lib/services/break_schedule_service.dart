import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/break_schedule.dart';

class BreakScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _lastScheduleIdKey = 'last_schedule_id';

  Future<void> saveBreakSchedule(BreakSchedule schedule) async {
    try {
      // Uložit rozvrh do Firestore
      await _firestore
          .collection('break_schedules')
          .doc(schedule.id)
          .set(schedule.toMap());

      // Uložit ID do SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastScheduleIdKey, schedule.id);

      print('✅ Rozvrh uložen s ID: ${schedule.id}');
    } catch (e) {
      print('❌ Chyba při ukládání rozvrhu: $e');
      rethrow;
    }
  }

  Future<String?> getLastScheduleId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_lastScheduleIdKey);
      print(id != null
          ? '✅ Nalezeno poslední ID rozvrhu: $id'
          : '❌ Nenalezeno žádné poslední ID rozvrhu');
      return id;
    } catch (e) {
      print('❌ Chyba při načítání posledního ID: $e');
      return null;
    }
  }

  Future<BreakSchedule?> getBreakSchedule(String id) async {
    try {
      final doc = await _firestore.collection('break_schedules').doc(id).get();
      if (doc.exists && doc.data() != null) {
        print('✅ Nalezen rozvrh s ID: $id');
        return BreakSchedule.fromMap(doc.data()!);
      }
      print('❌ Rozvrh s ID $id nebyl nalezen');
      return null;
    } catch (e) {
      print('❌ Chyba při načítání rozvrhu: $e');
      return null;
    }
  }

  Future<List<BreakSchedule>> getActiveBreakSchedules() async {
    try {
      // prvni nacitame posledni rozvrh
      final lastId = await getLastScheduleId();
      if (lastId != null) {
        final lastSchedule = await getBreakSchedule(lastId);
        if (lastSchedule != null) {
          final now = DateTime.now();
          if (lastSchedule.validUntil.isAfter(now)) {
            print('✅ Použití posledního aktivního rozvrhu');
            return [lastSchedule];
          }
        }
      }

      // pokud nemame posledni rozvrh nebo uz neni platny, nacteme vsechny aktivni(z nich last)
      final now = DateTime.now();
      final querySnapshot = await _firestore
          .collection('break_schedules')
          .where('validUntil', isGreaterThan: Timestamp.fromDate(now))
          .get();

      final schedules = querySnapshot.docs
          .map((doc) => BreakSchedule.fromMap(doc.data()))
          .where((schedule) => schedule != null)
          .toList();

      print('Nalezeno ${schedules.length} aktivních rozvrhů');
      return schedules;
    } catch (e) {
      print('❌ Chyba při načítání aktivních rozvrhů: $e');
      return [];
    }
  }

  Future<void> deleteExpiredBreakSchedules() async {
    try {
      final now = DateTime.now();
      final querySnapshot = await _firestore
          .collection('break_schedules')
          .where('validUntil', isLessThan: Timestamp.fromDate(now))
          .get();

      final batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      print('✅ Smazány expirované rozvrhy');
    } catch (e) {
      print('❌ Chyba při mazání expirovaných rozvrhů: $e');
    }
  }
}
