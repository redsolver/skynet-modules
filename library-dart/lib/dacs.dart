import 'dart:async';
import 'dart:html';

import 'package:dart_json_mapper/dart_json_mapper.dart' show JsonMapper;
import 'dacs.mapper.g.dart';

import 'package:dac_modules_base/base.dart';

main() {}

class _InitManager {
  static bool isDone = false;
}

class ProfileDAC extends ProfileDACModule {
  final _moduleSkylink = 'AQAXZpiIGQFT3lKGVwb8TAX3WymVsrM_LZ-A9cZzYNHWCw';

  final Map<String, Completer<dynamic>> reqs = {};

  final dws = DedicatedWorkerGlobalScope.instance;

  ProfileDAC() : super() {
    if (!_InitManager.isDone) {
      _InitManager.isDone = true;
      initializeJsonMapper();
    }
    dws.addEventListener('message', (event) {
      final e = event as MessageEvent;
      if (e.data['method'] == 'response') {
        final String nonce = e.data['nonce'];
        if (reqs.containsKey(nonce)) {
          reqs[nonce]!.complete(e.data);
        }
      }
    });
  }
  int _requestIdCounter = 1; // nonce

  Future<dynamic> _call(
    String methodName, [
    dynamic data = const <String, dynamic>{},
  ]) async {
    _requestIdCounter++;
    final nonce = 'ProfileDAC-$_requestIdCounter';

    final completer = Completer();
    reqs[nonce] = completer;

    final message = {
      'method': 'moduleCall',
      'nonce': nonce,
      'data': {
        'module': _moduleSkylink,
        'method': methodName,
        'data': data,
      },
    };
    dws.postMessage(
      message,
    );

    final res = await completer.future;
    if (res['err'] != null) {
      throw '${res['err']}';
    }
    return res['data'];
  }

  @override
  Future<Profile?> getProfile({String? userId}) async {
    return (await _call(
                'getProfile',
                _convertToJson({
                  'userId': userId,
                }))) ==
            null
        ? null
        : JsonMapper.fromMap<Profile>((await _call(
                'getProfile',
                _convertToJson({
                  'userId': userId,
                })))
            .cast<String, dynamic>());
  }

  @override
  Future<void> setProfile(Profile profile) async {
    await _call(
        'setProfile',
        _convertToJson({
          'profile': profile,
        }));
  }

  @override
  Future<List<Profile>> searchUsers(String query) async {
    return ((await _call(
            'searchUsers',
            _convertToJson({
              'query': query,
            }))) as List)
        .map<Profile>(
            (m) => JsonMapper.fromMap<Profile>(m.cast<String, dynamic>())!)
        .toList();
  }

  @override
  Future<bool> isMySkyReady() async {
    return (await _call('isMySkyReady', _convertToJson({}))) as bool;
  }

  @override
  Future<bool> isReady() async {
    return (await _call('isReady', _convertToJson({}))) as bool;
  }
}

class QueryDAC extends QueryDACModule {
  final _moduleSkylink = 'AQAPFg2Wdtld0HoVP0sIAQjQlVnXC-KY34WWDxXBLtzfbw';

  final Map<String, Completer<dynamic>> reqs = {};

  final dws = DedicatedWorkerGlobalScope.instance;

  QueryDAC() : super() {
    if (!_InitManager.isDone) {
      _InitManager.isDone = true;
      initializeJsonMapper();
    }
    dws.addEventListener('message', (event) {
      final e = event as MessageEvent;
      if (e.data['method'] == 'response') {
        final String nonce = e.data['nonce'];
        if (reqs.containsKey(nonce)) {
          reqs[nonce]!.complete(e.data);
        }
      }
    });
  }
  int _requestIdCounter = 1; // nonce

  Future<dynamic> _call(
    String methodName, [
    dynamic data = const <String, dynamic>{},
  ]) async {
    _requestIdCounter++;
    final nonce = 'QueryDAC-$_requestIdCounter';

    final completer = Completer();
    reqs[nonce] = completer;

    final message = {
      'method': 'moduleCall',
      'nonce': nonce,
      'data': {
        'module': _moduleSkylink,
        'method': methodName,
        'data': data,
      },
    };
    dws.postMessage(
      message,
    );

    final res = await completer.future;
    if (res['err'] != null) {
      throw '${res['err']}';
    }
    return res['data'];
  }

