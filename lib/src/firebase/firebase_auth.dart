import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

class FirAuth {
  static final FirAuth _instance = FirAuth._internal();
  factory FirAuth() => _instance;
  FirAuth._internal();

  final FirebaseAuth _fireBaseAuth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Constants
  static const int MAX_LOGIN_ATTEMPTS = 5;
  static const int RATE_LIMIT_DURATION = 3600000; // 1 hour in milliseconds
  static const String DEFAULT_AVATAR = 'assets/img/defaultAvatar.png';

  // Validation Patterns
  static final RegExp _emailPattern = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  static final RegExp _phonePattern = RegExp(r'^[0-9]{10}$');
  static final RegExp _uppercasePattern = RegExp(r'[A-Z]');
  static final RegExp _lowercasePattern = RegExp(r'[a-z]');
  static final RegExp _numberPattern = RegExp(r'[0-9]');

  // Validation Methods
  bool isValidEmail(String email) {
    return email.isNotEmpty && _emailPattern.hasMatch(email.trim());
  }

  bool isValidPhone(String phone) {
    return phone.isNotEmpty && _phonePattern.hasMatch(phone.trim());
  }

  bool isStrongPassword(String password) {
    if (password.isEmpty || password.length < 8) return false;

    return _uppercasePattern.hasMatch(password) &&
        _lowercasePattern.hasMatch(password) &&
        _numberPattern.hasMatch(password);
  }

  // Authentication Methods
  Future<void> signUp(
      String email,
      String pass,
      String name,
      String phone,
      Function(bool, String?) onComplete
      ) async {
    try {
      // Pre-signup validation
      if (!_validateSignUpInput(email, pass, phone)) {
        return;
      }

      print("Debug: Starting signup process");

      // Check for existing accounts
      await _checkUniqueCredentials(email, phone);
      print("Debug: Credentials checked");

      // Create auth user
      print("Debug: Creating Firebase Auth user");
      final UserCredential userCredential = await _fireBaseAuth
          .createUserWithEmailAndPassword(email: email, password: pass);
      print("Debug: Firebase Auth user created");

      final String userId = userCredential.user!.uid;
      print("Debug: User ID: $userId");

      // Create user records
      print("Debug: Creating user records");
      await _createUserRecords(userId, email, pass, name, phone);
      print("Debug: User records created");

      // Send verification email
      print("Debug: Sending verification email");
      await userCredential.user?.sendEmailVerification();
      print("Debug: Verification email sent");

      onComplete(true, null);
    } catch (error) {
      print("SignUp Error Detail: $error");
      String errorMessage = _getErrorMessage(error);
      print("Formatted Error Message: $errorMessage");
      onComplete(false, errorMessage);

      // Additional error information
      if (error is FirebaseException) {
        print("Firebase Error Code: ${error.code}");
        print("Firebase Error Message: ${error.message}");
      }
    }
  }

  Future<void> signIn(
      String emailOrPhone,
      String password,
      Function(bool, String?, UserCredential?) onComplete
      ) async {
    try {
      // Check rate limiting
      if (!await _checkRateLimit()) {
        throw Exception("Quá nhiều lần đăng nhập thất bại. Vui lòng thử lại sau.");
      }

      // Get email from phone if necessary
      final String email = await _resolveEmail(emailOrPhone);

      // Perform authentication
      final UserCredential userCredential = await _fireBaseAuth
          .signInWithEmailAndPassword(email: email, password: password);

      // Verify user exists in database
      await _verifyUserExists(userCredential.user!.uid);

      // Update last login
      await _updateLastLogin(userCredential.user!.uid);

      onComplete(true, null, userCredential);
    } catch (error) {
      await _recordFailedAttempt();
      print("SignIn Error: $error");
      String errorMessage = _getErrorMessage(error);
      onComplete(false, errorMessage, null);
    }
  }

