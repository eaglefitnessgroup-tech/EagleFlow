import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<Map<String, List<int>>?> pickFolderFilesImpl() async {
  final completer = Completer<Map<String, List<int>>?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..multiple = true;
  input.setAttribute('webkitdirectory', 'true');
  input.setAttribute('directory', 'true');

  input.onChange.listen((web.Event e) {
    final files = input.files;
    if (files == null || files.length == 0) {
      completer.complete(null);
      return;
    }

    final result = <String, List<int>>{};
    int processed = 0;

    for (int i = 0; i < files.length; i++) {
      final file = files.item(i)!;
      final reader = web.FileReader();

      web.EventStreamProviders.loadEvent.forTarget(reader).listen((web.Event _) {
        try {
          final buffer = reader.result as JSArrayBuffer;
          result[file.name] = buffer.toDart.asUint8List();
        } catch (_) {}
        processed++;
        if (processed == files.length) {
          completer.complete(result);
        }
      });

      web.EventStreamProviders.errorEvent.forTarget(reader).listen((web.Event _) {
        processed++;
        if (processed == files.length) {
          completer.complete(result);
        }
      });

      reader.readAsArrayBuffer(file);
    }
  });

  input.click();
  return completer.future;
}
