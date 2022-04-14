import 'package:timecode/timecode.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    setUp(() {
      // Additional setup goes here.
    });

    test('Testing Millis', () {
      final t1000 = Timecode(framerate: TimecodeFramerate(1000));
      expect(t1000.toString(), equals('00:00:00.000'));

      final t60 = Timecode(framerate: TimecodeFramerate(60));
      t60.forceFractionalSeconds = true;
      expect(t60.toString(), equals('00:00:00.000'));
    });

    test('Testing Drop Frame', () {
      final t2997 = Timecode(framerate: TimecodeFramerate(29.97));
      final t5994 = Timecode(framerate: TimecodeFramerate(59.94));
      for (var testable in [t2997, t5994]) {
        expect(testable.toString(), equals('00:00:00;00'));
        expect(testable.isDropFrame, isTrue);
      }
    });

    test('Testing Non Drop Frame', () {
      final t24 = Timecode(framerate: TimecodeFramerate(24));
      final t2398 = Timecode(framerate: TimecodeFramerate(23.98));
      final t30 = Timecode(framerate: TimecodeFramerate(30));
      final t60 = Timecode(framerate: TimecodeFramerate(60));
      final t2997 = Timecode(framerate: TimecodeFramerate(29.97, forceNonDropFrame: true));
      final t5994 = Timecode(framerate: TimecodeFramerate(59.94, forceNonDropFrame: true));

      for (var testable in [t24, t2398, t30, t60, t2997, t5994]) {
        expect(testable.toString(), equals('00:00:00:00'));
        expect(testable.isDropFrame, isFalse);
      }
    });

    test('Testing Constructors', () {
      var t = Timecode.atSeconds(10, framerate: TimecodeFramerate(24));
      expect(t.toString(), equals('00:00:10:00'));
      t = Timecode.atSeconds(10, framerate: TimecodeFramerate(29.97));
      expect(t.toString(), equals('00:00:10;00'));
    });

    test('Testing Drop Frame Increments', () {
      var t = Timecode.atSeconds(59, framerate: TimecodeFramerate(29.97));
      t.addFrames(27);
      expect(t.toString(), equals('00:00:59;27'));
      t.next();
      expect(t.toString(), equals('00:01:00;00'));
    });

    test('Testing Non Drop Frame Increments', () {
      var t = Timecode.atSeconds(10, framerate: TimecodeFramerate(24));
      expect(t.toString(), equals('00:00:10:00'));
    });
  });
}
