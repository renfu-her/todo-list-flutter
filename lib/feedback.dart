import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeedbackPage extends StatefulWidget {
  @override
  _FeedbackPageState createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String? _selectedType;

  SharedPreferences? prefs;

  @override
  void initState() {
    super.initState();
    _initSharedPreferences();
  }

  _initSharedPreferences() async {
    prefs = await SharedPreferences.getInstance();
    // 接下來，您可以使用 `prefs` 來讀取或寫入數據
    String? email = await prefs?.getString('user_email');
    _emailController.text = email ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('回饋意見'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedType,
                hint: Text('選擇問題類型'),
                onChanged: (newValue) {
                  setState(() {
                    _selectedType = newValue;
                  });
                },
                items: [
                  DropdownMenuItem(child: Text('登入問題'), value: '登入問題'),
                  DropdownMenuItem(child: Text('行事曆問題'), value: '行事曆問題'),
                  DropdownMenuItem(child: Text('建議事項'), value: '建議事項'),
                ],
              ),
              SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '名稱',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: '電子郵件',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _contentController,
                maxLines: 6,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  labelText: '內容',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitFeedback,
                child: Text('提交'),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _submitFeedback() async {
    String type = _selectedType ?? '';
    String name = _nameController.text;
    String email = _emailController.text;
    String content = _contentController.text;

    // 檢查所有欄位是否都已填寫
    if (type.isEmpty || name.isEmpty || email.isEmpty || content.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('錯誤'),
          content: Text('請確保所有欄位都已填寫。'),
          actions: <Widget>[
            TextButton(
              child: Text('確定'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
      return; // 早早返回，避免進一步的處理
    }

    var dio = Dio();

    try {
      Response response = await dio.post(
        'https://blog.dev-laravel.co/api/feedback',
        data: {
          'type': type,
          'name': name,
          'email': email,
          'content': content,
          'source': 'todo-list'
        },
        options: Options(
          headers: {
            // 如果需要的話，可以加入其他的標頭，例如認證
          },
        ),
      );

      if (response.statusCode == 200) {
        print('Feedback submitted successfully: ${response.data}');
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('成功'),
            content: Text('回饋意見已提交成功！'),
            actions: <Widget>[
              TextButton(
                child: Text('確定'),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      } else {
        print('Failed to submit feedback: ${response.data}');
        // 這裡您可以添加一些代碼來顯示錯誤消息或其他處理
      }
    } catch (e) {
      print('Error occurred: $e');
      // 這裡您可以添加一些代碼來處理異常或顯示錯誤消息
    }
  }
}
