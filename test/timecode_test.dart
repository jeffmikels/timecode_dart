import 'package:timecode/timecode.dart';
import 'package:test/test.dart';

void main() {
  group('Testing...', () {
    setUp(() {
      // Additional setup goes here.
    });

    test('Millis', () {
      final t1000 = Timecode(framerate: TimecodeFramerate(1000));
      expect(t1000.toString(), equals('00:00:00.000'));

      final t60 = Timecode(framerate: TimecodeFramerate(60));
      t60.forceFractionalSeconds = true;
      expect(t60.toString(), equals('00:00:00.000'));
    });

    test('Drop Frame Flags', () {
      final t2997 = Timecode(framerate: TimecodeFramerate(29.97));
      final t5994 = Timecode(framerate: TimecodeFramerate(59.94));
      for (var testable in [t2997, t5994]) {
        expect(testable.toString(), equals('00:00:00;00'));
        expect(testable.isDropFrame, isTrue);
      }
    });

    test('Non Drop Frame Flags', () {
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

    test('Constructors', () {
      var t = Timecode.atTimecode('00:00:59:00');
      expect(t.toString(), equals('00:00:59:00'));
      expect(t.framerate.fps, equals(24));
      expect(t.frameCount, equals(24 * 59));

      t = Timecode.atTimecode('00:00:59;00');
      expect(t.toString(), equals('00:00:59;00'));
      expect(t.framerate.fps, equals(29.97));
      expect(t.frameCount, equals((30 * 59).floor()));

      t = Timecode.atTimecode('00:00:59.000');
      expect(t.toString(), equals('00:00:59.000'));
      expect(t.framerate.fps, equals(1000));
      expect(t.frameCount, equals(1000 * 59));

      t = Timecode.atSeconds(10, framerate: TimecodeFramerate(24));
      expect(t.toString(), equals('00:00:10:00'));

      t = Timecode.atSeconds(10, framerate: TimecodeFramerate(29.97));
      expect(t.toString(), equals('00:00:09;29'));

      t = Timecode();
      expect(t.toString(), equals('00:00:00:00'));
      expect(t.frameCount, equals(0));
    });

    test('Drop Frame Increments with 29.97', () {
      var t = Timecode.atTimecode('00:00:59;00', framerate: TimecodeFramerate(29.97));
      t.addFrames(29);
      expect(t.toString(), equals('00:00:59;29'));
      t.next();
      expect(t.toString(), equals('00:01:00;02'));
      t.next();
      expect(t.toString(), equals('00:01:00;03'));
    });

    test('Forced Non Drop Frame Increments with 29.97', () {
      var t = Timecode.atTimecode('00:00:59:00', framerate: TimecodeFramerate(29.97, forceNonDropFrame: true));
      t.addFrames(29);
      expect(t.toString(), equals('00:00:59:29'));
      t.next();
      expect(t.toString(), equals('00:01:00:00'));
      t.next();
      expect(t.toString(), equals('00:01:00:01'));
    });

    test('Non Drop Frame Increments', () {
      var t = Timecode.atSeconds(10, framerate: TimecodeFramerate(24));
      t.addFrames(23);
      expect(t.toString(), equals('00:00:10:23'));
      t.next();
      expect(t.toString(), equals('00:00:11:00'));
    });
  });
}
