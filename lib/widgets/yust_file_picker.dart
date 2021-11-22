import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yust/models/yust_file.dart';
import 'package:yust/util/yust_exception.dart';
import 'package:yust/util/yust_offline_cache.dart';
import 'package:yust/widgets/yust_input_tile.dart';
import 'package:dio/dio.dart';
import '../yust.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

class YustFilePicker extends StatefulWidget {
  final String? label;
  final String folderPath;

  /// [pathToDoc] and [docAttribute] are needed for the offline compatibility.
  /// If not given, uploads are only possible with internet connection
  final String? pathToDoc;

  /// [pathToDoc] and [docAttribute] are needed for the offline compatibility.
  /// If not given, uploads are only possible with internet connection
  final String? docAttribute;
  final List<Map<String, String?>> files;
  final void Function(List<Map<String, String?>> files)? onChanged;
  final Widget? prefixIcon;
  final bool readOnly;

  YustFilePicker({
    Key? key,
    this.label,
    required this.folderPath,
    this.pathToDoc,
    this.docAttribute,
    required this.files,
    this.onChanged,
    this.prefixIcon,
    this.readOnly = false,
  }) : super(key: key);

  @override
  YustFilePickerState createState() => YustFilePickerState();
}

class YustFilePickerState extends State<YustFilePicker> {
  late List<YustFile> _files;
  late bool _enabled;

