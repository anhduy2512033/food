// import 'dart:async';
// import '../firebase/firebase_auth.dart';
//
// class AuthBloc {
//   final _firAuth = FirAuth();
//   final _nameController = StreamController<String>();
//   final _emailController = StreamController<String>();
//   final _passController = StreamController<String>();
//   final _phoneController = StreamController<String>();
//
//   Stream<String> get nameStream => _nameController.stream;
//   Stream<String> get emailStream => _emailController.stream;
//   Stream<String> get passStream => _passController.stream;
//   Stream<String> get phoneStream => _phoneController.stream;
//
//   bool isValid(String name, String email, String pass, String phone) {
//     if (name.isEmpty) {
//       _nameController.sink.addError("Nhập tên");
//       return false;
//     }
//     _nameController.sink.add("");
//
//     if (phone.isEmpty) {
//       _phoneController.sink.addError("Nhập số điện thoại");
//       return false;
//     }
//     _phoneController.sink.add("");
//
//     if (email.isEmpty) {
//       _emailController.sink.addError("Nhập email");
//       return false;
//     }
//     _emailController.sink.add("");
//
//     if (pass.length < 6) {
//       _passController.sink.addError("Mật khẩu phải trên 5 ký tự");
//       return false;
//     }
//     _passController.sink.add("");
//
//     return true;
//   }
//
//   Future<void> signUp(String email, String pass, String phone, String name,
//       Function(bool, String?) onComplete) async {
//     await _firAuth.signUp(email, pass, name, phone, onComplete);
//   }
//
//   void dispose() {
//     _nameController.close();
//     _emailController.close();
//     _passController.close();
//     _phoneController.close();
//   }
// }

import 'dart:async';
import '../firebase/firebase_auth.dart';

class AuthBloc {
  final _firAuth = FirAuth();

  // Stream controllers for form validation
  final _nameController = StreamController<String>.broadcast();
  final _emailController = StreamController<String>.broadcast();
  final _passController = StreamController<String>.broadcast();
  final _phoneController = StreamController<String>.broadcast();

  // Expose streams for UI consumption
  Stream<String> get nameStream => _nameController.stream;
  Stream<String> get emailStream => _emailController.stream;
  Stream<String> get passStream => _passController.stream;
  Stream<String> get phoneStream => _phoneController.stream;

  // Validate form fields
  bool isValid(String name, String email, String pass, String phone) {
    bool isValid = true;

    // Validate name
    if (name.trim().isEmpty) {
      _nameController.sink.addError("Vui lòng nhập họ tên");
      isValid = false;
    } else if (name.trim().length < 2) {
      _nameController.sink.addError("Họ tên phải có ít nhất 2 ký tự");
      isValid = false;
    } else {
      _nameController.sink.add(name);
    }

    // Validate phone
    if (phone.trim().isEmpty) {
      _phoneController.sink.addError("Vui lòng nhập số điện thoại");
      isValid = false;
    } else if (!_firAuth.isValidPhone(phone)) {
      _phoneController.sink.addError("Số điện thoại không hợp lệ");
      isValid = false;
    } else {
      _phoneController.sink.add(phone);
    }

    // Validate email
    if (email.trim().isEmpty) {
      _emailController.sink.addError("Vui lòng nhập email");
      isValid = false;
    } else if (!_firAuth.isValidEmail(email)) {
      _emailController.sink.addError("Email không hợp lệ");
      isValid = false;
    } else {
      _emailController.sink.add(email);
    }

    // Validate password
    if (pass.isEmpty) {
      _passController.sink.addError("Vui lòng nhập mật khẩu");
      isValid = false;
    } else if (!_firAuth.isStrongPassword(pass)) {
      _passController.sink.addError(
          "Mật khẩu phải có ít nhất 8 ký tự, bao gồm chữ hoa, chữ thường và số"
      );
      isValid = false;
    } else {
      _passController.sink.add(pass);
    }

    return isValid;
  }

  // Sign up method
  Future<void> signUp(
      String email,
      String pass,
      String phone,
      String name,
      Function(bool, String?) onComplete
      ) async {
    try {
      // Validate all fields before attempting signup
      if (!isValid(name, email, pass, phone)) {
        onComplete(false, "Vui lòng kiểm tra lại thông tin đăng ký");
        return;
      }

      // Attempt signup
      await _firAuth.signUp(email, pass, name, phone, onComplete);
    } catch (e) {
      onComplete(false, "Đã xảy ra lỗi: ${e.toString()}");
    }
  }

  // Cleanup resources
  void dispose() {
    _nameController.close();
    _emailController.close();
    _passController.close();
    _phoneController.close();
  }
}