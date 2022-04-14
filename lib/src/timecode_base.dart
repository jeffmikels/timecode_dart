const double defaultFPS = 24;

/// Some parts have been copied / inspired by the pytimecode library by Joshua Banton
///
/// https://pypi.org/project/pytimecode.py/
///
/// Notes: *There is a 24 hour SMPTE Timecode limit, so if your time exceeds that limit, it will roll over.
///
/// [Timecode] Does all the calculation over frames, so the main data it holds is
/// frames, then when required it converts the frames to a timecode by
/// using the frame rate setting.
///
/// Note: Drop frame timecodes operate by reporting higher frame numbers
/// than really exist so that 29.97 timecodes stay in sync with 30 fps ones, etc.
///
/// Drop Frame Example:
///
/// at 29.97 fps, the next frame after 00:00:59;29 will be 00:01:00;02 (skipping 0 & 1)
/// See the document here: https://www.connect.ecuad.ca/~mrose/pdf_documents/timecode.pdf
///
/// Drop Frame Calculations are done by implementing code found here:
/// - https://www.davidheidelberger.com/2010/06/10/drop-frame-timecode/
/// - https://robwomack.com/timecode-calculator/
class Timecode extends Object {
  TimecodeFramerate framerate;

  // convenience getters ---
  bool get isDropFrame => framerate.isDropFrame;
  int get integerFps => framerate.integerFps;
  double get fps => framerate.fps;

  // display frames as fractions of a second instead of frame numbers
  bool get isMillis => integerFps == 1000;
  bool forceFractionalSeconds = false;

  /// _frames keeps track of the actual frame count
  int _frameCount = 0;
  int get frameCount => _frameCount;
  set frameCount(int n) {
    if (n < 0) throw TimecodeException('frames must be given in integers greater than zero. Received: $n');
    _frameCount = n;
    _recomputeParts();
  }

  /// the real timecode parts get updated whenever frames are changed
  TimecodeData parts = TimecodeData();

  // these are the variables
  int get hh => parts.hh;
  int get mm => parts.mm;
  int get ss => parts.ss;

  /// will always honor the drop frame setting in the framerate
  int get ff => parts.ff;

  /// fractional seconds in milliseconds honors drop frame
  int get frac => parts.frac;

  /// millis reflects the realtime duration of this instance
  int get millis => parts.millis;

  // helper for `toString` method
  String get frameDelimiter => isDropFrame
      ? ';'
      : isMillis || forceFractionalSeconds
          ? '.'
          : ':';

  /// Creates a new Timecode instance.
  ///
  /// @parameters:
  ///
  /// [framerate] a [TimecodeFramerate] instance.
  ///
  /// [startFrames] : Optional starting offset in frames. Use this to force the
  /// timecode to start at a specific frame value (in real frames).
  Timecode({
    TimecodeFramerate? framerate,
    int startFrames = 0,
  }) : framerate = framerate ?? TimecodeFramerate(defaultFPS) {
    _frameCount = startFrames;
    _recomputeParts();
  }

  /// Creates a timecode with a specific timecode string and framerate.
  ///
  /// If [framerate] is omitted, the following defaults will be used:
  /// - default timecodes (00:00:00:00) -> 24 fps
  /// - drop frame timecodes (00:00:00;00) -> 29.97 fps
  /// - ms timecodes (00:00:00.000) -> 1000 fps
  ///
  /// NOTE: When using drop frame framerates, some timecode strings are considered
  /// invalid and will be corrected to valid timecodes. Consider the following examples.
  ///
  /// ```dart
  /// var fps = TimecodeFramerate(29.97);
  /// Timecode.atTimecode('00:00:59;29', framerate: fps); // -> 00:00:59;29
  /// Timecode.atTimecode('00:01:00;00', framerate: fps); // -> 00:01:00;02 (!!)
  /// Timecode.atTimecode('00:01:00;01', framerate: fps); // -> 00:01:00;02 (!!)
  /// Timecode.atTimecode('00:01:00;02', framerate: fps); // -> 00:01:00;02
  /// ```
  factory Timecode.atTimecode(String timecodeString, {TimecodeFramerate? framerate}) {
    double def = 24;
    if (timecodeString.contains(';')) {
      def = 29.97;
    } else if (timecodeString.contains('.')) {
      def = 1000;
    }
    framerate ??= TimecodeFramerate(def);
    var startFrames = parseToFrames(timecodeString, framerate: framerate);
    return Timecode(framerate: framerate, startFrames: startFrames);
  }

