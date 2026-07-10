String getFileExtension(String path) {
  final dot = path.lastIndexOf('.');
  if (dot <= 0 || dot == path.length - 1) return 'bin';
  return path.substring(dot + 1).toLowerCase();
}

bool isPdfAttachment(String path) {
  return getFileExtension(path) == 'pdf';
}

bool isImageAttachment(String path) {
  final ext = getFileExtension(path);
  return ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'webp';
}
