import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Reads Windows file attributes via the Win32 `GetFileAttributesW` syscall so
/// the hidden-files toggle can detect files flagged Hidden or System even when
/// their name does not start with a dot (e.g. `desktop.ini`, `$RECYCLE.BIN`).
///
/// All methods are safe to call on any platform; non-Windows always returns
/// `false` and the dynamic library is never opened off Windows.
class WinAttributes {
  WinAttributes._();

  static const int _invalidFileAttributes = 0xFFFFFFFF;
  static const int _fileAttributeHidden = 0x2;
  static const int _fileAttributeSystem = 0x4;

  // Lazily resolved; only touched after a Platform.isWindows guard, so the
  // library is never opened on macOS/Linux.
  static final int Function(Pointer<Utf16>) _getFileAttributesW = DynamicLibrary
          .open('kernel32.dll')
      .lookupFunction<Uint32 Function(Pointer<Utf16>),
          int Function(Pointer<Utf16>)>('GetFileAttributesW');

  /// Whether [path] has the Hidden or System attribute set. Returns `false`
  /// on non-Windows platforms or if the lookup fails.
  static bool isHidden(String path) {
    if (!Platform.isWindows) return false;
    final ptr = path.toNativeUtf16();
    try {
      final attrs = _getFileAttributesW(ptr);
      if (attrs == _invalidFileAttributes) return false;
      return (attrs & (_fileAttributeHidden | _fileAttributeSystem)) != 0;
    } catch (_) {
      return false;
    } finally {
      malloc.free(ptr);
    }
  }
}
