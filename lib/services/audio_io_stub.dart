/// Web stub — offline audio is stored in IndexedDB instead of the filesystem.
class MobileIo {
  Future<String> audioDirectory() async {
    throw UnsupportedError('Filesystem not available on web');
  }

  Future<bool> fileExists(String path) async => false;

  Future<void> writeFile(String path, List<int> bytes) async {
    throw UnsupportedError('Filesystem not available on web');
  }
}
