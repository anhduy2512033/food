import 'package:flutter/material.dart';

class Forgotpass extends StatefulWidget {
  @override
  _Forgotpass createState() => _Forgotpass();
}
class _Forgotpass extends State<Forgotpass> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quên mật khẩu'),
      ),
      body: Stack(
        children: [
          // Ảnh nền
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/img/background(1).jpg'),
                // Đường dẫn đến ảnh nền
                fit: BoxFit.cover, // Tùy chọn căn chỉnh ảnh nền
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/img/logo1.jpg',
                  width: 400,
                  height: 300,
                ),
                SizedBox(height: 20.0),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Email hoặc số điện thoại',
                    filled: true,
                    fillColor: Colors.orangeAccent[100],
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide(color: Colors.orange, width: 2.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: BorderSide(color: Colors.orange, width: 3.0),
                    ),
                  ),
                ),
                SizedBox(height: 20.0),
                ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>(
                            (Set<WidgetState> states) {
                          if (states.contains(WidgetState.pressed)) {
                            return Colors.orange; // Background color when pressed
                          }
                          return Colors.orange; // Default background color
                        }),
                    foregroundColor: WidgetStateProperty.resolveWith<Color>(
                            (Set<WidgetState> states) {
                          if (states.contains(WidgetState.pressed)) {
                            return Colors.white; // Text color when pressed
                          }
                          return Colors.white; // Default text color
                        }),
                    // ... other properties
                  ),
                  onPressed: (){},
                  child: Text('Quên mật khẩu'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}