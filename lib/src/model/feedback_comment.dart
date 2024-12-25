// feedback_comment.dart
import 'feedback.dart';
import 'user.dart';

class FeedbackComment {
  String id;
  User user;
  Feedback feedback;
  String content;
  String? image;
  int createdAt;
  int updatedAt;

  FeedbackComment({
    required this.id,
    required this.user,
    required this.feedback,
    required this.content,
    this.image,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': user.id,
      'feedbackId': feedback.id,
      'content': content,
      'image': image,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory FeedbackComment.fromMap(
      Map<String, dynamic> map,
      Map<String, User> users,
      Map<String, Feedback> feedbacks,
      ) {
    String userId = map['userId']?.toString() ?? '';
    String feedbackId = map['feedbackId']?.toString() ?? '';

    User? user = users[userId];
    Feedback? feedback = feedbacks[feedbackId];

    if (user == null || feedback == null) {
      throw Exception('User or Feedback not found for comment ${map['id']}');
    }

    return FeedbackComment(
      id: map['id']?.toString() ?? '',
      user: user,
      feedback: feedback,
      content: map['content']?.toString() ?? '',
      image: map['image']?.toString(),
      createdAt: map['createdAt'] as int? ?? 0,
      updatedAt: map['updatedAt'] as int? ?? 0,
    );
  }
}