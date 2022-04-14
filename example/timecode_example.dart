import 'package:timecode/timecode.dart';

void main() {
  var fps = TimecodeFramerate(29.97);
  var testStrings = {
    '00:00:59;29': 1799,
    '00:01:00;02': 1800 * 1,
    '00:02:00;04': 1800 * 2,
    '00:03:00;06': 1800 * 3,
    '00:04:00;08': 1800 * 4,
    '00:05:00;10': 1800 * 5,
    '00:06:00;12': 1800 * 6,
    '00:07:00;14': 1800 * 7,
    '00:08:00;16': 1800 * 8,
    '00:09:00;18': 1800 * 9,
    '00:10:00;00': 17982,
    '01:10:00;00': 125874,
  };
  for (var tc in testStrings.keys) {
    var frame = testStrings[tc]!;
    var t1 = Timecode.atTimecode(tc, framerate: fps);
    print('$tc - $t1 - ${t1.frameCount} - $frame');
    var t2 = Timecode(framerate: fps, startFrames: frame);
    print('$tc - $t1 - ${t1.frameCount} - $frame');
    print(t1 == t2);
  }

  var timecode = Timecode.atTimecode('00:01:00;02', framerate: fps);
  print('$timecode - ${timecode.frameCount}');

  print(Timecode.atSeconds(0, framerate: fps)); // -> 00:00:00;00
  print(Timecode.atSeconds(1, framerate: fps)); // -> 00:00:00;29
  print(Timecode.atSeconds(10, framerate: fps)); // -> 00:00:09;29

  // for (var i = 0; i < 10; i++) {
  //   timecode.next();
  //   print('$timecode - ${timecode.frameCount}');
  // }
}
