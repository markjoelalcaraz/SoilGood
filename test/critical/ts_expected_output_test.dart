/// Expected-output checks for TS-02, TS-03, TS-06, TS-07, and TS-10.
///
/// Automated with flutter test. Each test compares the app result to the
/// intended farmer-facing outcome (not only "no crash").
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soil_sense/core/ai/saved_assessment.dart';
import 'package:soil_sense/core/validation/app_validators.dart';
import 'package:soil_sense/features/home/data/soil_reading.dart';
import 'package:soil_sense/features/home/logic/home_ai_regen.dart';
import 'package:soil_sense/features/notifications/data/farm_notification.dart';
import 'package:soil_sense/features/notifications/logic/notification_evaluator.dart';
import 'package:soil_sense/features/onboarding/logic/onboarding_step_rules.dart';

void main() {
  final now = DateTime.utc(2026, 10, 11, 12);

  SoilReading reading() => SoilReading(
        id: 'r1',
        recordedAt: now.subtract(const Duration(minutes: 5)),
        moisturePercent: 18,
        ph: 4.2,
      );

  group('TS-02 registration and login fields', () {
    test('happy: valid email and signup password are accepted', () {
      expect(AppValidators.email('farmer@example.com'), isNull);
      expect(AppValidators.signupPassword('Farmpass1!'), isNull);
      expect(AppValidators.loginPassword('Farmpass1!'), isNull);
    });

    test('error: bad email and weak password are rejected with clear text', () {
      expect(
        AppValidators.email('not-an-email'),
        'Enter a valid email address.',
      );
      expect(AppValidators.loginPassword(''), 'Password is required.');
      expect(
        AppValidators.signupPassword('password'),
        'Use 8+ characters with a letter, a number, and a symbol.',
      );
    });
  });

  group('TS-03 onboarding order', () {
    test('happy: profile, pin, texture, then device, then done', () {
      expect(
        nextOnboardingStep(
          firstName: '',
          hasFarm: false,
          soilTexture: null,
          hasDevice: false,
        ),
        OnboardingStep.profile,
      );
      expect(
        nextOnboardingStep(
          firstName: 'Juan',
          hasFarm: false,
          soilTexture: null,
          hasDevice: false,
        ),
        OnboardingStep.location,
      );
      expect(
        nextOnboardingStep(
          firstName: 'Juan',
          hasFarm: true,
          soilTexture: 'clay_loam',
          hasDevice: false,
        ),
        OnboardingStep.device,
      );
      expect(
        nextOnboardingStep(
          firstName: 'Juan',
          hasFarm: true,
          soilTexture: 'clay_loam',
          hasDevice: true,
        ),
        OnboardingStep.done,
      );
    });

    test('error: empty texture does not skip to device claim', () {
      expect(
        nextOnboardingStep(
          firstName: 'Juan',
          hasFarm: true,
          soilTexture: '   ',
          hasDevice: false,
        ),
        OnboardingStep.soilTexture,
      );
    });
  });

  group('TS-06 water today output', () {
    const evaluator = NotificationEvaluator();

    test('happy: critical dry says water today', () {
      final drafts = evaluator.evaluate(
        farmId: 'farm',
        reading: reading(),
        facts: {
          'moisture': 'critical_dry',
          'n_band': 'ok',
          'p_band': 'ok',
          'k_band': 'ok',
          'ph_band': 'ok',
          'temp_band': 'ok',
          'ec_band': 'ok',
          'salinity_band': 'ok',
        },
        now: now,
      );
      final water = drafts.singleWhere(
        (d) => d.type == FarmNotificationType.irrigation,
      );
      expect(water.title, 'Soil is critically dry — water today');
      expect(water.body, contains('Water today'));
    });

    test('error: critical wet says do not water', () {
      final drafts = evaluator.evaluate(
        farmId: 'farm',
        reading: reading(),
        facts: {
          'moisture': 'critical_wet',
          'n_band': 'ok',
          'p_band': 'ok',
          'k_band': 'ok',
          'ph_band': 'ok',
          'temp_band': 'ok',
          'ec_band': 'ok',
          'salinity_band': 'ok',
        },
        now: now,
      );
      final water = drafts.singleWhere(
        (d) => d.type == FarmNotificationType.irrigation,
      );
      expect(water.title, 'Soil water is critically high');
      expect(water.body, contains('Do not water'));
    });
  });

  group('TS-07 out-of-band alerts', () {
    const evaluator = NotificationEvaluator();

    test('happy: critical pH creates an urgent soil alert', () {
      final drafts = evaluator.evaluate(
        farmId: 'farm',
        reading: reading(),
        facts: {
          'moisture': 'ok',
          'n_band': 'ok',
          'p_band': 'ok',
          'k_band': 'ok',
          'ph_band': 'critical_low',
          'temp_band': 'ok',
          'ec_band': 'ok',
          'salinity_band': 'ok',
        },
        now: now,
      );
      final soil = drafts.singleWhere(
        (d) => d.type == FarmNotificationType.soilAlert,
      );
      expect(soil.severity, FarmNotificationSeverity.urgent);
      expect(soil.title, 'Urgent: soil needs attention today');
      expect(soil.body, contains('pH is critically low'));
    });

    test('error: ok bands do not create soil or nutrient alerts', () {
      final drafts = evaluator.evaluate(
        farmId: 'farm',
        reading: reading(),
        facts: {
          'moisture': 'ok',
          'n_band': 'ok',
          'p_band': 'ok',
          'k_band': 'ok',
          'ph_band': 'ok',
          'temp_band': 'ok',
          'ec_band': 'ok',
          'salinity_band': 'ok',
        },
        now: now,
      );
      expect(
        drafts.any((d) => d.type == FarmNotificationType.soilAlert),
        isFalse,
      );
      expect(
        drafts.any((d) => d.type == FarmNotificationType.nutrientLow),
        isFalse,
      );
    });
  });

  group('TS-10 AI stays tied to the current story', () {
    SavedAssessment saved(String fingerprint) {
      return SavedAssessment(
        id: 'ai-1',
        farmId: 'farm',
        kind: 'home',
        overview: 'SGFP:$fingerprint\nTips for this story.',
        generatedAt: now,
        promptVersion: 'v1',
        recommendations: [
          AiRecommendation(
            type: 'irrigation',
            title: 'Water',
            description: 'tip',
            recommendedAction: 'water',
            priority: 'high',
            validUntil: DateTime.now().add(const Duration(hours: 6)),
          ),
        ],
      );
    }

    test('happy: same story reuses saved tips', () {
      expect(
        shouldRegenHomeAi(
          saved: saved('dry-story'),
          promptVersion: 'v1',
          currentFingerprint: 'dry-story',
        ),
        isFalse,
      );
    });

    test('error: changed story must not keep the old tips', () {
      expect(
        shouldRegenHomeAi(
          saved: saved('dry-story'),
          promptVersion: 'v1',
          currentFingerprint: 'wet-story',
        ),
        isTrue,
      );
    });
  });
}