  @override
  Future<Map<String, dynamic>?> getUserStats(String userId) async {
    return ((await _call(
            'getUserStats',
            _convertToJson({
              'userId': userId,
            }))) as Map?)
        ?.cast<String, dynamic>();
  }

  @override
  Future<bool> getUserExists(String userId) async {
    return (await _call(
        'getUserExists',
        _convertToJson({
          'userId': userId,
        }))) as bool;
  }

  @override
  Future<List<String>?> getUserFollowers(String userId) async {
    return ((await _call(
            'getUserFollowers',
            _convertToJson({
              'userId': userId,
            }))) as List?)
        ?.cast<String>();
  }

  @override
  Future<Map<String, dynamic>?> getPostStats(String ref) async {
    return ((await _call(
            'getPostStats',
            _convertToJson({
              'ref': ref,
            }))) as Map?)
        ?.cast<String, dynamic>();
  }

  @override
  Future<List<String>?> getPostComments(String ref) async {
    return ((await _call(
            'getPostComments',
            _convertToJson({
              'ref': ref,
            }))) as List?)
        ?.cast<String>();
  }

  @override
  Future<List<String>> searchUsers(String query) async {
    return ((await _call(
            'searchUsers',
            _convertToJson({
              'query': query,
            }))) as List)
        .cast<String>();
  }

  @override
  Future<void> enable() async {
    await _call('enable', _convertToJson({}));
  }

  @override
  Future<bool> isMySkyReady() async {
    return (await _call('isMySkyReady', _convertToJson({}))) as bool;
  }

  @override
  Future<bool> isReady() async {
    return (await _call('isReady', _convertToJson({}))) as bool;
  }
}

class SocialDAC extends SocialDACModule {
  final _moduleSkylink = 'AQDETEWOzNYZu5YeOIPhvwpqIn3aL6ghf-ccLpbj3O1EIw';

  final Map<String, Completer<dynamic>> reqs = {};

  final dws = DedicatedWorkerGlobalScope.instance;

  SocialDAC() : super() {
    if (!_InitManager.isDone) {
      _InitManager.isDone = true;
      initializeJsonMapper();
    }
    dws.addEventListener('message', (event) {
      final e = event as MessageEvent;
      if (e.data['method'] == 'response') {
        final String nonce = e.data['nonce'];
        if (reqs.containsKey(nonce)) {
          reqs[nonce]!.complete(e.data);
        }
      }
    });
  }
  int _requestIdCounter = 1; // nonce

  Future<dynamic> _call(
    String methodName, [
    dynamic data = const <String, dynamic>{},
  ]) async {
    _requestIdCounter++;
    final nonce = 'SocialDAC-$_requestIdCounter';

    final completer = Completer();
    reqs[nonce] = completer;

    final message = {
      'method': 'moduleCall',
      'nonce': nonce,
      'data': {
        'module': _moduleSkylink,
        'method': methodName,
        'data': data,
      },
    };
    dws.postMessage(
      message,
    );

    final res = await completer.future;
    if (res['err'] != null) {
      throw '${res['err']}';
    }
    return res['data'];
  }

  @override
  Future<void> follow(String userId, {Map<String, dynamic>? ext}) async {
    await _call(
        'follow',
        _convertToJson({
          'userId': userId,
          'ext': ext,
        }));
  }

  @override
  Future<void> unfollow(String userId) async {
    await _call(
        'unfollow',
        _convertToJson({
          'userId': userId,
        }));
  }

  @override
  Future<bool> isFollowing(String userId) async {
    return (await _call(
        'isFollowing',
        _convertToJson({
          'userId': userId,
        }))) as bool;
  }

  @override
  Future<List<String>> getFollowingForUser(String userId) async {
    return ((await _call(
            'getFollowingForUser',
            _convertToJson({
              'userId': userId,
            }))) as List)
        .cast<String>();
  }

  @override
  Future<Map<String, Map<dynamic, dynamic>>> getFollowingMapForUser(
      String userId) async {
    return ((await _call(
            'getFollowingMapForUser',
            _convertToJson({
              'userId': userId,
            }))) as Map)
        .cast<String, Map>();
  }

