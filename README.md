This package implements the Timecode SMPTE spec.

## Features

A `Timecode` object has a framerate and a number of frames. Various mathematical operations
can be done on the object, and it will be able to understand how to convert its frame number
to a human readable SMPTE string like `01:23:45:01` where the form is `HH:MM:SS:FF` (hours,
minutes, seconds, frames).

`Timecode` objects can also be configured to use milliseconds instead of frames or to output
SMPTE code with fractional seconds instead of frame numbers. In either case, the output will
look like this `01:23:45.123` where the last three digits are milliseconds.

## Usage

Add to your `pubspec.yaml`.

```bash
$ dart pub add timecode
```

Import in your file and create a `Timecode` object.

```dart
import 'package:timecode/timecode.dart';

var timecode = Timecode(framerate: TimecodeFramerate(24));
print(timecode);
for (var i = 0; i < 100; i++) {
	timecode.next();
	print(timecode);
}
```

## Additional information

The class is well-documented, so you should be able to understand it easily by looking at the API documentation
or by reading the source code directly.
