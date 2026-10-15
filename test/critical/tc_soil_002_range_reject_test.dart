/// TC_SOIL_002 — Reject out-of-range ingest values (unit).
///
/// Related: TS-02 Soil ingest + validation. Mirrors supabase_esp32_ingest.sql.
/// Docs: docs/testing/CRITICAL_TEST_CASES.md
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soil_sense/core/soil/soil_ingest_ranges.dart';

void main() {
  group('TC_SOIL_002 out-of-range ingest rejection', () {
    test('rejects moisture below 0 or above 100', () {
      expect(
        validateSoilIngestRanges(moisturePercent: -1).error,
        'moisture out of range',
      );
      expect(
        validateSoilIngestRanges(moisturePercent: 101).error,
        'moisture out of range',
      );
    });

    test('rejects pH below 0 or above 14', () {
      expect(
        validateSoilIngestRanges(ph: -0.1).error,
        'ph out of range',
      );
      expect(
        validateSoilIngestRanges(ph: 14.1).error,
        'ph out of range',
      );
    });

    test('rejects salinity below 0 or above 20000', () {
      expect(
        validateSoilIngestRanges(salinity: -1).error,
        'salinity out of range',
      );
      expect(
        validateSoilIngestRanges(salinity: 20001).error,
        'salinity out of range',
      );
    });

    test('reports moisture before pH when both invalid', () {
      expect(
        validateSoilIngestRanges(moisturePercent: 120, ph: 20).error,
        'moisture out of range',
      );
    });
  });

  group('TC_SOIL_001 in-range ingest acceptance (unit slice)', () {
    test('accepts boundary and typical seed values', () {
      expect(validateSoilIngestRanges(moisturePercent: 0).isValid, isTrue);
      expect(validateSoilIngestRanges(moisturePercent: 100).isValid, isTrue);
      expect(validateSoilIngestRanges(ph: 0).isValid, isTrue);
      expect(validateSoilIngestRanges(ph: 14).isValid, isTrue);
      expect(validateSoilIngestRanges(salinity: 0).isValid, isTrue);
      expect(validateSoilIngestRanges(salinity: 20000).isValid, isTrue);
      expect(
        validateSoilIngestRanges(
          moisturePercent: 45,
          ph: 6.5,
          salinity: 0.5,
        ).isValid,
        isTrue,
      );
    });

    test('null fields are allowed (SQL optional params)', () {
      expect(validateSoilIngestRanges().isValid, isTrue);
    });
  });
}
