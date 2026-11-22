import 'dart:io';

const _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';

/// autostart via the Run key. [hidden]: pencere açılmaz, sistem tepsisinde başlar
Future<void> setStartWithWindows(bool on, {bool hidden = true}) async {
  if (!Platform.isWindows) return;
  if (on) {
    final command = '"${Platform.resolvedExecutable}"${hidden ? ' --hidden' : ''}';
    await Process.run('reg', ['add', _runKey, '/v', 'NoLook', '/t', 'REG_SZ', '/d', command, '/f']);
  } else {
    await Process.run('reg', ['delete', _runKey, '/v', 'NoLook', '/f']);
  }
}
