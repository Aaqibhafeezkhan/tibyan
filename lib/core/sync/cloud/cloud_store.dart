/// Why a cloud store cannot be used right now.
enum CloudUnavailable {
  /// This build was made without what the store needs (the iCloud
  /// capability, or the Google sign-in client id).
  notInThisBuild,

  /// The device is not signed in to the account the store needs (iCloud
  /// off, or no Google account chosen).
  noAccount,

  /// The platform has no store (Windows, Linux, web).
  unsupported,
}

/// Where a device's sync file lives: the reader's own iCloud or Google
/// Drive app folder. Tibyan has no server in between and no account of its
/// own. Each device writes only its own file ([write]) and reads every
/// device's ([readAll]), so two devices never overwrite each other.
abstract interface class CloudStore {
  /// `icloud` or `gdrive`.
  String get kind;

  /// Null when the store can be used, else why not. Never asks the reader
  /// anything.
  Future<CloudUnavailable?> unavailable();

  /// Asks the reader to sign in when the store needs it (Google). Returns
  /// whether it can be used now. Only from a tap.
  Future<bool> connect();

  /// Every sync file in the store, by name.
  Future<Map<String, String>> readAll();

  Future<void> write(String name, String content);

  /// Deletes every sync file of every device.
  Future<void> deleteAll();

  /// Forgets the account (Google); nothing for iCloud.
  Future<void> disconnect();
}

/// A store in memory, for tests and as the store of an unsupported
/// platform's previews.
class MemoryCloudStore implements CloudStore {
  MemoryCloudStore({this.kind = 'memory', this.down});

  @override
  final String kind;

  /// Set to make the store unavailable.
  CloudUnavailable? down;
  final files = <String, String>{};
  int writes = 0;

  @override
  Future<CloudUnavailable?> unavailable() async => down;

  @override
  Future<bool> connect() async => down == null;

  @override
  Future<Map<String, String>> readAll() async {
    if (down != null) throw StateError('store unavailable');
    return Map.of(files);
  }

  @override
  Future<void> write(String name, String content) async {
    if (down != null) throw StateError('store unavailable');
    writes++;
    files[name] = content;
  }

  @override
  Future<void> deleteAll() async => files.clear();

  @override
  Future<void> disconnect() async {}
}
