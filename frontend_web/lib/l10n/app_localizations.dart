import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // 定义需要翻译的文本键值对
  static final Map<String, Map<String, String>> _localizedValues = {
    'zh': {
      'app_title': 'StudyService 网页版',
      'home': '首页',
      'recording': '讲义上传',
      'ai_summary': 'AI 总结',
      'quiz': '复习测验',
      'planner': '学习规划',
      'mail': '邮件翻译',
      'solver': '智能解题',
    },
    'ko': {
      'app_title': 'StudyService 웹',
      'home': '홈',
      'recording': '강의 업로드',
      'ai_summary': 'AI 요약',
      'quiz': '복습 퀴즈',
      'planner': '학습 계획',
      'mail': '메일 번역',
      'solver': '문제 풀이',
    },
    'ru': {
      'app_title': 'StudyService Web',
      'home': 'Главная',
      'recording': 'Загрузка лекции',
      'ai_summary': 'AI-конспект',
      'quiz': 'Тест',
      'planner': 'План',
      'mail': 'Перевод почты',
      'solver': 'Решение задач',
    },
  };

  String get appTitle => _localizedValues[locale.languageCode]!['app_title']!;
  String get home => _localizedValues[locale.languageCode]!['home']!;
  String get recording => _localizedValues[locale.languageCode]!['recording']!;
  String get aiSummary => _localizedValues[locale.languageCode]!['ai_summary']!;
  String get quiz => _localizedValues[locale.languageCode]!['quiz']!;
  String get planner => _localizedValues[locale.languageCode]!['planner']!;
  String get mail => _localizedValues[locale.languageCode]!['mail']!;
  String get solver => _localizedValues[locale.languageCode]!['solver']!;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['zh', 'ko', 'ru'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
