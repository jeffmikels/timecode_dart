import 'package:timecode/timecode.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    final t24 = Timecode(framerate: TimecodeFramerate(24));
    final t2398 = Timecode(framerate: TimecodeFramerate(23.98));
    final t2997 = Timecode(framerate: TimecodeFramerate(29.97));
    final t30 = Timecode(framerate: TimecodeFramerate(30));
    final t5994 = Timecode(framerate: TimecodeFramerate(59.94));
    final t60 = Timecode(framerate: TimecodeFramerate(60));
    final t1000 = Timecode(framerate: TimecodeFramerate(1000));

    setUp(() {
      // Additional setup goes here.
    });

    test('First Test', () {
      expect(t24.toString(), equals('00:00:00:00'));
      expect(t2398.toString(), equals('00:00:00:00'));
      expect(t2997.toString(), equals('00:00:00;00'));
      expect(t30.toString(), equals('00:00:00:00'));
      expect(t5994.toString(), equals('00:00:00;00'));
      expect(t60.toString(), equals('00:00:00:00'));
      expect(t1000.toString(), equals('00:00:00.000'));
    });
  });
}