  @override
  Future<int> getFollowingCountForUser(String userId) async {
    return (await _call(
        'getFollowingCountForUser',
        _convertToJson({
          'userId': userId,
        }))) as int;
  }

  @override
  Future<List<String>> getSuggestedUsers() async {
    return ((await _call('getSuggestedUsers', _convertToJson({}))) as List)
        .cast<String>();
  }

  @override
  Stream<void> onFollowingChange() {
    return Stream<void>.empty();
  }

  @override
  Future<bool> isMySkyReady() async {
    return (await _call('isMySkyReady', _convertToJson({}))) as bool;
  }

  @override
  Future<bool> isReady() async {
    return (await _call('isReady', _convertToJson({}))) as bool;
  }
}

class FeedDAC extends FeedDACModule {
  final _moduleSkylink = 'AQCSRGL0vey8Nccy_Pqk3fYTMm0y2nE_dK0I8ro8bZyZ3Q';

  final Map<String, Completer<dynamic>> reqs = {};

  final dws = DedicatedWorkerGlobalScope.instance;

  FeedDAC() : super() {
    if (!_InitManager.isDone) {
      _InitManager.isDone = true;
      initializeJsonMapper();
    }
    dws.addEventListener('message', (event) {
      final e = event as MessageEvent;
      if (e.data['method'] == 'response') {
        final String nonce = e.data['nonce'];
        if (reqs.containsKey(nonce)) {
          reqs[nonce]!.complete(e.data);
        }
      }
    });
  }
  int _requestIdCounter = 1; // nonce

  Future<dynamic> _call(
    String methodName, [
    dynamic data = const <String, dynamic>{},
  ]) async {
    _requestIdCounter++;
    final nonce = 'FeedDAC-$_requestIdCounter';

    final completer = Completer();
    reqs[nonce] = completer;

    final message = {
      'method': 'moduleCall',
      'nonce': nonce,
      'data': {
        'module': _moduleSkylink,
        'method': methodName,
        'data': data,
      },
    };
    dws.postMessage(
      message,
    );

    final res = await completer.future;
    if (res['err'] != null) {
      throw '${res['err']}';
    }
    return res['data'];
  }

  @override
  Future<Post> loadPost(String ref) async {
    return JsonMapper.fromMap<Post>((await _call(
            'loadPost',
            _convertToJson({
              'ref': ref,
            })))
        .cast<String, dynamic>())!;
  }

  @override
  Future<List<Post>> loadPostsForUser(String userId,
      {String feedId = 'posts', int? beforeTimestamp}) async {
    return ((await _call(
            'loadPostsForUser',
            _convertToJson({
              'userId': userId,
              'feedId': feedId,
              'beforeTimestamp': beforeTimestamp,
            }))) as List)
        .map<Post>((m) => JsonMapper.fromMap<Post>(m.cast<String, dynamic>())!)
        .toList();
  }

  @override
  Stream<CommentsPage> loadCommentsForPost(String ref) {
    return Stream<CommentsPage>.empty();
  }

  @override
  Stream<int> getCommentsCount(String ref) {
    return Stream<int>.empty();
  }

  @override
  Stream<Post> listenForPosts(String userId, {String feedId = 'posts'}) {
    return Stream<Post>.empty();
  }

  @override
  Future<String> createPost(PostContent content,
      {String feedId = 'posts'}) async {
    return (await _call(
        'createPost',
        _convertToJson({
          'content': content,
          'feedId': feedId,
        }))) as String;
  }

  @override
  Future<String> createComment(
      PostContent content, String commentTo, Post parent) async {
    return (await _call(
        'createComment',
        _convertToJson({
          'content': content,
          'commentTo': commentTo,
          'parent': parent,
        }))) as String;
  }

  @override
  Future<String> createRepost(String repostOf, Post parent) async {
    return (await _call(
        'createRepost',
        _convertToJson({
          'repostOf': repostOf,
          'parent': parent,
        }))) as String;
  }

  @override
  Future<void> deletePost(String ref) async {
    await _call(
        'deletePost',
        _convertToJson({
          'ref': ref,
        }));
  }

  @override
  Future<bool> isMySkyReady() async {
    return (await _call('isMySkyReady', _convertToJson({}))) as bool;
  }

