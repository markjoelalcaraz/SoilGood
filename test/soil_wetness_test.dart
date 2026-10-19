import 'package:flutter_test/flutter_test.dart';
import 'package:soil_sense/core/soil/soil_texture.dart';
import 'package:soil_sense/core/soil/soil_wetness.dart';

void main() {
  test('sandy loam 18% probe reads as mid wetness', () {
    expect(wetnessFromSensor(18, SoilTexture.sandyLoam), closeTo(43.9, 0.1));
  });

  test('wetness is capped at 100', () {
    expect(wetnessFromSensor(60, SoilTexture.sandy), 100);
  });

  test('unknown texture uses the loam default', () {
    expect(wetnessFromSensor(21.5, null), closeTo(50, 0.1));
  });

  test('texture mismatch only when clearly above saturation', () {
    expect(sensorAboveTextureSaturation(45, SoilTexture.sandyLoam), isFalse);
    expect(sensorAboveTextureSaturation(55, SoilTexture.sandyLoam), isTrue);
    expect(sensorAboveTextureSaturation(80, null), isFalse);
  });
}