  /// Creates a timecode at a specific number of seconds with a specified framerate.
  ///
  /// NOTE: When using fractional framerates, the resulting timecode may not match
  /// what you expect. Consider the following examples.
  ///
  /// ```dart
  /// var fps = TimecodeFramerate(29.97);
  /// Timecode.atSeconds(0, framerate: fps); // -> 00:00:00;00
  /// Timecode.atSeconds(1, framerate: fps); // -> 00:00:00;29
  /// Timecode.atSeconds(10, framerate: fps); // -> 00:00:09;29
  /// ```
  factory Timecode.atSeconds(double seconds, {TimecodeFramerate? framerate}) {
    framerate ??= TimecodeFramerate(defaultFPS);
    var startFrames = framerate.realSecondsToFrames(seconds);
    return Timecode(framerate: framerate, startFrames: startFrames);
  }

  /// The default format for a [timecodeString] is `HH:MM:SS:FF` where
  /// `FF` stands for the number of frames after the current second and
  /// may be `0 <= FF < fps`.
  ///
  /// When a drop frame encoding has been employed, the format will be
  /// `HH:MM:SS;FF` (final semicolon) or `HH;MM;SS;FF` (all semicolons).
  ///
  /// An alternate form looks like this `HH:MM:SS.SSS` where the seconds
  /// are specified in floating point form. This usually indicates the
  /// fps is 1000 (millisecond) but can be used with any framerate.
  static int parseToFrames(String timecodeString, {TimecodeFramerate? framerate}) {
    framerate ??= TimecodeFramerate(defaultFPS);
    var isDropFrame = timecodeString.contains(';');
    if (isDropFrame != framerate.isDropFrame) {
      throw TimecodeException(
          'timecode string and framerate mismatch. Framerates that employ drop frame encoding (29.97 and 59.94) use a timecode format like this 00:00:00;00');
    }
    var parts = timecodeString.replaceAll(';', ':').split(':').map<double>((e) => double.tryParse(e) ?? 0).toList();

    // if the timecode were fractional, there will be only three elements
    if (parts.length < 3) return 0;

    var hh = parts[0].toInt();
    var mm = parts[1].toInt();
    var ss = parts[2];
    int ff = (parts.length == 4) ? parts[3].toInt() : 0;

    var totalMinutes = mm + hh * 60;
    var totalSeconds = ss + totalMinutes * 60;
    var timecodeFrames = ff + framerate.timecodeSecondsToFrames(totalSeconds);
    return framerate.realFrames(timecodeFrames);
  }

  @override
  operator ==(Object other) {
    if (other is Timecode) {
      return other.millis == millis;
    }
    return false;
  }

  operator >(Timecode other) {
    return other.millis > millis;
  }

  operator <(Timecode other) {
    return other.millis < millis;
  }

  Timecode operator +(Timecode other) {
    var m = millis + other.millis;
    var seconds = m / 1000;
    return Timecode.atSeconds(seconds, framerate: framerate);
  }

  Timecode operator -(Timecode other) {
    var m = millis - other.millis;
    var seconds = m / 1000;
    return Timecode.atSeconds(seconds, framerate: framerate);
  }

  Timecode operator *(int multiplier) {
    var m = millis * multiplier;
    var seconds = m / 1000;
    return Timecode.atSeconds(seconds, framerate: framerate);
  }

  Timecode operator /(int divisor) {
    var m = millis / divisor;
    var seconds = m / 1000;
    return Timecode.atSeconds(seconds, framerate: framerate);
  }

  @override
  int get hashCode => _frameCount.hashCode;

  void _recomputeParts() {
    parts = framerate.parseFrames(frameCount);
  }

