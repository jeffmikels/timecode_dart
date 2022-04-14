import 'package:timecode/timecode.dart';

void main() {
  var fps = 29.97;
  var timecode = Timecode.atSeconds(59, framerate: TimecodeFramerate(29.97));
  timecode.addFrames(28);
  print(timecode);
  // for (var i = 0; i < fps; i++) {
  //   timecode.next();
  //   print(timecode);
  // }
}
