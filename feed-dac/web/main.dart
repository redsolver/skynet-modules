// !!! This file is automatically generated !!!

import 'dart:convert';
import 'dart:html';
import 'package:dac_modules_base/base.dart';
import 'package:skynet/skynet.dart';
import 'package:skynet/src/mysky_provider/kernel.dart';
import 'package:skynet/src/kernel/module.dart';
import 'package:skynet_dacs_library/dacs.dart';

import 'package:feed_dac_module/implementation.dart';

import 'package:dart_json_mapper/dart_json_mapper.dart' show JsonMapper;
import 'main.mapper.g.dart';

// TODO There's also sharedworkerglobalscope

void sendMessage(dynamic data) {
  DedicatedWorkerGlobalScope.instance.postMessage(data);
}

void respond(String nonce, dynamic data) {
  sendMessage({
    'nonce': nonce,
    'method': "response",
    'data': data,
    'err': null,
    'isWorker': true,
  });
}

void respondErr(String nonce, String err) {
  sendMessage({
    'nonce': nonce,
    'method': "response",
    'err': err,
    'data': null,
    'isWorker': true,
  });
}

void log(dynamic s) {
  print('[FeedDAC] $s');
}

bool isReady = false;

void main() {
  log('init');
  initializeJsonMapper();
  final skynetClient =
      SkynetClient(); // TODO Automatically use kernel-native methods in Skynet client when in worker scope

  final mySkyProvider = KernelMySkyProvider(skynetClient);

  final _impl = FeedDACModuleImplementation(
    mySkyProvider,
    bridgeDAC: BridgeDAC(),
    queryDAC: QueryDAC(),
    socialDAC: SocialDAC(),
  );

  DedicatedWorkerGlobalScope.instance.addEventListener('message',
      (event) async {
    final e = event as MessageEvent;

    final method = e.data['method'];
    if (method == 'presentSeed') {
      return;
    } else if (e.data['method'] == 'response') {
      return;
    }

    while (!isReady) {
      await Future.delayed(Duration(milliseconds: 10));
      isReady = await _impl.isReady();
    }

    final String nonce = e.data['nonce'];
    final String domain = e.data['domain'];

    try {
      final dynamic data = e.data['data'];

      log('> $method $data (domain: $domain)');

      if (false) {
      } else if (method == 'loadPost') {
        final res = await _impl.loadPost(
          data['ref'] as String,
        );
        respond(nonce, _convertToJson(res));
      } else if (method == 'loadPostsForUser') {
        final res = await _impl.loadPostsForUser(
          data['userId'] as String,
          feedId: data['feedId'] as String? ?? 'posts',
          beforeTimestamp: data['beforeTimestamp'] as int?,
        );
        respond(nonce, _convertToJson(res));
      } else if (method == 'createPost') {
        final res = await _impl.createPost(
          JsonMapper.fromMap<PostContent>(
              data['content'].cast<String, dynamic>())!,
          context: CallContext(domain),
        );
        respond(nonce, _convertToJson(res));
      } else if (method == 'createComment') {
        final res = await _impl.createComment(
          JsonMapper.fromMap<PostContent>(
              data['content'].cast<String, dynamic>())!,
          data['commentTo'] as String,
          JsonMapper.fromMap<Post>(data['parent'].cast<String, dynamic>())!,
          context: CallContext(domain),
        );
        respond(nonce, _convertToJson(res));
      } else if (method == 'createRepost') {
        final res = await _impl.createRepost(
          data['repostOf'] as String,
          JsonMapper.fromMap<Post>(data['parent'].cast<String, dynamic>())!,
          context: CallContext(domain),
        );
        respond(nonce, _convertToJson(res));
      } else if (method == 'deletePost') {
        await _impl.deletePost(
          data['ref'] as String,
          context: CallContext(domain),
        );
        respond(nonce, {});
      } else if (method == 'isMySkyReady') {
        final res = await _impl.isMySkyReady();
        respond(nonce, _convertToJson(res));
      } else if (method == 'isReady') {
        final res = await _impl.isReady();
        respond(nonce, _convertToJson(res));
      }
    } catch (e) {
      respondErr(nonce, e.toString());
    }
  });
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