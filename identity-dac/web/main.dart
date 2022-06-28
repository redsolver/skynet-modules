import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:html';

import 'package:convert/convert.dart';
import 'package:hive/hive.dart';
import 'package:skynet/skynet.dart';
import 'package:cryptography/cryptography.dart';
import 'package:web_socket_channel/html.dart';

import 'package:skynet/src/registry_classes.dart';
import 'package:skynet/src/mysky/tweak.dart';

// ! WARNING
// This code is very work-in-progress, a lot of the components (permission checks, external seed provider support) will be moved to other modules soon
// ! WARNING

final dws = DedicatedWorkerGlobalScope.instance;

void sendMessage(dynamic data) {
  dws.postMessage(data);
}

int nonceCounter = 0;

final Map<String, Completer<dynamic>> kernelRequests = {};

final Map<String, Completer<dynamic>> identityDACServerRequests = {};

void log(dynamic s) {
  print('[IdentityDAC] $s');
}

Future<dynamic> callModule(
  String module,
  String methodName, [
  dynamic data = const <String, dynamic>{},
]) async {
  nonceCounter++;
  final nonce = nonceCounter.toString();

  final completer = Completer();
  kernelRequests[nonce] = completer;

  DedicatedWorkerGlobalScope.instance.postMessage({
    'method': 'moduleCall',
    'data': {
      'module': module,
      'method': methodName,
      'data': data,
    },
    'nonce': nonce
  });

  final res = await completer.future;
  if (res['err'] != null) {
    throw '${res['err']}';
  }
  return res['data'];
}