  // User Detail Methods
  Future<Map<String, dynamic>?> getUserDetail(String userId) async {
    try {
      final snapshot = await _database
          .child('userDetails')
          .child(userId)
          .get();

      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (error) {
      print("Get UserDetail Error: $error");
      throw Exception("Lỗi khi lấy thông tin chi tiết người dùng");
    }
  }

  Future<void> updateUserDetail(String userId, Map<String, dynamic> updates) async {
    try {
      // Validate updates
      if (!_validateUserDetailUpdates(updates)) {
        throw Exception("Dữ liệu cập nhật không hợp lệ");
      }

      await _database
          .child('userDetails')
          .child(userId)
          .update(updates);
    } catch (error) {
      print("Update UserDetail Error: $error");
      throw Exception("Lỗi khi cập nhật thông tin chi tiết người dùng");
    }
  }

  // Private Helper Methods
  bool _validateSignUpInput(String email, String pass, String phone) {
    if (!isValidEmail(email)) {
      throw Exception("Email không hợp lệ");
    }
    if (!isValidPhone(phone)) {
      throw Exception("Số điện thoại không hợp lệ");
    }
    if (!isStrongPassword(pass)) {
      throw Exception("Mật khẩu phải có ít nhất 8 ký tự, bao gồm chữ hoa, chữ thường và số");
    }
    return true;
  }

  Future<void> _checkUniqueCredentials(String email, String phone) async {
    final emailExists = await _checkFieldExists('email', email);
    if (emailExists) {
      throw Exception("Email đã tồn tại");
    }

    final phoneExists = await _checkFieldExists('phone', phone);
    if (phoneExists) {
      throw Exception("Số điện thoại đã tồn tại");
    }
  }

  Future<bool> _checkFieldExists(String field, String value) async {
    final snapshot = await _database
        .child('accounts')
        .orderByChild(field)
        .equalTo(value)
        .get();
    return snapshot.exists;
  }

  Future<void> _createUserRecords(
    String userId,
    String email,
    String pass,
    String name,
    String phone
) async {
    try {
      // Create records in parallel for better performance
      await Future.wait([
        // Account record
        _database.child('accounts').push().set({
          'email': email,
          'phone': phone,
          'pass': pass,
          'createdAt': ServerValue.timestamp,
        }),

        // User record
        _database.child('users').child(userId).set({
          'name': name,
          'email': email,
          'phone': phone,
          'createdAt': ServerValue.timestamp,
        }),

        // User details record
        _database.child('userDetails').child(userId).set({
          'id': userId,
          'image': DEFAULT_AVATAR,
          'gioitinh': null,
          'date': null,
          'diachi': null,
          'createdAt': ServerValue.timestamp,
        })
      ]);

    } catch (error) {
      print("Error creating user records: $error");
      await _cleanupFailedSignup(userId);
      throw Exception("Lỗi khi tạo tài khoản: ${error.toString()}");
    }
}
// Update the cleanup method as well
  Future<void> _cleanupFailedSignup(String userId) async {
    try {
      final List<Future<void>> futures = [
        _database.child('users').child(userId).remove(),
        _database.child('userDetails').child(userId).remove(),
        // Find and remove the account record
        _database
            .child('accounts')
            .orderByChild('email')
            .equalTo(userId)
            .once()
            .then((event) {
          if (event.snapshot.value != null) {
            Map<dynamic, dynamic> accounts =
            event.snapshot.value as Map<dynamic, dynamic>;
            accounts.forEach((key, value) {
              _database.child('accounts').child(key).remove();
            });
          }
        }),
      ];

      // Delete the Firebase Auth user if it exists
      if (_fireBaseAuth.currentUser != null) {
        futures.add(_fireBaseAuth.currentUser!.delete());
      }

      await Future.wait(futures);
    } catch (error) {
      print("Cleanup Error: $error");
    }
  }

  Future<String> _resolveEmail(String emailOrPhone) async {
    if (emailOrPhone.contains('@')) {
      return emailOrPhone;
    }

    final snapshot = await _database
        .child('accounts')
        .orderByChild('phone')
        .equalTo(emailOrPhone)
        .get();

    if (!snapshot.exists) {
      throw Exception("Không tìm thấy tài khoản");
    }

    final accountData = Map<String, dynamic>.from((snapshot.value as Map).values.first);
    return accountData['email'];
  }

  Future<void> _verifyUserExists(String userId) async {
    final userSnapshot = await _database
        .child('users')
        .child(userId)
        .get();

    if (!userSnapshot.exists) {
      throw Exception("Tài khoản không tồn tại trong hệ thống");
    }
  }

  Future<void> _updateLastLogin(String userId) async {
    await _database
        .child('users')
        .child(userId)
        .update({'lastLogin': ServerValue.timestamp});
  }

  // Rate Limiting Methods
  Future<bool> _checkRateLimit() async {
    final String deviceId = await _getDeviceId();
    final snapshot = await _database
        .child('failedAttempts')
        .child(deviceId)
        .orderByChild('timestamp')
        .startAt(DateTime.now().millisecondsSinceEpoch - RATE_LIMIT_DURATION)
        .get();

    if (snapshot.exists) {
      final attempts = (snapshot.value as Map).length;
      return attempts < MAX_LOGIN_ATTEMPTS;
    }
    return true;
  }

  Future<void> _recordFailedAttempt() async {
    final String deviceId = await _getDeviceId();
    await _database
        .child('failedAttempts')
        .child(deviceId)
        .push()
        .set({
      'timestamp': ServerValue.timestamp,
    });
  }

  Future<String> _getDeviceId() async {
    // TODO: Implement actual device ID retrieval
    return 'temp-device-id';
  }

  bool _validateUserDetailUpdates(Map<String, dynamic> updates) {
    // Add validation logic for user detail updates
    return true;
  }

  String _getErrorMessage(dynamic error) {
    if (error is Exception) {
      final message = error.toString().toLowerCase();

      return switch (message) {
        String m when m.contains("user-not-found") => "Tài khoản không tồn tại",
        String m when m.contains("wrong-password") => "Sai mật khẩu",
        String m when m.contains("invalid-email") => "Email không hợp lệ",
        String m when m.contains("user-disabled") => "Tài khoản đã bị khóa",
        String m when m.contains("email-already-in-use") => "Email đã được sử dụng",
        String m when m.contains("weak-password") => "Mật khẩu quá yếu",
        String m when m.contains("network-request-failed") => "Lỗi kết nối mạng",
        String m when m.contains("lỗi khi tạo tài khoản") => message,
        _ => "Đã có lỗi xảy ra. Vui lòng thử lại sau."
      };
    }
    return "Đã có lỗi xảy ra. Vui lòng thử lại sau.";
  }

  // Public Utility Methods
  Future<void> resetPassword(String email) async {
    if (!isValidEmail(email)) {
      throw Exception("Email không hợp lệ");
    }
    await _fireBaseAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await _fireBaseAuth.signOut();
  }

  bool isSignedIn() {
    return _fireBaseAuth.currentUser != null;
  }

  User? getCurrentUser() {
    return _fireBaseAuth.currentUser;
  }
}