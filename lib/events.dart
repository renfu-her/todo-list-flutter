import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:ionicons/ionicons.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart';
import 'package:todo_list/utils.dart';
import 'package:todo_list/main.dart';
import 'package:todo_list/feedback.dart';
import 'package:add_2_calendar/add_2_calendar.dart' as cal;
import 'package:device_calendar/device_calendar.dart' as device_cal;
import 'package:timezone/data/latest.dart' as tz;

Dio dio = Dio();

void main() {
  initializeDateFormatting().then((_) => runApp(MyApp()));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calendar Example',
      theme: ThemeData(
        primarySwatch: Colors.lightGreen,
      ),
      home: StartPage(),
      routes: {
        '/main': (_) => LoginPage(),
        '/events': (_) => StartPage(),
      },
    );
  }
}

class StartPage extends StatefulWidget {
  @override
  _StartPageState createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  final _eventTitleController = TextEditingController();
  final _startDateController = TextEditingController();
  String? userId;

  late final ValueNotifier<List<Event>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  RangeSelectionMode _rangeSelectionMode = RangeSelectionMode.toggledOff;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();

    _initAsync();

    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));

    fetchEventsFromAPI().then((eventsFromAPI) {
      setState(() {
        kEvents.addAll(eventsFromAPI); // Make sure kEvents is not final anymore
        _selectedEvents.value = _getEventsForDay(_selectedDay!);
      });
    });
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  Future<void> _initAsync() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    userId = prefs.getString('user_id');
    if (token == null) {
      // 跳轉到 LoginPage
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  List<Event> _getEventsForDay(DateTime day) {
    // Implementation example
    return kEvents[day] ?? [];
  }

  List<Event> _getEventsForRange(DateTime start, DateTime end) {
    // Implementation example
    final days = daysInRange(start, end);

    return [
      for (final d in days) ..._getEventsForDay(d),
    ];
  }

  Future<void> updateEventAPI(DateTime focusDate, Event event) async {
    TextEditingController _controller =
        TextEditingController(text: event.toString());

    // print(focusDate.toString().substring(0, 10));
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => AlertDialog(
          title: Text('更新事件'),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 24.0), // You can adjust this padding
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(hintText: '请输入新的事件内容'),
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                ),
                SizedBox(height: 10), // Adding a little space between elements
                Row(
                  children: [
                    Text('是否完成'),
                    Switch(
                      value: event.isActive == 1 ? false : true,
                      onChanged: (value) {
                        setState(() {
                          event.isActive = value ? 0 : 1;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('取消'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('更新'),
              onPressed: () async {
                String updatedEvent = _controller.text;

                // 1. Call your API to update the event
                await dio.post(
                    'https://calendar-dev.dev-laravel.co/api/calendar/update',
                    data: {
                      'update_title': updatedEvent,
                      'start_date': focusDate.toString().substring(0, 10),
                      'title': event.toString(),
                      'is_active': event.isActive,
                    });

                // 2. Update local data (e.g., kEvents) and UI if necessary
                setState(() {
                  _reloadEvents();
                });

                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> deleteEventAPI(DateTime focusDate, Event event) async {
    // 在此处调用删除事件的API
    print('Delete event: $event ' + focusDate.toString().substring(0, 10));
    // 实际API调用可能类似于：
    // await dio.delete(
    //     'https://calendar-dev.dev-laravel.co/calendar/delete/${event.id}');
    print(event.toString());

    await dio.delete(
      'https://calendar-dev.dev-laravel.co/api/calendar/delete',
      data: {
        'start_date': focusDate.toString().substring(0, 10),
        'title': event.toString(),
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _rangeStart = null; // Important to clean those
        _rangeEnd = null;
        _rangeSelectionMode = RangeSelectionMode.toggledOff;
      });

      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  void _onRangeSelected(DateTime? start, DateTime? end, DateTime focusedDay) {
    setState(() {
      _selectedDay = null;
      _focusedDay = focusedDay;
      _rangeStart = start;
      _rangeEnd = end;
      _rangeSelectionMode = RangeSelectionMode.toggledOn;
    });

    // `start` or `end` could be null
    if (start != null && end != null) {
      _selectedEvents.value = _getEventsForRange(start, end);
    } else if (start != null) {
      _selectedEvents.value = _getEventsForDay(start);
    } else if (end != null) {
      _selectedEvents.value = _getEventsForDay(end);
    }
  }

  void _onAddEventButtonPressed() {
    // Set the _startDateController's value to the currently selected date
    _startDateController.text = _selectedDay != null
        ? '${_selectedDay!.year}-${_selectedDay!.month.toString().padLeft(2, '0')}-${_selectedDay!.day.toString().padLeft(2, '0')}'
        : '';
    bool _isActive = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => AlertDialog(
          title: Text('新增事件'),
          content: SingleChildScrollView(
            // 這裡加入 SingleChildScrollView
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _startDateController,
                  decoration: InputDecoration(
                    labelText: '日期',
                    hintText: '例如：2023-09-01',
                  ),
                  readOnly: true,
                ),
                TextField(
                  controller: _eventTitleController,
                  decoration: InputDecoration(
                    hintText: '事件名稱',
                  ),
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                ),
                Row(
                  children: [
                    Switch(
                      value: _isActive,
                      onChanged: (bool value) {
                        setState(() {
                          _isActive = value;
                        });
                      },
                    ),
                    Text('是否完成'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('取消'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('確認'),
              onPressed: () async {
                await _onSaveEventButtonPressed(_isActive);

                _startDateController.clear(); // Clear the controllers
                _eventTitleController.clear();

                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSaveEventButtonPressed(bool isActive) async {
    tz.initializeTimeZones();

    final Map<String, dynamic> eventData = {
      "start_date": _startDateController.text,
      "title": _eventTitleController.text,
      'member_id': userId,
      'days': 1,
      'full_day': 1,
      'is_active': isActive ? 0 : 1,
    };

    final response = await dio.post(
        'https://calendar-dev.dev-laravel.co/api/calendar/events',
        data: eventData);

    if (response.statusCode == 200) {
      await _reloadEvents();

      DateTime startOfDay = DateTime.parse(_startDateController.text).toLocal();
      DateTime endOfDay = DateTime(
          startOfDay.year, startOfDay.month, startOfDay.day, 23, 59, 59);

      final eventId = response.data['id'];

      device_cal.DeviceCalendarPlugin deviceCalendarPlugin =
          device_cal.DeviceCalendarPlugin();

      // 获取日历列表
      final calendarsResult = await deviceCalendarPlugin.retrieveCalendars();
      final calendars = calendarsResult.data;

      if (calendars == null || calendars.isEmpty) {
        print("No calendars available or permission not granted");
        return;
      }

      // 创建一个可修改的日历列表
      List<device_cal.Calendar> modifiableCalendars = List.from(calendars);

      // 查找第一个不是只读的日历
      device_cal.Calendar? firstCalendar = modifiableCalendars.firstWhere(
        (calendar) => calendar.isReadOnly!,
        orElse: () => calendars.first,
      );

      // 创建事件
      print('ID: ' + eventId.toString());
      print('ID:' + firstCalendar.id.toString());
      device_cal.Event event = device_cal.Event(
        firstCalendar.id,
        start: TZDateTime.from(startOfDay, getLocation('Asia/Taipei')),
        end: TZDateTime.from(endOfDay, getLocation('Asia/Taipei')),
        allDay: true,
        title: _eventTitleController.text,
      );

      // 添加事件到日历
      final createEventResult =
          await deviceCalendarPlugin.createOrUpdateEvent(event);
    } else {
      print('Error while adding event: ${response.data}');
    }
  }

  Future<void> _reloadEvents() async {
    final eventsFromAPI = await fetchEventsFromAPI();
    setState(() {
      kEvents.clear(); // 清除当前的事件
      kEvents.addAll(eventsFromAPI);
      // 更新当前选中日期的事件
      _selectedEvents.value = _getEventsForDay(_selectedDay!);
    });
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('token'); // This will remove the token
    await prefs.remove('user_id'); // This will remove the user_id

    // Navigate back to the login screen or whichever screen you deem appropriate post logout.
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> updateEventIsActiveAPI(
      DateTime focusDate, Event event, bool isActive) async {
    // 呼叫 API 來更新 isActive 的狀態
    await dio.post(
      'https://calendar-dev.dev-laravel.co/api/calendar/updateIsActive',
      data: {
        'start_date': focusDate.toString().substring(0, 10),
        'title': event.toString(),
        'is_active': isActive ? 1 : 0,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('日曆'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.logout), // Icon for logout
            onPressed: _logout,
            tooltip: '登出',
          ),
        ],
      ),
      drawer: Drawer(
        // 添加 Drawer
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              child: Text('選單', style: TextStyle(fontSize: 24)),
              decoration: BoxDecoration(
                color: Colors.lightGreen,
              ),
            ),
            ListTile(
              title: Text('回饋意見', style: TextStyle(fontSize: 20)),
              onTap: () {
                // 使用 Navigator 跳轉到 FeedbackPage
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FeedbackPage()),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          TableCalendar<Event>(
            locale: 'zh_CN',
            calendarBuilders: CalendarBuilders(
              dowBuilder: (context, day) {
                final text =
                    DateFormat.E('zh_CN').format(day); // 使用指定的語言代碼格式化日期

                if (day.weekday == DateTime.saturday ||
                    day.weekday == DateTime.sunday) {
                  return Center(
                    child: Text(
                      text,
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }

                return Center(child: Text(text)); // 其他的星期天將使用預設的顏色
              },
              defaultBuilder: (context, date, events) {
                return Center(
                  child: Text(
                    date.day.toString(),
                    style: TextStyle(
                      color: (date.weekday == DateTime.saturday ||
                              date.weekday == DateTime.sunday)
                          ? Colors.red
                          : null,
                    ),
                  ),
                );
              },
            ),
            firstDay: kFirstDay,
            lastDay: kLastDay,
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            rangeStartDay: _rangeStart,
            rangeEndDay: _rangeEnd,
            calendarFormat: _calendarFormat,
            rangeSelectionMode: _rangeSelectionMode,
            eventLoader: _getEventsForDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarStyle: const CalendarStyle(
              // Use `CalendarStyle` to customize the UI
              outsideDaysVisible: false,
            ),
            onDaySelected: _onDaySelected,
            onRangeSelected: _onRangeSelected,
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: ValueListenableBuilder<List<Event>>(
              valueListenable: _selectedEvents,
              builder: (context, value, _) {
                return ListView.builder(
                  itemCount: value.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 4.0,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(),
                        borderRadius: BorderRadius.circular(12.0),
                        color: value[index].isActive == 1
                            ? Colors.white
                            : Colors.grey[400], // 这里改变颜色
                      ),
                      child: ListTile(
                        onTap: () => print('${value[index]} 事件 {$index}'),
                        title: Row(
                          children: [
                            if (value[index].isActive == 1)
                              Checkbox(
                                value: value[index].isActive != 1, // 注意這裡的更改
                                onChanged: (bool? newValue) async {
                                  if (newValue != null && newValue) {
                                    // 只有當 newValue 為 true 時才執行
                                    // 這裡呼叫 API 來更新 isActive 的狀態
                                    await updateEventIsActiveAPI(
                                        _focusedDay, value[index], false);
                                    setState(() {
                                      value[index].isActive =
                                          0; // 將 isActive 設置為 0
                                    });
                                  }
                                },
                              ),
                            Expanded(
                              child: Text(
                                '${value[index]}',
                                style: TextStyle(
                                  decoration: value[index].isActive != 1
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Ionicons.create_outline),
                              onPressed: () async {
                                await updateEventAPI(_focusedDay, value[index]);
                                print(
                                    'Update button pressed for event: ${value[index]}');
                              },
                            ),
                            IconButton(
                              icon: Icon(Ionicons.trash_outline),
                              onPressed: () async {
                                await deleteEventAPI(_focusedDay, value[index]);
                                setState(() {
                                  value.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: _onAddEventButtonPressed,
      ),
    );
  }
}