  void addFrames(int n) => frameCount = frameCount + n;
  void subFrames(int n) => frameCount = frameCount - n;
  void multFrames(int n) => frameCount = frameCount * n;
  void divFrames(int n) => frameCount = frameCount ~/ n;
  void next() => addFrames(1);
  void back() => frameCount > 0 ? subFrames(1) : null;

  @override
  String toString() {
    var hhs = hh.toString().padLeft(2, '0');
    var mms = mm.toString().padLeft(2, '0');
    var sss = ss.toString().padLeft(2, '0');
    var ffs = (forceFractionalSeconds || isMillis) ? frac.toString().padLeft(3, '0') : ff.toString().padLeft(2, '0');
    var delim = frameDelimiter;
    return '$hhs:$mms:$sss$delim$ffs';
  }
}

/// The framerate of a Timecode instance. It may be based on any
/// arbitrary floating point value, but usually will be one of the industry
/// standard framerates: 23.976, 23.98, 24, 25, 29.97, 30, 50, 59.94, 60, 1000.
/// If the framerate is either 29.97 or 59.94, the internal [isDropFrame] flag
/// will be set unless `forceNonDropFrame` is specified in the constructor.
///
/// This class handles all calculations regarding framerates. It handles
/// the drop frame calculations, and can convert between seconds and frames.
///
/// Drop Frame Calculations are done by implementing code found here:
/// - https://www.davidheidelberger.com/2010/06/10/drop-frame-timecode/
/// - https://robwomack.com/timecode-calculator/
///
/// However, Rob Womack's implementation uses the integer fps when
/// it should have used the full fps. David Heidelberger's code is likewise
/// ambiguous on when to use integer fps and when to use the full fps.
class TimecodeFramerate {
  final double fps;
  final int integerFps;
  final bool isDropFrame;

  /// [skippedFrameNumbersPerMinute] is the number of frames to drop every minute
  /// and is computed as the nearest integer to 6% of the full fps
  late final int skippedFrameNumbersPerMinute;
  late final int realFramesPerHour;
  late final int realFramesPer24Hours;
  late final int realFramesPer10Minutes;
  late final int timecodeFramesPerMinute;

  TimecodeFramerate._(this.fps, this.integerFps, this.isDropFrame) {
    // these are calculations that are used in dropFrame conversions
    skippedFrameNumbersPerMinute = isDropFrame ? (fps * 0.0666666).round() : 0;
    realFramesPerHour = (fps * 60 * 60).round();
    realFramesPer24Hours = realFramesPerHour * 24;
    realFramesPer10Minutes = (fps * 60 * 10).round();

    // timecodeFramesPerMinute uses the integerFps because it also accounts for dropFrames
    timecodeFramesPerMinute = (integerFps * 60) - skippedFrameNumbersPerMinute;
  }

  /// Will create a [TimecodeFramerate] instance. [fps] may be any
  /// arbitrary floating point value, but usually will be one of the industry
  /// standard framerates: 23.976, 23.98, 24, 25, 29.97, 30, 50, 59.94, 60, 1000.
  /// If the framerate is either 29.97 or 59.94, the internal [isDropFrame] flag
  /// will be set unless [forceNonDropFrame] is specified in the constructor.
  factory TimecodeFramerate(double fps, {forceNonDropFrame = false}) {
    var integerFramerate = fps.round();
    var isDropFrame = false;

    // compute the integer framerate and drop frame status if needed.
    switch ((fps * 100).round()) {
      case 2997:
        isDropFrame = !forceNonDropFrame;
        break;
      case 5994:
        isDropFrame = !forceNonDropFrame;
        break;
    }
    return TimecodeFramerate._(
      fps,
      integerFramerate,
      isDropFrame,
    );
  }

  double rollover(double seconds) {
    while (seconds < 0) {
      seconds += 60 * 60 * 24;
    }
    return seconds % (60 * 60 * 24);
  }

  /// returns real frame count from seconds of real time
  /// and does not account for drop frames
  /// if seconds > 24 hours, rolls over
  int realSecondsToFrames(double seconds) {
    seconds = rollover(seconds);
    return (seconds * fps).floor();
  }

