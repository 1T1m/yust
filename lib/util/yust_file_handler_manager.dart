import 'dart:async';

import 'package:collection/collection.dart';
import 'package:yust/models/yust_file.dart';
import 'package:yust/util/yust_file_handler.dart';

class YustFileHandlerManager {
  List<YustFileHandler> filehandlers = [];

  YustFileHandler createFileHandler({
    required String storageFolderPath,
    String? linkedDocAttribute,
    String? linkedDocPath,
    void Function()? onFileUploaded,
  }) {
    var newFileHandler = getFileHandler(linkedDocAttribute, linkedDocPath);

    if (newFileHandler == null) {
      newFileHandler = YustFileHandler(
        storageFolderPath: storageFolderPath,
        linkedDocAttribute: linkedDocAttribute,
        linkedDocPath: linkedDocPath,
        onFileUploaded: onFileUploaded,
      );
      if (linkedDocAttribute != null && linkedDocPath != null) {
        filehandlers.add(newFileHandler);
      }
    }
    return newFileHandler;
  }

  YustFileHandler? getFileHandler(
      String? linkedDocAttribute, String? linkedDocPath) {
    var newFileHandler = filehandlers.firstWhereOrNull(
      (filehandler) =>
          filehandler.linkedDocAttribute == linkedDocAttribute &&
          filehandler.linkedDocPath == linkedDocPath,
    );
    return newFileHandler;
  }

  /// Uploads all cached files. If the upload fails,  a new attempt is made after [_reuploadTime].
  /// Should be started only ONCE, renewed call only possible after successful upload.
  Future<void> uploadCachedFiles() async {
    var cachedFiles = await YustFileHandler.loadCachedFiles();
    while (cachedFiles.isNotEmpty) {
      print(cachedFiles.length.toString() + ' files in upload queue');
      var file = cachedFiles.first;
      var filehandler = createFileHandler(
        storageFolderPath: file.storageFolderPath ?? '',
        linkedDocAttribute: file.linkedDocAttribute,
        linkedDocPath: file.linkedDocPath,
      );

      cachedFiles.removeWhere((YustFile f) =>
          f.linkedDocAttribute == file.linkedDocAttribute &&
          f.linkedDocPath == file.linkedDocPath);
      await filehandler.updateFiles([]);
      filehandler.startUploadingCachedFiles();
    }
  }
}
