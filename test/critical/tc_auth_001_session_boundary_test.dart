/// TC_AUTH_001 / TC_AUTH_002 — session ownership + secret stripping (unit).
///
/// Related: TS-04 Auth / RLS farm boundary. Docs: docs/testing/CRITICAL_TEST_CASES.md
/// Full Postgres RLS is still a later SQL/integration check.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:soil_sense/features/auth/logic/session_access_rules.dart';

void main() {
  const userA = 'user-a-uid';
  const userB = 'user-b-uid';
  const farmA = 'farm-a-id';
  const farmB = 'farm-b-id';
  const deviceA = 'device-a-id';
  const deviceB = 'device-b-id';

  final farms = [
    {'id': farmA, 'owner_id': userA},
    {'id': farmB, 'owner_id': userB},
  ];
  final devices = [
    {'id': deviceA, 'farm_id': farmA, 'ingest_token': 'secret-a'},
    {'id': deviceB, 'farm_id': farmB, 'ingest_token': 'secret-b'},
  ];
  final soilRows = [
    {
      'id': 'reading-a',
      'device_id': deviceA,
      'moisture_percent': 42,
    },
    {
      'id': 'reading-b',
      'device_id': deviceB,
      'moisture_percent': 55,
    },
  ];

  group('TC_AUTH_001 owner can see own farm soil path', () {
    test('signed-in uid is required and accepted', () {
      expect(requireSignedInUserId(userA), userA);
    });

    test('owner A resolves only Farm A devices and soil', () {
      final ownedFarms = farmIdsOwnedBy(uid: userA, farms: farms);
      expect(ownedFarms, [farmA]);

      final ownedDevices = deviceIdsForOwnedFarms(
        ownedFarmIds: ownedFarms,
        devices: devices,
      );
      expect(ownedDevices, [deviceA]);

      final rows = soilRowsForOwnedDevices(
        rows: soilRows,
        ownedDeviceIds: ownedDevices,
      );
      expect(rows.length, 1);
      expect(rows.first['id'], 'reading-a');
      expect(rows.first['moisture_percent'], 42);
    });
  });

  group('TC_AUTH_002 cross-farm and secrets denied', () {
    test('no session → hard fail', () {
      expect(
        () => requireSignedInUserId(null),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            kNoSignedInUserMessage,
          ),
        ),
      );
      expect(() => requireSignedInUserId('  '), throwsStateError);
    });

    test('user B cannot pull user A soil when scope is built from owner_id', () {
      final ownedFarms = farmIdsOwnedBy(uid: userB, farms: farms);
      final ownedDevices = deviceIdsForOwnedFarms(
        ownedFarmIds: ownedFarms,
        devices: devices,
      );
      final rows = soilRowsForOwnedDevices(
        rows: soilRows,
        ownedDeviceIds: ownedDevices,
      );

      expect(ownedFarms, [farmB]);
      expect(ownedDevices, [deviceB]);
      expect(rows.map((r) => r['id']), ['reading-b']);
      expect(rows.any((r) => r['id'] == 'reading-a'), isFalse);
    });

    test('forged farm A is not in user B owner filter', () {
      expect(farmIdsOwnedBy(uid: userB, farms: farms), isNot(contains(farmA)));
      final safeDevices = deviceIdsForOwnedFarms(
        ownedFarmIds: farmIdsOwnedBy(uid: userB, farms: farms),
        devices: devices,
      );
      expect(safeDevices, [deviceB]);
      expect(safeDevices, isNot(contains(deviceA)));
    });

    test('farmerSafeDeviceRow strips ingest_token', () {
      final safe = farmerSafeDeviceRow({
        'id': deviceA,
        'claim_code': 'SG-7K2M',
        'ingest_token': 'must-not-leak',
        'ingestToken': 'also-must-not-leak',
      });
      expect(safe.containsKey('ingest_token'), isFalse);
      expect(safe.containsKey('ingestToken'), isFalse);
      expect(safe['claim_code'], 'SG-7K2M');
    });

    test('client must not use service_role key names', () {
      expect(
        isForbiddenClientSupabaseKeyName('SUPABASE_SERVICE_ROLE_KEY'),
        isTrue,
      );
      expect(isForbiddenClientSupabaseKeyName('SERVICE_ROLE_KEY'), isTrue);
      expect(isForbiddenClientSupabaseKeyName('SUPABASE_ANON_KEY'), isFalse);
    });
  });
}