  @override
  Future<bool> isReady() async {
    return (await _call('isReady', _convertToJson({}))) as bool;
  }
}

class BridgeDAC extends BridgeDACModule {
  final _moduleSkylink = 'AQAKn33Pm9WPcm872JuxnRhowH5UA3Mm_hCb6CMT79nQdw';

  final Map<String, Completer<dynamic>> reqs = {};

  final dws = DedicatedWorkerGlobalScope.instance;

  BridgeDAC() : super() {
    if (!_InitManager.isDone) {
      _InitManager.isDone = true;
      initializeJsonMapper();
    }
    dws.addEventListener('message', (event) {
      final e = event as MessageEvent;
      if (e.data['method'] == 'response') {
        final String nonce = e.data['nonce'];
        if (reqs.containsKey(nonce)) {
          reqs[nonce]!.complete(e.data);
        }
      }
    });
  }
  int _requestIdCounter = 1; // nonce

  Future<dynamic> _call(
    String methodName, [
    dynamic data = const <String, dynamic>{},
  ]) async {
    _requestIdCounter++;
    final nonce = 'BridgeDAC-$_requestIdCounter';

    final completer = Completer();
    reqs[nonce] = completer;

    final message = {
      'method': 'moduleCall',
      'nonce': nonce,
      'data': {
        'module': _moduleSkylink,
        'method': methodName,
        'data': data,
      },
    };
    dws.postMessage(
      message,
    );

    final res = await completer.future;
    if (res['err'] != null) {
      throw '${res['err']}';
    }
    return res['data'];
  }

  @override
  Future<Profile?> getProfile(String userId) async {
    return (await _call(
                'getProfile',
                _convertToJson({
                  'userId': userId,
                }))) ==
            null
        ? null
        : JsonMapper.fromMap<Profile>((await _call(
                'getProfile',
                _convertToJson({
                  'userId': userId,
                })))
            .cast<String, dynamic>());
  }

  @override
  Future<Post> loadPost(String ref) async {
    return JsonMapper.fromMap<Post>((await _call(
            'loadPost',
            _convertToJson({
              'ref': ref,
            })))
        .cast<String, dynamic>())!;
  }

  @override
  Future<List<Post>> loadPostsForUser(String userId,
      {String feedId = 'posts', int? beforeTimestamp}) async {
    return ((await _call(
            'loadPostsForUser',
            _convertToJson({
              'userId': userId,
              'feedId': feedId,
              'beforeTimestamp': beforeTimestamp,
            }))) as List)
        .map<Post>((m) => JsonMapper.fromMap<Post>(m.cast<String, dynamic>())!)
        .toList();
  }

  @override
  Future<List<Post>> loadCommentsForPost(String ref) async {
    return ((await _call(
            'loadCommentsForPost',
            _convertToJson({
              'ref': ref,
            }))) as List)
        .map<Post>((m) => JsonMapper.fromMap<Post>(m.cast<String, dynamic>())!)
        .toList();
  }

  @override
  Future<List<Profile>> searchUsers(String query) async {
    return ((await _call(
            'searchUsers',
            _convertToJson({
              'query': query,
            }))) as List)
        .map<Profile>(
            (m) => JsonMapper.fromMap<Profile>(m.cast<String, dynamic>())!)
        .toList();
  }

  @override
  Future<bool> isMySkyReady() async {
    return (await _call('isMySkyReady', _convertToJson({}))) as bool;
  }

  @override
  Future<bool> isReady() async {
    return (await _call('isReady', _convertToJson({}))) as bool;
  }
}

dynamic _convertToJson(dynamic o) {
  if (o is List) {
    return o.map((e) => _convertToJson(e)).toList();
  } else if (o is Map) {
    return o.map((k, v) => MapEntry(k, _convertToJson(v)));
  } else if (o is bool) {
    return o;
  } else if (o is String) {
    return o;
  } else if (o is int) {
    return o;
  } else if (o is double) {
    return o;
  } else if (o == null) {
    return o;
  } else {
    if (o is Post) {
      final ext = o.content?.ext;
      o.content?.ext = null;
      final m = JsonMapper.toMap(o);
      if (ext != null) {
        m!['content'] ??= {};
        m['content']['ext'] = ext;
      }
      return m;
    } else {
      return JsonMapper.toMap(o);
    }
  }
}
