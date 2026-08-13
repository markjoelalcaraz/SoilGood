/// Calls the `soilgood-insights` Edge Function (Groq key stays on the server).
///
/// Home, Crops, and Analytics clients send a job name plus compact facts.
/// No soil data → the function returns `no_reading` and does not call Groq.
library;

import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_bootstrap.dart';

const kGroqModel = 'llama-3.3-70b-versatile';
const kInsightsFunction = 'soilgood-insights';

/// Thrown when the insights Edge Function cannot return usable JSON.
class GroqChatException implements Exception {
  const GroqChatException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// One POST to `soilgood-insights`; returns the parsed Groq JSON object.
class GroqChatClient {
  /// Runs [job] (`home` / `analytics` / `crops.care`) with JSON [userPayload].
  Future<Map<String, dynamic>> completeJson({
    required String job,
    required Object userPayload,
  }) async {
    if (supabase.auth.currentSession == null) {
      throw const GroqChatException('Sign in required for AI insights.');
    }

    try {
      final res = await supabase.functions
          .invoke(
            kInsightsFunction,
            body: {
              'job': job,
              'payload': userPayload,
            },
          )
          .timeout(const Duration(seconds: 25));

      final data = res.data;
      if (res.status < 200 || res.status >= 300) {
        throw GroqChatException(_messageFrom(data, res.status));
      }
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      throw const GroqChatException(
        'Insights API returned an unexpected body. Pull to try again.',
      );
    } on GroqChatException {
      rethrow;
    } on FunctionException catch (e) {
      throw GroqChatException(_messageFrom(e.details, e.status));
    } catch (e) {
      throw GroqChatException('Insights API failed: $e');
    }
  }

  static String _messageFrom(Object? data, int status) {
    final map = _asMap(data);
    final error = map?['error'] as String?;
    final message = map?['message'] as String?;
    if (error == 'no_reading') {
      return message ?? 'No soil data yet — AI was not called.';
    }
    if (error == 'missing_groq_key') {
      return message ?? 'Set GROQ_API_KEY in Edge Function secrets.';
    }
    if (message != null && message.isNotEmpty) return message;
    if (error != null && error.isNotEmpty) {
      return 'Insights API error ($error).';
    }
    return 'Insights API failed ($status). Deploy soilgood-insights and set '
        'GROQ_API_KEY in Dashboard secrets.';
  }

  static Map<String, dynamic>? _asMap(Object? data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      final text = data.trim();
      if (text.startsWith('{')) {
        try {
          final decoded = jsonDecode(text);
          if (decoded is Map<String, dynamic>) return decoded;
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } on FormatException {
          return null;
        }
      }
    }
    return null;
  }
}