  @override
  void initState() {
    _files =
        widget.files.map<YustFile>((file) => YustFile.fromJson(file)).toList();

    _enabled = (widget.onChanged != null && !widget.readOnly);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: YustOfflineCache.loadFiles(
            uploadedFiles: widget.files
                .map<YustFile>((file) => YustFile.fromJson(file))
                .toList(),
            files: _files),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return SizedBox.shrink();
          }
          return YustInputTile(
              child: _buildAddButton(context),
              label: widget.label,
              prefixIcon: widget.prefixIcon,
              suffixChild: _buildFiles(context));
        });
  }

  _buildAddButton(BuildContext context) {
    if (!_enabled) {
      return SizedBox.shrink();
    }
    return IconButton(
      icon: Icon(Icons.add, color: Theme.of(context).colorScheme.secondary),
      onPressed: _enabled ? _pickFiles : null,
    );
  }

  Widget _buildFiles(BuildContext context) {
    return Column(
      children: _files.map((file) => _buildFile(context, file)).toList(),
    );
  }

  Widget _buildFile(BuildContext context, YustFile file) {
    return ListTile(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file),
          SizedBox(width: 8),
          Expanded(
            child: Text(
                YustOfflineCache.isLocalFile(file.name)
                    ? file.name.substring(
                        5) // each local file has the name tag 'local'. It gets hided for the ui.
                    : file.name,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      trailing: _buildDeleteButton(file),
      onTap: () => _showFile(file),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
    );
  }

  Widget _buildDeleteButton(YustFile file) {
    if (!_enabled) {
      return SizedBox.shrink();
    }
    if (file.processing == true) {
      return CircularProgressIndicator();
    }
    return IconButton(
      icon: Icon(Icons.delete),
      onPressed: _enabled ? () => _deleteFile(file) : null,
    );
  }

  Future<void> addFile(YustFile newFile) async {
    setState(() {
      _files.add(newFile);
      _files.sort((a, b) => (a.name).compareTo(b.name));
      newFile.processing = true;
    });

    //if there are bytes in the file, it is a WEB operation > offline compatibility is not implemented
    if (_isOfflineUploadPossible() && newFile.bytes == null) {
      // Add 'local' as a name suffix to distinguish the files between uploaded and local
      newFile.name = 'local' + newFile.name;
      if (newFile.file != null) {
        newFile.url = await YustOfflineCache.saveFileTemporary(
          file: newFile,
          docAttribute: widget.docAttribute!,
          folderPath: widget.folderPath,
          pathToDoc: widget.pathToDoc!,
        );
      }
    } else {
      try {
        newFile.url = await Yust.service.uploadFile(
          path: widget.folderPath,
          name: newFile.name,
          file: newFile.file,
          bytes: newFile.bytes,
        );
      } on YustException catch (e) {
        if (mounted) {
          Yust.service.showAlert(context, 'Ups', e.message);
        }
      } catch (e) {
        if (mounted) {
          Yust.service.showAlert(
              context, 'Ups', 'Die Datei konnte nicht hochgeladen werden.');
        }
      }
      if (newFile.url == null) {
        _files.remove(newFile);
      }
    }

    setState(() {
      newFile.processing = false;
    });

    if (mounted) {
      setState(() {});
    }
    _onChanged();
    YustOfflineCache.uploadLocalFiles(validateLocalFiles: false);
  }

  Future<void> _pickFiles() async {
    Yust.service.unfocusCurrent(context);
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none &&
        !_isOfflineUploadPossible()) {
      Yust.service.showAlert(context, 'Kein Internet',
          'Für das Hinzufügen einer Datei ist eine Internetverbindung erforderlich.');
    } else {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result != null) {
        for (final platformFile in result.files) {
          var name = platformFile.name!.split('/').last;
          final ext = platformFile.extension;
          if (ext != null && name.split('.').last != ext) {
            name += '.' + ext;
          }

          final newFile = YustFile(
            name: name,
            processing: true,
          );

          if (_files.any((file) => file.name == newFile.name)) {
            Yust.service.showAlert(context, 'Nicht möglich',
                'Eine Datei mit dem Namen ${newFile.name} existiert bereits.');
          } else {
            File? file;
            if (platformFile.path != null) {
              file = File(platformFile.path!);
            }
            newFile.file = file;
            newFile.bytes = platformFile.bytes;
            await addFile(newFile);
          }

          _onChanged();
        }
      }
    }
  }

  Future<void> _showFile(YustFile file) async {
    Yust.service.unfocusCurrent(context);
    final connectivityResult = await Connectivity().checkConnectivity();
    if (file.file == null && YustOfflineCache.isLocalFile(file.name)) {
      Yust.service.showAlert(context, 'Nicht vorhanden',
          'Die ausgewählte Date wird soeben von einem anderem Gerät hochgeladen. Versuche es später nocheinmal.');
    } else if (connectivityResult == ConnectivityResult.none) {
      Yust.service.showAlert(context, 'Kein Internet',
          'Für das Anzeigen einer Datei ist eine Internetverbindung erforderlich.');
      // is it a valid file?
    } else if (file.processing == false) {
      // is the process running on mobile?
      if (!kIsWeb) {
        await EasyLoading.show(status: 'Datei laden...');
        try {
          final tempDir = await getTemporaryDirectory();
          await Dio().download(file.url!, '${tempDir.path}/${file.name}');
          var result = await OpenFile.open('${tempDir.path}/${file.name}');
          // if cant open file type, tries via browser
          if (result.type != ResultType.done) {
            _launchBrowser(file);
          }

          await EasyLoading.dismiss();
        } catch (e) {
          await EasyLoading.dismiss();
          await Yust.service.showAlert(context, 'Ups',
              'Die Datei kann nicht geöffnet werden. ${e.toString()}');
        }
      } else {
        await EasyLoading.show(status: 'Datei laden...');
        _launchBrowser(file);
        await EasyLoading.dismiss();
      }
    }
  }

  Future<void> _launchBrowser(YustFile file) async {
    if (await canLaunch(file.url!)) {
      await launch(file.url!);
    } else {
      await Yust.service
          .showAlert(context, 'Ups', 'Die Datei kann nicht geöffnet werden.');
    }
  }

  Future<void> _deleteFile(YustFile file) async {
    Yust.service.unfocusCurrent(context);
    final connectivityResult = await Connectivity().checkConnectivity();
    if (YustOfflineCache.isLocalFile(file.name)) {
      bool? confirmed = false;
      if (file.file == null) {
        confirmed = await Yust.service.showConfirmation(
            context,
            'Achtung! Diese Datei wird soeben von einem anderen Gerät hochgeladen! Willst du diese Datei wirklich löschen?',
            'Löschen');
      } else {
        confirmed = await Yust.service
            .showConfirmation(context, 'Wirklich löschen?', 'Löschen');
      }
      if (confirmed == true) {
        try {
          await YustOfflineCache.deleteLocalFile(file.name);
        } catch (e) {}
        setState(() {
          _files.remove(file);
        });
        _onChanged();
      }
    } else if (connectivityResult == ConnectivityResult.none) {
      // if the file is not local, and there is no connectivityResult, you can not delete the file
      Yust.service.showAlert(context, 'Kein Internet',
          'Für das Löschen einer Datei ist eine Internetverbindung erforderlich.');
    } else {
      final confirmed = await Yust.service
          .showConfirmation(context, 'Wirklich löschen?', 'Löschen');
      if (confirmed == true) {
        try {
          await firebase_storage.FirebaseStorage.instance
              .ref()
              .child(widget.folderPath)
              .child(file.name)
              .delete();
        } catch (e) {}

        setState(() {
          _files.remove(file);
        });
        _onChanged();
        // widget.onChanged!(_files);
      }
    }
  }

  /// removes file.urls that are paths to a folder
  void _onChanged() {
    List<YustFile> _onlineFiles = List.from(_files);
    for (var file in _onlineFiles) {
      if (YustOfflineCache.isLocalPath(file.url ?? '')) {
        file.url = null;
      }
    }
    widget.onChanged!(_onlineFiles.map((file) => file.toJson()).toList());
  }

  bool _isOfflineUploadPossible() {
    return widget.docAttribute != null && widget.pathToDoc != null;
  }
}
