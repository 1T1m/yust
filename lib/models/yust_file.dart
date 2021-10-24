import 'dart:io';
import 'dart:typed_data';

import 'package:yust/util/yust_serializable.dart';

class YustFile with YustSerializable {
  String name;
  String? url;
  File? file;
  Uint8List? bytes;
  bool processing;
  String folderPath;

  YustFile({
    required this.name,
    this.url,
    this.file,
    this.bytes,
    this.processing = false,
    folderPath,
  }) : folderPath = folderPath ?? 'false';

  factory YustFile.fromJson(Map<String, dynamic> json) {
    return YustFile(
      name: json['name'] as String,
      url: json['url'] as String,
      folderPath: json['folderPath'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'url': url,
      'folderPath': folderPath,
    };
  }
}
