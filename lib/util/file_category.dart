enum FileCategory { image, video, audio, text, pdf, other }

FileCategory categoryFor(String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  if (['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'heic'].contains(ext)) {
    return FileCategory.image;
  }
  if (['mp4', 'mov', 'webm', 'mkv', 'm4v', 'avi'].contains(ext)) {
    return FileCategory.video;
  }
  if (['mp3', 'wav', 'm4a', 'ogg', 'flac', 'aac', 'opus'].contains(ext)) {
    return FileCategory.audio;
  }
  if ([
    'txt', 'md', 'markdown', 'json', 'yaml', 'yml', 'xml', 'csv', 'log',
    'dart', 'js', 'ts', 'jsx', 'tsx', 'py', 'rs', 'go', 'c', 'cpp', 'h',
    'hpp', 'java', 'kt', 'swift', 'rb', 'php', 'sh', 'bash', 'zsh',
    'html', 'htm', 'css', 'scss', 'sql', 'toml', 'ini', 'cfg', 'conf',
    'gitignore', 'env', 'lock',
  ].contains(ext)) {
    return FileCategory.text;
  }
  if (ext == 'pdf') return FileCategory.pdf;
  return FileCategory.other;
}

const int kMaxTextPreviewBytes = 200 * 1024;