import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_list/events.dart';
import 'package:todo_list/splash_screen.dart';

Dio dio = Dio();

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '登入或者註冊',
      theme: ThemeData(
        primarySwatch: Colors.lightGreen,
      ),
      home: SplashScreen(),
      routes: {
        '/login': (_) => LoginPage(),
        '/register': (_) => RegisterPage(),
        '/events': (_) => StartPage(),
      },
    );
  }
}

class PrePage extends StatefulWidget {
  @override
  _PrePageState createState() => _PrePageState();
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _PrePageState extends State<PrePage> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  void _checkLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    if (token == null) {
      // 如果 token 不存在，跳轉到登录页面
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      // token 存在，跳轉到主頁
      Navigator.pushReplacementNamed(context, '/events');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _login() async {
    // 这里是发送请求到API的代码

    try {
      final response = await dio.post(
        'https://calendar-dev.dev-laravel.co/api/auth/login',
        data: {
          'email': _emailController.text,
          'password': _passwordController.text,
        },
      );
      if (response.statusCode == 200 && response.data['success']) {
        Fluttertoast.showToast(msg: '登入成功！', gravity: ToastGravity.CENTER);
        // 儲存 token 到 SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        try {
          await prefs.setString('token', response.data['token']);
          await prefs.setString('user_id',
              response.data['user']['id'].toString()); // 注意，这里我们把 id 转换为字符串
        } catch (e) {
          print('Error saving to SharedPreferences: $e');
        }

        String? token = prefs.getString('token');

        if (token == null) {
          // 如果由於某种原因 token 未保存成功，可以在此处理或导航到登录页面。
          Navigator.pushReplacementNamed(context, '/login');
        } else {
          // token 存在，跳轉到主頁
          Navigator.pushReplacementNamed(context, '/events');
        }
      } else {
        Fluttertoast.showToast(
          msg: response.data['error'],
          gravity: ToastGravity.CENTER,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: '登入失敗！',
        gravity: ToastGravity.CENTER,
      );
      ;
    }
  }

  void _goToRegister() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('登入'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset('assets/images/todo-list.png',
                width: 250), // 調整大小為所需的大小
            SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
              style: TextStyle(fontSize: 20.0),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: '密碼'),
              obscureText: true,
              style: TextStyle(fontSize: 20.0),
            ),
            ElevatedButton(
                onPressed: _login,
                child: Text('登入',
                    style: TextStyle(fontSize: 18.0, color: Colors.white))),
            TextButton(
                onPressed: _goToRegister,
                child: Text('前往註冊', style: TextStyle(fontSize: 20.0)))
          ],
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  void _register() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      Fluttertoast.showToast(
        msg: '密碼不匹配！',
        gravity: ToastGravity.CENTER,
      );
      return;
    }

    // 发送请求到API
    final response = await dio.post(
      'https://calendar-dev.dev-laravel.co/api/auth/register',
      data: {
        'name': _nameController.text,
        'email': _emailController.text,
        'password': _passwordController.text,
        'password_confirmation': _confirmPasswordController.text,
      },
    );

    if (response.statusCode == 200 && response.data['success']) {
      Fluttertoast.showToast(msg: '註冊成功！', gravity: ToastGravity.CENTER);
      Navigator.pop(context); // 返回登录页面
    } else {
      Fluttertoast.showToast(
        msg: response.data['error'],
        gravity: ToastGravity.CENTER,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('註冊')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset('assets/images/todo-list.png',
                width: 250), // 調整大小為所需的大小
            SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: '名稱'),
              style: TextStyle(fontSize: 20.0),
            ),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
              style: TextStyle(fontSize: 20.0),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: '密碼'),
              style: TextStyle(fontSize: 20.0),
              obscureText: true,
            ),
            TextField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(labelText: '確認密碼'),
              style: TextStyle(fontSize: 20.0),
              obscureText: true,
            ),
            ElevatedButton(
                onPressed: _register,
                child: Text('註冊',
                    style: TextStyle(fontSize: 18.0, color: Colors.white)))
          ],
        ),
      ),
    );
  }
}
