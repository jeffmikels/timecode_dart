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
/// at 59.94 fps, the next frame after 00:00:59;59 will be 00:01:00;02 (skipping 0 & 1)
///
/// We implement drop frame timecodes by internally keeping track of real frames
/// and timecode frames.
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
  int _frames = 0;
  int get frames => _frames;
  set frames(int n) {
    if (n < 0) throw TimecodeException('frames must be given in integers greater than zero. Received: $n');
    _frames = n;
    _recomputeValues();
  }

  TimecodeData _data = TimecodeData();

  // these are the variables
  int get hh => _data.hh;
  int get mm => _data.mm;
  int get ss => _data.ss;

  /// will honor the drop frame setting
  int get ff => _data.ff;

  /// fractional seconds in milliseconds honors drop frame
  int get frac => _data.frac;

  /// millis reflects the realtime duration of this instance
  int get millis => _data.millis;

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
  /// timecode to start at a specific value. Otherwise, the timecode will start
  /// at '00:00:00:00' or '00:00:00.000' depending on the framerate
  Timecode({
    TimecodeFramerate? framerate,
    int startFrames = 0,
  }) : framerate = framerate ?? TimecodeFramerate(defaultFPS) {
    frames = startFrames;
  }

  /// Creates a timecode with a specific timecode string and framerate.
  factory Timecode.atTimecode(String timecodeString, {TimecodeFramerate? framerate}) {
    framerate ??= TimecodeFramerate(defaultFPS);
    var startFrames = parseToFrames(timecodeString, framerate: framerate);
    return Timecode(framerate: framerate, startFrames: startFrames);
  }

  /// Creates a timecode at a specific number of seconds with a specified framerate.
  factory Timecode.atSeconds(double seconds, {TimecodeFramerate? framerate}) {
    framerate ??= TimecodeFramerate(defaultFPS);
    var startFrames = framerate.secondsToFrames(seconds);
    return Timecode(framerate: framerate, startFrames: startFrames);
  }

  /// dropframe timecodes look like this 00:00:00;00 (semicolon)
  /// ms timecodes look like this 00:00:00.000 (decimal + 3 digits)
  /// others look like this HH:MM:SS:FF
  ///
  /// The calculation of this timecode is modified from the math
  /// of the pytimecode library. Any errors in the implementation
  /// are my own.
  static int parseToFrames(String timecodeString, {TimecodeFramerate? framerate}) {
    framerate ??= TimecodeFramerate(defaultFPS);
    var isDropFrame = timecodeString.contains(';');
    if (isDropFrame != framerate.isDropFrame) {
      throw TimecodeException(
          'timecode string and framerate mismatch. Framerates that employ drop frame encoding (29.97 and 59.94) use a timecode format like this 00:00:00;00');
    }
    var parts = timecodeString.replaceFirst(';', ':').split(':').map<double>((e) => double.tryParse(e) ?? 0).toList();

    // if the timecode were fractional, there will be only three elements
    if (parts.length < 3) return 0;

    var hh = parts[0];
    var mm = parts[1];
    var ss = parts[2];
    var ff = (parts.length == 4) ? parts[3] : 0;

    var totalMinutes = mm + hh * 60;
    var totalSeconds = ss + totalMinutes * 60;
    var totalFrames = (totalSeconds * framerate.integerFps + ff).floor();
    return framerate.realFrames(totalFrames);
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
  int get hashCode => _frames.hashCode;

  void _recomputeValues() {
    _data = framerate.parseFrames(frames);
  }

  void addFrames(int n) => frames = frames + n;
  void subFrames(int n) => frames = frames - n;
  void multFrames(int n) => frames = frames * n;
  void divFrames(int n) => frames = frames ~/ n;
  void next() => addFrames(1);
  void back() => frames > 0 ? subFrames(1) : null;

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

/// The frame rate of a Timecode instance. It may be based on any
/// arbitrary floating point value, but usually will be one of the industry
/// standard framerates: 23.976, 23.98, 24, 25, 29.97, 30, 50, 59.94, 60, 1000.
/// If the framerate is either 29.97 or 59.94, the internal [isDropFrame] flag
/// will be set unless `forceNonDropFrame` is specified in the constructor.
class TimecodeFramerate {
  final double fps;
  final int integerFps;
  final bool isDropFrame;

  /// [droppedFramesPerMinute] is the number of frames to drop every minute
  /// and is computed as the nearest integer to 6% of the full fps
  final int droppedFramesPerMinute;

  const TimecodeFramerate._(this.fps, this.integerFps, this.isDropFrame, this.droppedFramesPerMinute);

  /// Will create a [TimecodeFramerate] instance. [fps] may be any
  /// arbitrary floating point value, but usually will be one of the industry
  /// standard framerates: 23.976, 23.98, 24, 25, 29.97, 30, 50, 59.94, 60, 1000.
  /// If the framerate is either 29.97 or 59.94, the internal [isDropFrame] flag
  /// will be set unless [forceNonDropFrame] is specified in the constructor.
  factory TimecodeFramerate(double fps, {forceNonDropFrame = false}) {
    var integerFramerate = fps.round();
    var isDropFrame = false;

    // compute the integer framerate and drop frame status if needed.
    switch ((fps * 1000).round()) {
      case 29970:
        isDropFrame = !forceNonDropFrame;
        break;
      case 59940:
        isDropFrame = !forceNonDropFrame;
        break;
    }
    var dfpm = isDropFrame ? (fps * 0.0666666).round() : 0;
    return TimecodeFramerate._(fps, integerFramerate, isDropFrame, dfpm);
  }

  int secondsToFrames(double seconds) {
    // timecode rolls over after 24 hours
    seconds %= 60 * 60 * 24;
    if (!isDropFrame) return (seconds * fps).floor();
    var framesBeforeDrop = (seconds * integerFps).floor();
    return realFrames(framesBeforeDrop);
  }

  TimecodeData parseFrames(int frames, {ignoreDropFrame = false}) {
    // Number of frames in a day - timecode rolls over after 24 hours
    var framesPer24Hours = (fps * 60 * 60 * 24).round();
    frames %= framesPer24Hours;
    var effectiveFps = fps;
    if (!ignoreDropFrame) {
      frames = timecodeFrames(frames);
      if (isDropFrame) effectiveFps = integerFps.toDouble();
    }
    var seconds = frames / effectiveFps;
    var ws = seconds.floor();
    var hh = (ws ~/ 60) ~/ 60;
    var mm = (ws ~/ 60) % 60;
    var ss = ws % 60;
    var ff = frames - (ws * effectiveFps).floor();
    var millis = (seconds * 1000).floor();
    var frac = (1000 * (seconds % 60)).floor();

    return TimecodeData(hh, mm, ss, ff, frac, millis);
  }

  /// timecode frames will be equal to or larger than real frames
  /// in 59.94 fps, after one minute, two frames will be added to
  /// the timecode frame count
  int timecodeFrames(int realFrames) {
    var frames = realFrames;
    if (isDropFrame) {
      // Number of frames per minute is the integer framerate * 60 minus
      // the number of dropped frames.
      var framesPerMinute = integerFps * 60 - droppedFramesPerMinute;
      var totalMinutes = frames ~/ framesPerMinute;
      var minutesWithDroppedFrames = totalMinutes - (totalMinutes ~/ 10);

      // Add the dropped frames back in
      frames += minutesWithDroppedFrames * droppedFramesPerMinute;
    }
    return frames;
  }

  /// timecode frames will be equal to or larger than real frames
  /// in 59.94 fps, after one minute, two frames will be added to
  /// the timecode frame count
  int realFrames(int timecodeFrames) {
    var frames = timecodeFrames;
    if (isDropFrame) {
      var seconds = frames ~/ integerFps;
      var totalMinutes = seconds ~/ 60;
      var minutesWithDroppedFrames = totalMinutes - (totalMinutes ~/ 10);

      // Remove the dropped frames back in
      frames += minutesWithDroppedFrames * droppedFramesPerMinute;
    }
    return frames;
  }
}

class TimecodeSecondsWithFrames {
  double seconds;

  int fractionAsFrames;
  int get wholeSeconds => seconds.floor();

  TimecodeSecondsWithFrames(this.seconds, this.fractionAsFrames);
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

  const TimecodeData([this._hh = 0, this._mm = 0, this._ss = 0, this._ff = 0, this._frac = 0, this._millis = 0]);
}

class TimecodeException implements Exception {
  String message;
  TimecodeException(this.message);
  @override
  String toString() {
    return "TimecodeException: $message";
  }
}
