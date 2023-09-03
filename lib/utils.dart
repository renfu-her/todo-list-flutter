import 'dart:collection';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

Dio dio = Dio();

class Event {
  final String title;
  int? isActive;

  Event(this.title, this.isActive);

  @override
  String toString() => title;
}

Future<LinkedHashMap<DateTime, List<Event>>> fetchEventsFromAPI() async {
  Dio dio = Dio();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? userId = prefs.getString('user_id');
  print(userId);
  final response = await dio
      .get('https://calendar-dev.dev-laravel.co/api/calendar/member/$userId');

  if (response.statusCode == 200) {
    if (response.data == null || !(response.data is Map)) {
      return LinkedHashMap<DateTime, List<Event>>(); // 返回一个空的LinkedHashMap
    }

    LinkedHashMap<DateTime, List<Event>> eventsMap =
        LinkedHashMap<DateTime, List<Event>>(
      equals: isSameDay,
      hashCode: getHashCode,
    );

    Map<String, dynamic> data = response.data;
    data.forEach((key, value) {
      DateTime date = DateTime.parse(key);
      // 修改以下行以從新的JSON格式中提取事件標題
      List<Event> events = (value as List)
          .map((e) => Event(e['title'].toString(), e['is_active'] ?? 0))
          .toList();

      eventsMap[date] = events;
    });

    return eventsMap;
  } else {
    throw Exception('Failed to load events from the API');
  }
}

/// Using a [LinkedHashMap] is highly recommended if you decide to use a map.
final kEvents = LinkedHashMap<DateTime, List<Event>>(
  equals: isSameDay,
  hashCode: getHashCode,
);

int getHashCode(DateTime key) {
  return key.day * 1000000 + key.month * 10000 + key.year;
}

/// Returns a list of [DateTime] objects from [first] to [last], inclusive.
List<DateTime> daysInRange(DateTime first, DateTime last) {
  final dayCount = last.difference(first).inDays + 1;
  return List.generate(
    dayCount,
    (index) => DateTime.utc(first.year, first.month, first.day + index),
  );
}

final kToday = DateTime.now();
final kFirstDay = DateTime(kToday.year, kToday.month - 3, kToday.day);
final kLastDay = DateTime(kToday.year, kToday.month + 3, kToday.day);