  /// returns timecode frame count from timecode seconds.
  /// Timecode seconds are always based on the integerFps
  /// and that's why drop frames are needed
  /// will roll over after 24 hours
  int timecodeSecondsToFrames(double seconds, {ignoreDropFrame = false}) {
    seconds = rollover(seconds);
    return seconds.round() * integerFps;
    // return (seconds * ((isDropFrame && !ignoreDropFrame) ? integerFps : fps)).floor();
  }

  /// code modified for Dart and split into two functions
  /// from https://www.davidheidelberger.com/2010/06/10/drop-frame-timecode/
  TimecodeData parseFrames(int frameCount, {ignoreDropFrame = false}) {
    frameCount = timecodeFrames(frameCount, ignoreDropFrame: ignoreDropFrame);

    int frRound = fps.round();
    int ff = frameCount % frRound;
    int ss = (frameCount ~/ frRound) % 60;
    int mm = ((frameCount ~/ frRound) ~/ 60) % 60;
    int hh = (((frameCount ~/ frRound) ~/ 60) ~/ 60);
    int millis = (1000 * frameCount / frRound).floor(); // total time
    int frac = millis % 1000;

    // this is the "corrected" frame data
    return TimecodeData(hh, mm, ss, ff, frac, millis);
  }

  /// timecode frames will be equal to or larger than real frames.
  /// Example: in 29.97 fps, after each minute, two frames will be added to
  /// the timecode frame count, except after 10 minutes, no frames are added
  /// This function adds in the extra timecode frames.
  ///
  /// from https://www.davidheidelberger.com/2010/06/10/drop-frame-timecode/
  int timecodeFrames(int frameCount, {ignoreDropFrame = false}) {
    // always handle frameCount rollover

    // do not accept negative frame numbers
    while (frameCount < 0) {
      frameCount = realFramesPer24Hours + frameCount;
    }
    // greater than 24 hours rolls over to 0
    frameCount = frameCount % realFramesPer24Hours;

    if (isDropFrame && !ignoreDropFrame) {
      var dropFrames = skippedFrameNumbersPerMinute;
      int d = frameCount ~/ realFramesPer10Minutes;
      int m = frameCount % realFramesPer10Minutes;

      if (m > dropFrames) {
        frameCount = frameCount + (dropFrames * 9 * d) + dropFrames * ((m - dropFrames) ~/ timecodeFramesPerMinute);
      } else {
        frameCount = frameCount + dropFrames * 9 * d;
      }
    }

    return frameCount;
  }

  /// timecode frames will be equal to or larger than real frames.
  /// Example: in 29.97 fps, after each minute, two frames will be added to
  /// the timecode frame count, except after 10 minutes, no frames are added
  /// This code removes the extra timecode frames to get the real underlying
  /// frame count.
  int realFrames(int timecodeFrames) {
    var frames = timecodeFrames;

    if (isDropFrame) {
      var seconds = frames ~/ integerFps;
      var timecodeMinutes = seconds ~/ 60;
      var minutesWithDroppedFrames = timecodeMinutes - (timecodeMinutes ~/ 10);

      // Remove the extra timecode frames (the `drop frames`)
      frames -= minutesWithDroppedFrames * skippedFrameNumbersPerMinute;
    }
    return frames;
  }
}

/// Timecode data that is ignorant of framerate.
/// We use this to pass around structured timecode data
class TimecodeData {
  // these are the variables
  final int _hh;
  int get hh => _hh;
  final int _mm;
  int get mm => _mm;
  final int _ss;
  int get ss => _ss;
  final int _ff;
  int get ff => _ff;
  final int _frac; // fractional seconds in milliseconds
  int get frac => _frac;
  final int _millis;
  int get millis => _millis;

  const TimecodeData([
    this._hh = 0,
    this._mm = 0,
    this._ss = 0,
    this._ff = 0,
    this._frac = 0,
    this._millis = 0,
  ]);
}

class TimecodeException implements Exception {
  String message;
  TimecodeException(this.message);
  @override
  String toString() {
    return "TimecodeException: $message";
  }
}
