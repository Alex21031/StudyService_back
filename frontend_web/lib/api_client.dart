import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class PickedUpload {
  PickedUpload({
    required this.name,
    required this.bytes,
  });

  final String name;
  final Uint8List bytes;
}

class UserProfile {
  UserProfile({
    required this.id,
    required this.email,
    required this.isActive,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int? ?? 0,
      email: json['email'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
    );
  }

  final int id;
  final String email;
  final bool isActive;
}

class Lecture {
  Lecture({
    required this.id,
    required this.userId,
    required this.title,
    required this.courseName,
    required this.audioPath,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.transcript,
    this.summaryOriginal,
    this.summaryRussian,
    this.summaryTranslations = const <String, String>{},
    this.keyTerms = const <KeyTerm>[],
    this.errorMessage,
    this.progressPercent = 0,
    this.progressMessage,
    this.progressCurrent,
    this.progressTotal,
  });

  factory Lecture.fromJson(Map<String, dynamic> json) {
    return Lecture(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      courseName: json['courseName'] as String? ?? '',
      audioPath: json['audioPath'] as String? ?? '',
      status: json['status'] as String? ?? '',
      transcript: json['transcript'] as String?,
      summaryOriginal: json['summaryOriginal'] as String?,
      summaryRussian: json['summaryRussian'] as String?,
      summaryTranslations:
          (json['summaryTranslations'] as Map<String, dynamic>? ?? const {})
              .map((key, value) => MapEntry(key, value.toString())),
      keyTerms: (json['keyTerms'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(KeyTerm.fromJson)
          .toList(),
      errorMessage: json['errorMessage'] as String?,
      progressPercent: json['progressPercent'] as int? ?? 0,
      progressMessage: json['progressMessage'] as String?,
      progressCurrent: json['progressCurrent'] as int?,
      progressTotal: json['progressTotal'] as int?,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  final String id;
  final int userId;
  final String title;
  final String courseName;
  final String audioPath;
  final String status;
  final String? transcript;
  final String? summaryOriginal;
  final String? summaryRussian;
  final Map<String, String> summaryTranslations;
  final List<KeyTerm> keyTerms;
  final String? errorMessage;
  final int progressPercent;
  final String? progressMessage;
  final int? progressCurrent;
  final int? progressTotal;
  final String createdAt;
  final String updatedAt;
}

class KeyTerm {
  KeyTerm({
    required this.term,
    required this.originalExplanation,
    required this.russianExplanation,
    required this.additionalContext,
    this.explanations = const <String, String>{},
    this.additionalNotes = const <String, String>{},
  });

  factory KeyTerm.fromJson(Map<String, dynamic> json) {
    return KeyTerm(
      term: json['term'] as String? ?? '',
      originalExplanation: json['originalExplanation'] as String? ?? '',
      russianExplanation: json['russianExplanation'] as String? ?? '',
      additionalContext: json['additionalContext'] as String? ?? '',
      explanations: (json['explanations'] as Map<String, dynamic>? ?? const {})
          .map((key, value) => MapEntry(key, value.toString())),
      additionalNotes:
          (json['additionalNotes'] as Map<String, dynamic>? ?? const {})
              .map((key, value) => MapEntry(key, value.toString())),
    );
  }

  final String term;
  final String originalExplanation;
  final String russianExplanation;
  final String additionalContext;
  final Map<String, String> explanations;
  final Map<String, String> additionalNotes;
}

class LectureQuiz {
  LectureQuiz({
    required this.id,
    required this.lectureId,
    required this.type,
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
    required this.difficulty,
    this.skillTag,
    this.conceptRefs = const <String>[],
    this.reviewHint,
    this.followUpPrompt,
    this.localizedContent = const <String, QuizLocalization>{},
    required this.createdAt,
  });

  factory LectureQuiz.fromJson(Map<String, dynamic> json) {
    return LectureQuiz(
      id: json['id'] as String? ?? '',
      lectureId: json['lectureId'] as String? ?? '',
      type: json['type'] as String? ?? '',
      question: json['question'] as String? ?? '',
      options: (json['options'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      answer: json['answer'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      difficulty: json['difficulty'] as String? ?? '',
      skillTag: json['skillTag'] as String?,
      conceptRefs: (json['conceptRefs'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      reviewHint: json['reviewHint'] as String?,
      followUpPrompt: json['followUpPrompt'] as String?,
      localizedContent:
          (json['localizedContent'] as Map<String, dynamic>? ?? const {})
              .map(
                (key, value) => MapEntry(
                  key,
                  QuizLocalization.fromJson(
                    value is Map<String, dynamic> ? value : const {},
                  ),
                ),
              ),
      createdAt: json['createdAt'] as String? ?? '',
    );
  }

  final String id;
  final String lectureId;
  final String type;
  final String question;
  final List<String> options;
  final String answer;
  final String explanation;
  final String difficulty;
  final String? skillTag;
  final List<String> conceptRefs;
  final String? reviewHint;
  final String? followUpPrompt;
  final Map<String, QuizLocalization> localizedContent;
  final String createdAt;
}

class QuizLocalization {
  QuizLocalization({
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
    this.reviewHint,
    this.followUpPrompt,
    this.skillTag,
    this.conceptRefs = const <String>[],
  });

  factory QuizLocalization.fromJson(Map<String, dynamic> json) {
    return QuizLocalization(
      question: json['question'] as String? ?? '',
      options: (json['options'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      answer: json['answer'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      reviewHint: json['reviewHint'] as String?,
      followUpPrompt: json['followUpPrompt'] as String?,
      skillTag: json['skillTag'] as String?,
      conceptRefs: (json['conceptRefs'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
    );
  }

  final String question;
  final List<String> options;
  final String answer;
  final String explanation;
  final String? reviewHint;
  final String? followUpPrompt;
  final String? skillTag;
  final List<String> conceptRefs;
}

class LectureDetail {
  LectureDetail({
    required this.lecture,
    required this.quizzes,
  });

  factory LectureDetail.fromJson(Map<String, dynamic> json) {
    return LectureDetail(
      lecture: Lecture.fromJson(json['lecture'] as Map<String, dynamic>? ?? const {}),
      quizzes: (json['quizzes'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LectureQuiz.fromJson)
          .toList(),
    );
  }

  final Lecture lecture;
  final List<LectureQuiz> quizzes;
}

class ProcessLectureResult {
  ProcessLectureResult({
    required this.lecture,
    required this.quizzes,
  });

  factory ProcessLectureResult.fromJson(Map<String, dynamic> json) {
    return ProcessLectureResult(
      lecture: Lecture.fromJson(json['lecture'] as Map<String, dynamic>? ?? const {}),
      quizzes: (json['quizzes'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LectureQuiz.fromJson)
          .toList(),
    );
  }

  final Lecture lecture;
  final List<LectureQuiz> quizzes;
}

class QuizAttemptResult {
  QuizAttemptResult({
    required this.attemptId,
    required this.correct,
    required this.total,
    required this.score,
    required this.mode,
    required this.language,
    required this.questionResults,
    required this.weakConcepts,
    required this.recommendedActions,
  });

  factory QuizAttemptResult.fromJson(Map<String, dynamic> json) {
    return QuizAttemptResult(
      attemptId: json['attemptId'] as String? ?? '',
      correct: json['correct'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      score: json['score'] as int? ?? 0,
      mode: json['mode'] as String? ?? 'practice',
      language: json['language'] as String? ?? 'en',
      questionResults: (json['questionResults'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(QuizQuestionResult.fromJson)
          .toList(),
      weakConcepts: (json['weakConcepts'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WeakConcept.fromJson)
          .toList(),
      recommendedActions:
          (json['recommendedActions'] as List<dynamic>? ?? const [])
              .map((value) => value.toString())
              .toList(),
    );
  }

  final String attemptId;
  final int correct;
  final int total;
  final int score;
  final String mode;
  final String language;
  final List<QuizQuestionResult> questionResults;
  final List<WeakConcept> weakConcepts;
  final List<String> recommendedActions;
}

class QuizQuestionResult {
  QuizQuestionResult({
    required this.quizId,
    required this.question,
    required this.submittedAnswer,
    required this.correctAnswer,
    required this.isCorrect,
    required this.explanation,
    this.reviewHint,
    this.skillTag,
    this.conceptRefs = const <String>[],
    this.followUpPrompt,
  });

  factory QuizQuestionResult.fromJson(Map<String, dynamic> json) {
    return QuizQuestionResult(
      quizId: json['quizId'] as String? ?? '',
      question: json['question'] as String? ?? '',
      submittedAnswer: json['submittedAnswer'] as String? ?? '',
      correctAnswer: json['correctAnswer'] as String? ?? '',
      isCorrect: json['isCorrect'] as bool? ?? false,
      explanation: json['explanation'] as String? ?? '',
      reviewHint: json['reviewHint'] as String?,
      skillTag: json['skillTag'] as String?,
      conceptRefs: (json['conceptRefs'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      followUpPrompt: json['followUpPrompt'] as String?,
    );
  }

  final String quizId;
  final String question;
  final String submittedAnswer;
  final String correctAnswer;
  final bool isCorrect;
  final String explanation;
  final String? reviewHint;
  final String? skillTag;
  final List<String> conceptRefs;
  final String? followUpPrompt;
}

class WeakConcept {
  WeakConcept({
    required this.label,
    required this.misses,
    this.reviewHint,
  });

  factory WeakConcept.fromJson(Map<String, dynamic> json) {
    return WeakConcept(
      label: json['label'] as String? ?? '',
      misses: json['misses'] as int? ?? 0,
      reviewHint: json['reviewHint'] as String?,
    );
  }

  final String label;
  final int misses;
  final String? reviewHint;
}

class StudyPlanItem {
  StudyPlanItem({
    required this.date,
    required this.phase,
    required this.title,
    required this.task,
    required this.mission,
    required this.focus,
    required this.review,
    required this.expectedOutput,
    required this.whyThisMatters,
    this.focusBoost,
    required this.effort,
    required this.sessionMinutes,
  });

  factory StudyPlanItem.fromJson(Map<String, dynamic> json) {
    return StudyPlanItem(
      date: json['date'] as String? ?? '',
      phase: json['phase'] as String? ?? '',
      title: json['title'] as String? ?? '',
      task: json['task'] as String? ?? '',
      mission: json['mission'] as String? ?? '',
      focus: json['focus'] as String? ?? '',
      review: json['review'] as String? ?? '',
      expectedOutput:
          json['expectedOutput'] as String? ??
          json['expected_output'] as String? ??
          '',
      whyThisMatters:
          json['whyThisMatters'] as String? ??
          json['why_this_matters'] as String? ??
          '',
      focusBoost:
          json['focusBoost'] as String? ??
          json['focus_boost'] as String?,
      effort: json['effort'] as String? ?? 'steady',
      sessionMinutes:
          json['sessionMinutes'] as int? ??
          json['session_minutes'] as int? ??
          90,
    );
  }

  final String date;
  final String phase;
  final String title;
  final String task;
  final String mission;
  final String focus;
  final String review;
  final String expectedOutput;
  final String whyThisMatters;
  final String? focusBoost;
  final String effort;
  final int sessionMinutes;
}

class StudyPlanResult {
  StudyPlanResult({
    required this.course,
    required this.examDate,
    required this.startDate,
    required this.scope,
    required this.language,
    required this.totalDays,
    required this.studyDays,
    required this.dailyMinutes,
    required this.overview,
    required this.checkpoints,
    this.personalizationNote,
    required this.weakConcepts,
    required this.selectedLectureIds,
    required this.selectedLectureTitles,
    required this.plan,
  });

  factory StudyPlanResult.fromJson(Map<String, dynamic> json) {
    return StudyPlanResult(
      course: json['course'] as String? ?? '',
      examDate: json['exam_date'] as String? ?? '',
      startDate: json['start_date'] as String? ?? '',
      scope: json['scope'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      totalDays: json['total_days'] as int? ?? 0,
      studyDays: json['study_days'] as int? ?? 0,
      dailyMinutes: json['daily_minutes'] as int? ?? 90,
      overview: json['overview'] as String? ?? '',
      checkpoints: (json['checkpoints'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      personalizationNote:
          json['personalizationNote'] as String? ??
          json['personalization_note'] as String?,
      weakConcepts: (json['weakConcepts'] as List<dynamic>? ??
              json['weak_concepts'] as List<dynamic>? ??
              const [])
          .map((item) => item.toString())
          .toList(),
      selectedLectureIds: (json['selectedLectureIds'] as List<dynamic>? ??
              json['selected_lecture_ids'] as List<dynamic>? ??
              const [])
          .map((item) => item.toString())
          .toList(),
      selectedLectureTitles: (json['selectedLectureTitles'] as List<dynamic>? ??
              json['selected_lecture_titles'] as List<dynamic>? ??
              const [])
          .map((item) => item.toString())
          .toList(),
      plan: (json['plan'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(StudyPlanItem.fromJson)
          .toList(),
    );
  }

  final String course;
  final String examDate;
  final String startDate;
  final String scope;
  final String language;
  final int totalDays;
  final int studyDays;
  final int dailyMinutes;
  final String overview;
  final List<String> checkpoints;
  final String? personalizationNote;
  final List<String> weakConcepts;
  final List<String> selectedLectureIds;
  final List<String> selectedLectureTitles;
  final List<StudyPlanItem> plan;
}

class SolveSessionState {
  SolveSessionState({
    required this.sessionId,
    required this.prompt,
    required this.stepIndex,
    required this.totalSteps,
    required this.isFinished,
    this.ok,
    this.feedback,
    this.hint,
    this.stepTitle,
    this.attempts = 0,
  });

  factory SolveSessionState.fromJson(Map<String, dynamic> json) {
    return SolveSessionState(
      sessionId: json['session_id'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      stepIndex: json['step_index'] as int? ?? 0,
      totalSteps: json['total_steps'] as int? ?? 0,
      isFinished: json['is_finished'] as bool? ?? false,
      ok: json['ok'] as bool?,
      feedback: json['feedback'] as String?,
      hint: json['hint'] as String?,
      stepTitle: json['step_title'] as String?,
      attempts: json['attempts'] as int? ?? 0,
    );
  }

  final String sessionId;
  final String prompt;
  final int stepIndex;
  final int totalSteps;
  final bool isFinished;
  final bool? ok;
  final String? feedback;
  final String? hint;
  final String? stepTitle;
  final int attempts;
}

class ApiClient {
  ApiClient({
    required this.baseUrl,
    this.token,
  });

  String baseUrl;
  String? token;

  Future<Map<String, dynamic>> health() async {
    final response = await http.get(_uri('/health'));
    return _decodeMap(response);
  }

  Future<UserProfile> register({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      _uri('/auth/register'),
      headers: _jsonHeaders(),
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
    return UserProfile.fromJson(_decodeMap(response));
  }

  Future<String> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      _uri('/auth/token'),
      headers: const {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: Uri(queryParameters: {
        'username': email,
        'password': password,
      }).query,
    );
    final payload = _decodeMap(response);
    final accessToken = payload['access_token'] as String? ?? '';
    if (accessToken.isEmpty) {
      throw ApiException('Missing access token in login response');
    }
    token = accessToken;
    return accessToken;
  }

  Future<UserProfile> me() async {
    final response = await http.get(
      _uri('/auth/me'),
      headers: _authHeaders(),
    );
    return UserProfile.fromJson(_decodeMap(response));
  }

  Future<List<Lecture>> listLectures() async {
    final response = await http.get(
      _uri('/lectures'),
      headers: _authHeaders(),
    );
    return _decodeList(response).map(Lecture.fromJson).toList();
  }

  Future<LectureDetail> getLecture(String lectureId) async {
    final response = await http.get(
      _uri('/lectures/$lectureId'),
      headers: _authHeaders(),
    );
    return LectureDetail.fromJson(_decodeMap(response));
  }

  Future<List<LectureQuiz>> listLectureQuizzes(String lectureId) async {
    final response = await http.get(
      _uri('/lectures/$lectureId/quizzes'),
      headers: _authHeaders(),
    );
    return _decodeList(response).map(LectureQuiz.fromJson).toList();
  }

  Future<ProcessLectureResult> processAudio({
    required String title,
    required String courseName,
    required PickedUpload audio,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/lectures/process-audio'));
    request.headers.addAll(_authHeaders());
    request.fields['title'] = title;
    request.fields['courseName'] = courseName;
    request.files.add(
      http.MultipartFile.fromBytes(
        'audio',
        audio.bytes,
        filename: audio.name,
      ),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return ProcessLectureResult.fromJson(_decodeMap(response));
  }

  Future<QuizAttemptResult> submitQuizAnswers({
    required String lectureId,
    required Map<String, String> answers,
    List<String> quizIds = const [],
    String mode = 'practice',
    String language = 'en',
  }) async {
    final response = await http.post(
      _uri('/lectures/$lectureId/quiz-attempts'),
      headers: _authHeaders(json: true),
      body: jsonEncode({
        'answers': answers,
        'quizIds': quizIds,
        'mode': mode,
        'language': language,
      }),
    );
    return QuizAttemptResult.fromJson(_decodeMap(response));
  }

  Future<List<LectureQuiz>> regenerateLectureQuizzes({
    required List<String> lectureIds,
    int questionCount = 10,
  }) async {
    final response = await http.post(
      _uri('/lectures/quiz-sets/regenerate'),
      headers: _authHeaders(json: true),
      body: jsonEncode({
        'lectureIds': lectureIds,
        'questionCount': questionCount,
      }),
    );
    return _decodeList(response).map(LectureQuiz.fromJson).toList();
  }

  Future<StudyPlanResult> createStudyPlan({
    required String course,
    required String examDate,
    required String scope,
    String? startDate,
    required String language,
    required int studyDaysPerWeek,
    required int sessionMinutes,
    List<String> lectureIds = const [],
  }) async {
    final response = await http.post(
      _uri('/study-plan'),
      headers: _optionalAuthJsonHeaders(),
      body: jsonEncode({
        'course': course,
        'exam_date': examDate,
        'scope': scope,
        'start_date': startDate,
        'language': language,
        'study_days_per_week': studyDaysPerWeek,
        'session_minutes': sessionMinutes,
        'lectureIds': lectureIds,
      }),
    );
    return StudyPlanResult.fromJson(_decodeMap(response));
  }

  Future<Map<String, String>> translateEmail({
    required String text,
    required List<String> languages,
  }) async {
    final response = await http.post(
      _uri('/email-translate'),
      headers: _optionalAuthJsonHeaders(),
      body: jsonEncode({
        'text': text,
        'languages': languages,
      }),
    );
    final payload = _decodeMap(response);
    final translations = payload['translations'] as Map<String, dynamic>? ?? const {};
    return translations.map((key, value) => MapEntry(key, value.toString()));
  }

  Future<SolveSessionState> createSolveSession({
    required String problem,
    required String problemType,
    required String language,
  }) async {
    final response = await http.post(
      _uri('/solve-problem/sessions'),
      headers: _optionalAuthJsonHeaders(),
      body: jsonEncode({
        'problem': problem,
        'problem_type': problemType,
        'language': language,
      }),
    );
    return SolveSessionState.fromJson(_decodeMap(response));
  }

  Future<SolveSessionState> getSolveSession(String sessionId) async {
    final response = await http.get(
      _uri('/solve-problem/sessions/$sessionId'),
      headers: _optionalAuthHeaders(),
    );
    return SolveSessionState.fromJson(_decodeMap(response));
  }

  Future<SolveSessionState> submitSolveAnswer({
    required String sessionId,
    required String answer,
  }) async {
    final response = await http.post(
      _uri('/solve-problem/sessions/$sessionId/answer'),
      headers: _optionalAuthJsonHeaders(),
      body: jsonEncode({
        'answer': answer,
      }),
    );
    return SolveSessionState.fromJson(_decodeMap(response));
  }

  Uri _uri(String path) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBase$normalizedPath');
  }

  Map<String, String> _jsonHeaders() => const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Map<String, String> _authHeaders({bool json = false}) {
    final value = token;
    if (value == null || value.isEmpty) {
      throw ApiException('Login is required for this request.');
    }
    return {
      if (json) ..._jsonHeaders() else 'Accept': 'application/json',
      'Authorization': 'Bearer $value',
    };
  }

  Map<String, String> _optionalAuthHeaders() {
    final headers = <String, String>{'Accept': 'application/json'};
    final value = token;
    if (value != null && value.isNotEmpty) {
      headers['Authorization'] = 'Bearer $value';
    }
    return headers;
  }

  Map<String, String> _optionalAuthJsonHeaders() {
    final headers = <String, String>{..._jsonHeaders()};
    final value = token;
    if (value != null && value.isNotEmpty) {
      headers['Authorization'] = 'Bearer $value';
    }
    return headers;
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    final payload = _decodeBody(response);
    if (payload is Map<String, dynamic>) {
      return payload;
    }
    throw ApiException('Unexpected response payload', statusCode: response.statusCode);
  }

  List<Map<String, dynamic>> _decodeList(http.Response response) {
    final payload = _decodeBody(response);
    if (payload is List) {
      return payload.whereType<Map<String, dynamic>>().toList();
    }
    throw ApiException('Unexpected response payload', statusCode: response.statusCode);
  }

  dynamic _decodeBody(http.Response response) {
    final isJson = response.body.trim().isNotEmpty;
    final decoded = isJson ? jsonDecode(response.body) : null;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    String message = 'Request failed (${response.statusCode})';
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      if (detail is String && detail.isNotEmpty) {
        message = detail;
      } else if (detail is List && detail.isNotEmpty) {
        message = _formatValidationDetails(detail);
      }
    }
    throw ApiException(message, statusCode: response.statusCode);
  }

  String _formatValidationDetails(List<dynamic> detail) {
    final messages = <String>[];
    for (final item in detail) {
      if (item is! Map<String, dynamic>) {
        messages.add(item.toString());
        continue;
      }
      final path = (item['loc'] as List<dynamic>? ?? const [])
          .skip(1)
          .map((part) => part.toString())
          .where((part) => part.isNotEmpty)
          .join('.');
      final text = item['msg']?.toString().trim() ?? 'Invalid value';
      messages.add(path.isEmpty ? text : '$path: $text');
    }
    return messages.join('\n');
  }
}