Future<dynamic> callIdentityDAC(
  String domain,
  String methodName, [
  dynamic data = const <String, dynamic>{},
]) async {
  nonceCounter++;
  final nonce = nonceCounter.toString();

  final completer = Completer();
  identityDACServerRequests[nonce] = completer;

  channel.sink.add(
    json.encode({
      'domain': domain,
      'method': methodName,
      'data': data,
      'nonce': nonce,
    }),
  );

  final res = await completer.future;
  if (res['err'] != null) {
    throw '${res['err']}';
  }
  return res['data'];
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

late final SkynetUser skynetUser;
bool isLoggedIn = false;

bool identityDACServerActive = false;

late Box encryptedBox;

late HtmlWebSocketChannel channel;

void main() {
  dws.addEventListener('message', (event) async {
    final e = event as MessageEvent;
    // log('received ${event.data}');

    final method = e.data['method'];
    if (method == 'presentSeed') {
      try {
        /*     
        encryptedBox = await Hive.openBox(
          'secure-identity-dac.hns',
          encryptionCipher: HiveAesCipher(
            Blake2bHash.hashWithDigestSize(256, e.data['data']['seed']),
          ),
        ); */

        // if (!(encryptedBox.get('is_enabled') ?? false)) {

        final Uint8List privateKey =
            e.data['data']['myskyRootKeypair']['secretKey'];

        final Uint8List publicKey =
            e.data['data']['myskyRootKeypair']['publicKey'];

        log('received seed, initializing key pair...');

        final simplePublicKey = SimplePublicKey(
          publicKey,
          type: KeyPairType.ed25519,
        );

        skynetUser = SkynetUser.fromKeyPair(
          SimpleKeyPairData(
            privateKey.sublist(0, 32),
            publicKey: simplePublicKey,
            type: KeyPairType.ed25519,
          ),
          simplePublicKey,
        );

        isLoggedIn = true;
        log('ready.');
        // }
        return;

        channel = HtmlWebSocketChannel.connect(
          Uri.parse(
            'ws://localhost:43913',
          ),
        );
        // TODO Auto-reconnect
        channel.stream.listen(
          (event) {
            final msg = json.decode(event);
            if (msg['method'] == 'initAuth') {
              identityDACServerActive = true;
              isLoggedIn = true;
              log('SERVER CONNECTION ACTIVE');
              encryptedBox.put('is_enabled', true);
              return;
            }

            final String nonce = msg['nonce'];
            if (identityDACServerRequests.containsKey(nonce)) {
              identityDACServerRequests[nonce]!.complete(msg);
            }
            return;

            // TODO Get responses here
          },
        );

        if (!encryptedBox.containsKey('ws_key')) {
          encryptedBox.put(
            'ws_key',
            hex.encode(
              SkynetUser.generateRandomKey(),
            ),
          );
        }

        channel.sink.add(
          json.encode({
            'method': 'initAuth',
            'key': encryptedBox.get('ws_key'),
          }),
        );
      } catch (e, st) {
        log(e);
        log(st);
      }

      return;
    } else if (e.data['method'] == 'response') {
      final String nonce = e.data['nonce'];
      if (kernelRequests.containsKey(nonce)) {
        kernelRequests[nonce]!.complete(e.data);
      }
      return;
    }

    while (!isLoggedIn) {
      await Future.delayed(Duration(milliseconds: 10));
    }

    final String nonce = e.data['nonce'];

    try {
      final String domain = e.data['domain'];
      final dynamic data = e.data['data'];

      log('> $method $data (domain: ${e.data['domain']})');

      if (method == 'checkLogin') {
        if (identityDACServerActive) {
          respond(nonce, true);
        } else {
          respond(nonce, isLoggedIn);
        }
      } else if (method == 'userID') {
        if (identityDACServerActive) {
          final res = await callIdentityDAC(domain, 'userID');
          respond(nonce, res);
        } else {
          respond(nonce, skynetUser.id);
        }
      } else if (method == 'signRegistryEntry') {
        if (identityDACServerActive) {
          final res = await callIdentityDAC(
            domain,
            'signRegistryEntry',
            data,
          );
          respond(nonce, res);
        } else {
          // final registryEntry = data['entry'];
          final String path = data['path'];
          await validatePathAccess(domain, path);
          // log(registryEntry['revision']);

          final rv = RegistryEntry(
            datakey: null,
            data: base64Url.decode(data['data']),
            revision: data['revision'] is int
                ? data['revision']
                : int.parse(data['revision']),
          );

          rv.hashedDatakey = deriveDiscoverableTweak(path);

          final sig = await skynetUser.sign(rv.hash());

          respond(nonce, base64Url.encode(sig.bytes));
        }
      } /*  else if (method == 'signEncryptedRegistryEntry') {
        final String path = data['path'];
        await validatePathAccess(domain, path);

        final rv = RegistryEntry(
          datakey: null,
          data: base64Url.decode(data['data']),
          revision: data['revision'] is int
              ? data['revision']
              : int.parse(data['revision']),
        );

        final pathSeed = await mysky_io_impl.getEncryptedPathSeed(
          path,
          false,
          skynetUser.rawSeed,
        );

        rv.hashedDatakey = Uint8List.fromList(
          hex.decode(
            deriveEncryptedFileTweak(pathSeed),
          ),
        );

        final sig = await skynetUser.sign(rv.hash());

        respond(nonce, base64Url.encode(sig.bytes));
      } else if (method == 'getEncryptedFileSeed') {
        final String path = data['path'];

        await validatePathAccess(domain, path);

        final seed = await mysky_io_impl.getEncryptedPathSeed(
          path,
          data['isDirectory'],
          skynetUser.rawSeed,
        );
        respond(nonce, seed);
      } */
    } catch (e) {
      respondErr(nonce, e.toString());
    }
  });
}

// example.hns: SKYLINK
final domainMap = <String, String>{};

Future<void> validatePathAccess(String domain, String path) async {
  return;

  log('validatePathAccess $domain $path $domainMap');
  final parts = path.split('/');
  final pathDomain = parts[0];
  if (domain != pathDomain) {
    if (pathDomain.endsWith('.hns')) {
      if (!domainMap.containsKey(pathDomain)) {
        final res = await callModule(
          'AQDJKcL_ciRYOZ-T4N5SfKrKU2LSwrOU1-L7v1K8Uu0xPQ',
          'hnsres',
          {
            'tld': pathDomain.substring(0, pathDomain.length - 4),
          },
        );
        final String resolverSkylink = res['skylink'].substring(6);
        domainMap[pathDomain] = resolverSkylink;
      }
      if (domainMap[pathDomain] == domain) {
        return;
      }
    }
    throw 'Access denied.';
  }
}
