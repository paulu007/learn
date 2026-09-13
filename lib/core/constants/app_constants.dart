import 'package:flutter/material.dart';

/// Shared constants: feedback colors, CSV format, difficulties, statuses.
class AppConstants {
  static const String appName = 'E';

  // Learning feedback colors (always paired with text labels, never color-only).
  static const Color correctGreen = Color(0xFF2E9E5B);
  static const Color incorrectRed = Color(0xFFD64545);
  static const Color actionBlue = Color(0xFF2F7CF6);

  static const List<String> itemTypes = ['vocab', 'sentence', 'communication'];
  static const List<String> difficulties = ['easy', 'medium', 'hard'];
  static const List<String> progressStatuses = [
    'new',
    'learning',
    'review',
    'mastered',
  ];

  static const List<String> csvHeaders = [
    'type',
    'source',
    'target',
    'example',
    'hint',
    'lesson',
    'tags',
    'difficulty',
  ];

  /// Shown on the import screen so users know exactly how to prepare a file.
  static const String csvExample = '''type,source,target,example,hint,lesson,tags,difficulty
vocab,hello,سلام,Hello John!,A greeting,1,greeting,easy
vocab,book,کتاب,I read a book.,Something you read,1,objects,easy
vocab,water,آب,I drink water.,A common drink,1,food,easy
sentence,How are you?,حالت چطوره؟,How are you today?,Common greeting,1,greetings,easy
sentence,I need help.,من کمک نیاز دارم.,I need help with this.,Useful communication,1,communication,medium''';

  static const int defaultDailyGoal = 10;
}

/// Font-size options from Settings. The value is a text scaler multiplier.
enum AppFontSize {
  small(0.85, 'Small'),
  normal(1.0, 'Normal'),
  large(1.15, 'Large'),
  extraLarge(1.3, 'Extra Large');

  const AppFontSize(this.scale, this.label);
  final double scale;
  final String label;

  static AppFontSize fromName(String? name) => AppFontSize.values.firstWhere(
    (e) => e.name == name,
    orElse: () => AppFontSize.normal,
  );
}
