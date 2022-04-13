const double defaultFPS = 24;

/// This is a reimplementation in Dart of the excellent PyTimeCode library
/// for Python by Joshua Banton
///
/// https://pypi.org/project/pytimecode.py/
///
/// This module is for the generating and manipulating of SMPTE timecode.
/// Supports 60, 59.94, 50, 30, 29.97, 25, 24, 23.98 frame rates in drop
/// and non-drop where applicable, and milliseconds. It also implements
/// operator overloading for equality, addition, subtraction, multiplication,
/// and division (when the two objects have the same framerate). To combine
/// objects of different framerates, use the instance methods.
///
/// [iterReturn] sets the format that iterations return, the options are "tc" for a timecode string,
/// "frames" for a int total frames, and "tc_tuple" for a tuple of ints in the following format,
/// (hours, minutes, seconds, frames).
///
/// Notes: *There is a 24 hour SMPTE Timecode limit, so if your time exceeds that limit, it will roll over.
///
/// [Timecode] Does all the calculation over frames, so the main data it holds is
/// frames, then when required it converts the frames to a timecode by
/// using the frame rate setting.
///
/// Parameters:
///
/// [framerate]: The frame rate of the Timecode instance. It
///   should be one of ['23.976', '23.98', '24', '25', '29.97', '30', '50',
///   '59.94', '60', 'NUMERATOR/DENOMINATOR', ms'] where "ms" equals to
///   1000 fps.
///   Can not be skipped.
///   Setting the framerate will automatically set the :attr:`.drop_frame`
///   attribute to correct value.
/// :param start_timecode: The start timecode. Use this to be able to
///   set the timecode of this Timecode instance. It can be skipped and
///   then the frames attribute will define the timecode, and if it is also
///   skipped then the start_second attribute will define the start
///   timecode, and if start_seconds is also skipped then the default value
///   of '00:00:00:00' will be used.
///   When using 'ms' frame rate, timecodes like '00:11:01.040' use '.040'
///   as frame number. When used with other frame rates, '.040' represents
///   a fraction of a second. So '00:00:00.040'@25fps is 1 frame.
/// :type framerate: str or int or float or tuple
/// :type start_timecode: str or None
/// :param start_seconds: A float or integer value showing the seconds.
/// :param int frames: Timecode objects can be initialized with an
///   integer number showing the total frames.
/// :param force_non_drop_frame: If True, uses Non-Dropframe calculation for
///   29.97 or 59.94 only. Has no meaning for any other framerate.
class Timecode extends Object {
  TimecodeFramerate framerate;

  // convenience getters ---
  bool get isDropFrame => framerate.isDropFrame;
  int get integerFps => framerate.integerFps;
  double get fps => framerate.fps;

  // display frames as fractions of a second instead of frame numbers
  bool get isMillis => integerFps == 1000;

  bool forceFractionalSeconds = false;

  int _frames = 0;
  int get frames => _frames;
  set frames(int n) {
    if (n < 0) throw TimecodeException('frames must be given in integers greater than zero. Received: $n');
    _frames = n;
    _recomputeValues();
  }

  int _hh = 0;
  int get hh => _hh;
  int _mm = 0;
  int get mm => _mm;
  int _ss = 0;
  int get ss => _ss;
  int _ff = 0;
  int get ff => _ff;
  int _frac = 0; // fractional seconds in milliseconds
  int get frac => _frac;
  int _millis = 0;
  int get millis => _millis;

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
    var startFrames = parse(timecodeString, framerate: framerate);
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
  static int parse(String timecodeString, {TimecodeFramerate? framerate}) {
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
    return framerate.removeDroppedFrames(totalFrames);
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
    var millis = _millis + other.millis;
    var seconds = millis / 1000;
    return Timecode.atSeconds(seconds, framerate: framerate);
  }

  Timecode operator -(Timecode other) {
    var millis = _millis - other.millis;
    var seconds = millis / 1000;
    return Timecode.atSeconds(seconds, framerate: framerate);
  }

  Timecode operator *(int multiplier) {
    var millis = _millis * multiplier;
    var seconds = millis / 1000;
    return Timecode.atSeconds(seconds, framerate: framerate);
  }

  Timecode operator /(int divisor) {
    var millis = _millis / divisor;
    var seconds = millis / 1000;
    return Timecode.atSeconds(seconds, framerate: framerate);
  }

  @override
  int get hashCode => _frames.hashCode;

  void _recomputeValues() {
    var seconds = framerate.framesToSeconds(_frames);
    var ws = seconds.wholeSeconds;

    _ss = ws % 60;
    _mm = (ws ~/ 60) % 60;
    _hh = (ws ~/ 60) ~/ 60;
    _ff = seconds.fractionAsFrames;
    _frac = (1000 * (seconds.seconds - ws)).floor();
    _millis = (seconds.seconds * 1000).round();
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

  // when moving to frames, always add one frame;
  int secondsToFrames(double seconds) {
    if (!isDropFrame) return (seconds * fps).floor();
    var framesBeforeDrop = (seconds * integerFps).floor();
    return removeDroppedFrames(framesBeforeDrop);
  }

  // when moving to seconds, always remove one frame
  TimecodeSecondsWithFrames framesToSeconds(int frames) {
    // Number of frames in a day - timecode rolls over after 24 hours
    var framesPer24Hours = (fps * 60 * 60 * 24).round();
    frames %= framesPer24Hours;
    frames = restoreDroppedFrames(frames);
    var remainderFrames = frames % integerFps;
    var seconds = frames / integerFps;

    return TimecodeSecondsWithFrames(seconds, remainderFrames);
  }

  int restoreDroppedFrames(int framesAfterDrop) {
    var frames = framesAfterDrop;
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

  int removeDroppedFrames(int framesBeforeDrop) {
    var frames = framesBeforeDrop;
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

class TimecodeException implements Exception {
  String message;
  TimecodeException(this.message);
  @override
  String toString() {
    return "TimecodeException: $message";
  }
}
