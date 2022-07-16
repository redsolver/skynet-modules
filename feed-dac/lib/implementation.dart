import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:dac_modules_base/base.dart';
import 'package:canonical_json/canonical_json.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:feed_dac_module/model/cached_entry.dart';
import 'package:hive/hive.dart';
import 'package:pool/pool.dart';
import 'package:skynet/skynet.dart';
import 'package:skynet/src/kernel/module.dart';
import 'package:skynet/src/skystandards/types.dart';
import 'package:skynet/src/mysky/tweak.dart';
import 'package:skynet/src/registry.dart';
import 'package:skynet/src/registry_classes.dart';
import 'package:skynet/src/websocket.dart';
import 'package:cryptography/cryptography.dart';
import 'package:messagepack/messagepack.dart' as msgpack;
import 'package:tuple/tuple.dart';

const dataDomain = 'feed-dac.hns';

class FeedDACModuleImplementation extends FeedDACModule with Permissions {
  final MySkyProvider mySkyProvider;

  final SocialDACModule socialDAC;

  late final WebSocketConnection _ws;

  final BridgeDACModule? bridgeDAC;

  final QueryDACModule queryDAC;

  FeedDACModuleImplementation(
    this.mySkyProvider, {
    required this.socialDAC,
    required this.bridgeDAC,
    required this.queryDAC,
  }) {
    declarePermissions(
      dataDomain,
      {},
    );
    _init();
  }

  void _init() async {
    _ws = WebSocketConnection(mySkyProvider.client);
    _ws.onConnectionStateChange = () {
      print('WebSocket connection state ${_ws.connectionState.type}');
    };
    _ws.connect();

    Hive.registerAdapter(CachedEntryAdapter());
    Hive.registerAdapter(SetAdapter());

    // TODO Remove deprecated types
    Hive.registerAdapter(FeedPageAdapter());
    Hive.registerAdapter(PostAdapter());
    Hive.registerAdapter(PostContentAdapter());
    Hive.registerAdapter(MediaAdapter());
    Hive.registerAdapter(AudioAdapter());
    try {
      Hive.registerAdapter(ImageAdapter());
    } catch (_) {}
    Hive.registerAdapter(VideoAdapter());

    _feedPageCache =
        await Hive.openBox<CachedEntry>('cache-$dataDomain-feed-pages');

    _feedIndexCache =
        await Hive.openBox<Uint8List>('cache-$dataDomain-feed-index');

    _bridgeFeedCache =
        await Hive.openLazyBox<FeedPage>('cache-$dataDomain-bridge-feed-posts');

    _commentRelationsCache =
        await Hive.openBox<Set<String>>('cache-$dataDomain-comment-relations');

    _isReady = true;

    Timer.periodic(Duration(milliseconds: 500), (timer) async {
      if (await mySkyProvider.checkLogin()) {
        _onUserLogin();
        timer.cancel();
      }
    });
  }

  bool _isMySkyReady = false;

  @override
  Future<bool> isMySkyReady() => Future.value(_isMySkyReady);

  bool _isReady = false;

  @override
  Future<bool> isReady() => Future.value(_isReady);

  late Box<CachedEntry> _feedPageCache;
  late Box<Uint8List> _feedIndexCache;

  late LazyBox<FeedPage> _bridgeFeedCache;

  late Box<Set<String>> _commentRelationsCache;

  void _onUserLogin() async {
    await _updateFollowing();

    socialDAC.onFollowingChange().listen((event) {
      _updateFollowing();
    });

    _runBridgeFetcher();

    _isMySkyReady = true;
  }

  final pool = Pool(1);

  void _runBridgeFetcher() async {
    int _currentIndex = 0;
    bool _isFirstRun = true;

    await Future.delayed(Duration(seconds: 1));

/*     Stream.periodic(Duration(seconds: 15)).listen((event) {
      pool.withResource(
        () => loadPostsForUser(
          ownFollowingList.reversed.toList()[1],
          useCache: false,
        ),
      );
    }); */

    while (true) {
      if (_isFirstRun) {
        // await Future.delayed(Duration(milliseconds: 100));
      } else {
        await Future.delayed(
            Duration(minutes: 15) * (1 / ownFollowingList.length));
      }

      if (_currentIndex >= ownFollowingList.length) {
        _currentIndex = 0;
        _isFirstRun = false;
      }

      final userId = ownFollowingList[_currentIndex];

      // TODO Enable for native and add web bridge
      if (false && userId.contains('@')) {
        // print('FETCH $userId');
        pool.withResource(
          () => loadPostsForUser(
            userId,
            useCache: false,
          ).timeout(
            Duration(seconds: 60),
          ),
        );
      }

      _currentIndex++;
    }
  }

  var ownFollowingList = <String>[];

  Future<void> _updateFollowing() async {
    final ownUserId = await mySkyProvider.userId();
    ownFollowingList = await socialDAC.getFollowingForUser(
      ownUserId,
    );

    ownFollowingList.add(ownUserId);

    multiFeeds['$ownUserId/@following'] =
        ownFollowingList.map((userId) => '$userId/posts').toList();

    var feedId = 'posts';
    for (final userId in ownFollowingList) {
      final userFeedKey = '$userId/$feedId';
      if (!feedStreams.containsKey(userFeedKey)) {
        _subscribeToFeed(userId, feedId);
      }
    }

    feedId = 'comments';
    for (final userId in ownFollowingList) {
      final userFeedKey = '$userId/$feedId';
      if (!feedStreams.containsKey(userFeedKey)) {
        _subscribeToFeed(userId, feedId);
      }
    }
  }

  void _subscribeToFeed(String userId, String feedId) {
    final userFeedKey = '$userId/$feedId';
    final _ctrl = StreamController<Post>.broadcast();
    feedStreams[userFeedKey] = _ctrl;

    if (userId.contains('@')) return;

    final indexPath = '$dataDomain/feed/$feedId/index.json';

    _ws.subscribe(userId, indexPath).listen((sre) async {
      final bytes = sre.entry.data.sublist(1);
      _cacheFeedIndex(userId, feedId, bytes);
      final p = msgpack.Unpacker(bytes);
      final list = p.unpackList();

      info('[sub/event] $userFeedKey $list');

      final index = FeedIndex.fromList(
        list,
        sre.entry.revision,
      );
      int requiredItemCount = index.currentPageItemCount;
      bool isOnCurrentPage = true;

      final downloadPageCount = ownFollowingList.contains(userId) ? 8 : 2;

      info('ws_debug_1 $downloadPageCount');

      for (int i = index.currentPageNumber;
          i >= max(0, index.currentPageNumber - downloadPageCount);
          i--) {
        info('ws_debug_2 $i');
        final page = await fetchPage(
          feedId,
          i,
          userId: userId,
          useCache: true,
        );
        if (page.items.length < requiredItemCount) {
          info('ws_debug_3 $i FETCH');
          final currentPage = await fetchPage(
            feedId,
            i,
            userId: userId,
            useCache: false,
          );
          if (isOnCurrentPage) {
            info('ws_debug_4 ADD TO STREAM');
            for (final post in currentPage.items.sublist(page.items.length)) {
              info('ws_debug_5 ADD TO STREAM ${post} ${json.encode(post)}');
              _ctrl.add(post);
            }
          }
        } else {
          break;
        }

        requiredItemCount = index.pageSize;
        isOnCurrentPage = false;
      }
    });
  }

  // TODO permissions

  @override
  Future<String> createComment(
    PostContent content,
    String commentTo,
    Post parent, {
    CallContext? context,
  }) {
    return handleNewPost(
        'comments', content, false, null, commentTo, parent, []);
  }

  @override
  Future<String> createPost(
    PostContent content, {
    CallContext? context,
  }) {
    return handleNewPost('posts', content, false, null, null, null, []);
  }

  @override
  Future<String> createRepost(
    String repostOf,
    Post parent, {
    CallContext? context,
  }) {
    return handleNewPost('posts', null, true, repostOf, null, parent, []);
  }

  @override
  Future<void> deletePost(
    String ref, {
    CallContext? context,
  }) async {
    throw 'Not implemented';
    /*  if (ref.startsWith('sky://')) {
        ref = 'https://' + ref.substring(6);
      } else {
        throw Error('FeedDAC: Unsupported protocol')
      }
      const url = new URL(ref);

      let userId = url.hostname;

      if (userId.startsWith('ed25519-')) {
        userId = userId.substring(8);
      } else if (userId.length == 64) {
      } else {
        throw Error('FeedDAC: Unsupported userId format')
      }

      if (!url.pathname.startsWith(`/${DATA_DOMAIN}/${this.skapp}/`)) {
        throw Error('Your skapp does not have permission to delete this post')
      }

      const res = await this.client.file.getJSON(userId, url.pathname.substring(1));

      if (res.data == null) {
        throw Error('This post does not exist')
      }

      let index: number = + url.hash.substring(1);

      for (let item of (res.data.items as Post[])) {
        if (item.id === index) {
          item.isDeleted = true;
          item.content = {};
          break;
        }
      }

      await this.updateFile(url.pathname.substring(1), res.data);

      return {
        success: true,
      }; */
  }

  @override
  Future<Post> loadPost(String ref) async {
    final uri = Uri.tryParse(ref.replaceFirst('$dataDomain/', ''));

    info('loadPost 1');

    if (uri == null) throw 'Invalid URI';

    var userId = uri.authority;

    /*   if (userId.startsWith('ed25519-')) {
      userId = userId.substring(8);
    } else */

    info('loadPost 2');

    if (userId.contains('@')) {
      return bridgeDAC!.loadPost(ref);
    } else if (userId.length == 64) {
    } else {
      throw 'FeedDAC: Unsupported userId format';
    }

    info('loadPost 3');

    final pageNumber = int.parse(uri.pathSegments.reversed.toList()[1]);
    final feedId = uri.pathSegments[1];

    final pagePath = ([dataDomain] +
            uri.pathSegments.sublist(0, uri.pathSegments.length - 2) +
            ['page_$pageNumber.json'])
        .join('/');

    // '$dataDomain/feed/$feedId/page_${currentPageNumber}.json';

    final index = int.tryParse(uri.pathSegments.last);

    info('pagePath $pagePath');

    final cacheKey = '$userId/$pagePath';

    // print('loadPost 4');

    final cachedEntry = _feedPageCache.get(cacheKey);
    if (cachedEntry != null) {
      // print('loadPost 5');
      final data = json.decode(cachedEntry.data);
      if (data != null) {
        if ((data['items'] ?? []).length > index) {
          return Post.fromJson(
            data['items'][index],
            feedPageUri: buildFeedUri(
              userId: userId,
              feedId: feedId,
              pageNumber: pageNumber,
            ),
          );
        }
      }
    }

    // print('loadPost 6 $userId/$pagePath');

    final res = await mySkyProvider.client.file.getJSONWithRevision(
      userId,
      pagePath,
    );

    // print('loadPost 7');

    if (res.data == null) {
      throw 'Post not found (page)';
    }
    _feedPageCache.put(
      cacheKey,
      CachedEntry(
        revision: res.revision,
        data: json.encode(res.data),
      ),
    );

    final item = res.data['items']?[index];
    if (item == null) {
      throw 'Post not found (index)';
    }

    return Post.fromJson(
      item,
      feedPageUri: buildFeedUri(
        userId: userId,
        feedId: feedId,
        pageNumber: pageNumber,
      ),
    );
  }

  final earliestItemTimestampsPerPage = <String, Map<int, int>>{};

  final currentPageNumbers = <String, int>{};

  final multiFeeds = <String, List<String>>{};

  final feedStreams = <String, StreamController<Post>>{};

  final commentStreams = <String, StreamController<Post>>{};

  StreamController<Post> getCommentsStreamController(String ref) {
    if (!commentStreams.containsKey(ref)) {
      commentStreams[ref] = StreamController<Post>.broadcast();
    }
    return commentStreams[ref]!;
  }

  @override
  Stream<Post> listenForPosts(
    String userId, {
    String feedId = 'posts',
  }) async* {
    // if (userId.contains('@')) return;

    final userFeedKey = '$userId/$feedId';
    if (multiFeeds.containsKey(userFeedKey)) {
      // info('yield* ufks ${multiFeeds}');
      final streams = <Stream<Post>>[];
      for (final ufk in multiFeeds[userFeedKey]!) {
        // if (ufk.contains('@')) continue;

        if (!feedStreams.containsKey(ufk)) {
          final parts = ufk.split('/');
          try {
            _subscribeToFeed(parts[0], parts[1]);
          } catch (e, st) {
            info('yield* crash $ufk $e $st');
          }
        }
        // info('yield* $ufk');
        streams.add(feedStreams[ufk]!.stream);
      }

      yield* StreamGroup.merge(streams);

      return;
    }
    if (!feedStreams.containsKey(userFeedKey)) {
      _subscribeToFeed(userId, feedId);
    }
    yield* feedStreams[userFeedKey]!.stream;
  }

  Stream<List<Post>> _loadMultiFeeds(List<String> feeds,
      {int minItemsPerPage = 8}) async* {
    /*    LoadingState state = LoadingState.loadMore;

enum LoadingState {
  idle,
  loadMore,
  done,
} */
/* 

void main() async {
  final ctrl = StreamController<Null>();
  loadPosts(8, ctrl.stream).listen((event) {
    print('Got page $event');
  });

  await Future.delayed(Duration(seconds: 3));
  state = LoadingState.loadMore;
  await Future.delayed(Duration(seconds: 3));
  state = LoadingState.done;
  await Future.delayed(Duration(seconds: 3));
} */

/* Stream<List<Post>> loadPosts(
    int minPageLength, Stream<Null> pageLoading) async* { */

    if (feeds.isEmpty) {
      yield [];
      // TODO state = LoadingState.done;
      return;
    }

    final skapps = feeds;

    final buffer = <Post>[];

    final skappPostBuffer = <Post>[];

    final bridgePosts = <String, List<Post>>{};

    final futures = <Future>[];

    for (final feed in feeds) {
      if (feed.contains('@')) {
        // TODO Custom feedId support

        // print('CONTAINS $feed ${_bridgeFeedCache.containsKey(feed)}');

        if (_bridgeFeedCache.containsKey(feed)) {
          bridgePosts[feed] = (await _bridgeFeedCache.get(feed))!.items;
        } else {
          futures.add(() async {
            bridgePosts[feed] =
                await bridgeDAC!.loadPostsForUser(feed.split('/').first);
          }());
        }
      }
    }
    await Future.wait(futures);

    final skappTimestampLimit = <String, int>{};
    final skappCurrentPage = <String, int>{};
    final limitBeforePageEnd = <String, int>{};

    for (final skapp in List<String>.from(skapps)) {
      if (bridgePosts.containsKey(skapp)) {
        if (bridgePosts[skapp]!.isEmpty) continue;

        skappTimestampLimit[skapp] = bridgePosts[skapp]!.first.ts!;
        skappCurrentPage[skapp] = 0;
        continue;
      }
      final parts = skapp.split('/');
      final index = _getFeedIndexCached(parts[0], parts[1]) ??
          await fetchIndex(parts[1], userId: parts[0]);

      // print('[debug] [FeedDAC] $index');
      if (index.latestItemTimestamp == 0) {
        /* final index = skapps.indexOf(skapp, 0);
        if (index > -1) { */
        skapps.remove(skapp);
        // }
      } else {
        skappTimestampLimit[skapp] = index.latestItemTimestamp;
        skappCurrentPage[skapp] = index.currentPageNumber;
      }
    }

    final bool onlyOneSkapp = skapps.length == 1;

    String? nextSkapp;
    String? ignoreSkapp;
    int? currentLimit;

    // Select priority skapp

    while (true) {
      if (skappTimestampLimit.isEmpty) {
        break;
      }
      String currentSkapp;
      if (onlyOneSkapp) {
        currentSkapp = skapps.first;
      } else if (nextSkapp == null) {
        final highestLimit =
            _getLatestSkapp(skappTimestampLimit, exclude: ignoreSkapp);

        currentSkapp = highestLimit.item1;

        //print('highestLimit $highestLimit');
      } else {
        currentSkapp = nextSkapp;
      }

      final secondHighestLimit =
          _getLatestSkapp(skappTimestampLimit, exclude: currentSkapp);

      //print('secondHighestLimit $secondHighestLimit');

      final localLimitBeforePageEnd = limitBeforePageEnd[currentSkapp];

      if (localLimitBeforePageEnd == null ||
          currentLimit == null ||
          currentLimit <= localLimitBeforePageEnd) {
        if ((skappCurrentPage[currentSkapp] ?? -1) < 0) {
        } else {
          List<Post> posts;

          if (bridgePosts.containsKey(currentSkapp)) {
            posts = bridgePosts[currentSkapp]!.reversed.toList();
          } else {
            print(
              '[http] load page $currentSkapp.${skappCurrentPage[currentSkapp]}',
            );
            final parts = currentSkapp.split('/');
            try {
              // TODO Handle errors
              final page = await fetchPage(
                parts[1],
                skappCurrentPage[currentSkapp]!,
                userId: parts[0],
                useCache: true,
              );
              posts = page.items;
            } catch (e, st) {
              print(e);
              print(st);
              posts = [];
            }
          }

          skappCurrentPage[currentSkapp] =
              (skappCurrentPage[currentSkapp] ?? 0) - 1;

          //

          limitBeforePageEnd[currentSkapp] =
              posts.isEmpty ? 0 : posts[0].ts ?? 0; // TODO Sort

          skappPostBuffer.addAll(posts);

          // skappCurrentPage[currentSkapp]--;
        }
      }

      skappPostBuffer.sort((a, b) => -(a.ts ?? 0).compareTo(b.ts ?? 0));

      ignoreSkapp = null;
      nextSkapp = null;

      while (skappPostBuffer.isNotEmpty) {
        final post = skappPostBuffer.first;
        skappTimestampLimit[currentSkapp] = post.ts ?? 0;
        currentLimit = post.ts;

        if ((post.ts ?? 0) < secondHighestLimit.item2) {
          nextSkapp = secondHighestLimit.item1;
          ignoreSkapp = currentSkapp;
          break;
        }

        buffer.add(post);

        skappPostBuffer.removeAt(0);
      }

      if (buffer.length >= minItemsPerPage) {
        // TODO state = LoadingState.idle;

        trustPostMediaUrls(buffer);

        yield buffer;
        buffer.clear();
        /* TODO while (state == LoadingState.idle) {
        await Future.delayed(Duration(milliseconds: 20));
      }
      if (state == LoadingState.done) {
        return;
      } */
      }

      if (skappPostBuffer.isEmpty) {
        skappTimestampLimit[currentSkapp] =
            (skappTimestampLimit[currentSkapp] ?? 0) - 1;

        if ((skappCurrentPage[currentSkapp] ?? -1) < 0) {
          skappCurrentPage.remove(currentSkapp);
          skappTimestampLimit.remove(currentSkapp);
        }
      }
    }

    trustPostMediaUrls(buffer);

    yield buffer;
    print('Reached end of all posts.');
// TODO  state = LoadingState.done;
  }

  void trustPostMediaUrls(List<Post> posts) {
    for (final post in posts) {
      // TODO Re-add
      /* final urls = [
        ...(post.content?.media?.audio?.map((e) => e.url).toList() ?? []),
        ...(post.content?.media?.video?.map((e) => e.url).toList() ?? []),
        ...(post.content?.media?.image?.map((e) => e.url).toList() ?? []),
      ];
      for (final url in urls) {
        mySkyProvider.client.addTrustedDomain(url);
      } */
    }
  }

  Tuple2<String, int> _getLatestSkapp(
    Map<String, int> limitMap, {
    String? exclude,
  }) {
    int maxLimit = 0;
    String maxSkapp = '';
    for (final skapp in limitMap.keys) {
      if (skapp == exclude) continue;

      final limit = limitMap[skapp] ?? 0;

      if (limit > maxLimit) {
        maxLimit = limit;
        maxSkapp = skapp;
      }
    }
    return Tuple2(maxSkapp, maxLimit);
  }

  @override
  Future<List<Post>> loadPostsForUser(
    String userId, {
    String feedId = 'posts',
    int? beforeTimestamp,
    bool useCache = true,
  }) async {
    final userFeedKey = '$userId/$feedId';
    info('loadPostsForUser $userFeedKey');

    if (userId.contains('@')) {
      info('loadPostsForUser bridge mode');
      final oldPosts = (await _bridgeFeedCache.get(userFeedKey))?.items ?? [];

      if (oldPosts.isEmpty) {
        info('loadPostsForUser old posts is empty, normal full fetch');
        final posts = await bridgeDAC!.loadPostsForUser(
          userId,
          beforeTimestamp: beforeTimestamp,
          feedId: feedId,
        );
        _bridgeFeedCache.put(userFeedKey, FeedPage(items: posts));
        trustPostMediaUrls(posts);
        return posts;
      } else {
        info('loadPostsForUser old posts exists, doing delta fetch');
        final future = bridgeDAC!
            .loadPostsForUser(
          userId,
          beforeTimestamp: beforeTimestamp,
          feedId: feedId,
        )
            .then((posts) {
          info('loadPostsForUser: delta update received');
          final oldPostRefs = oldPosts.map((e) => e.fullRef).toSet();

          info('loadPostsForUser: old refs ready');
          // bool hasChanges = false;
          trustPostMediaUrls(posts);
          for (final post in posts.reversed) {
            if (!oldPostRefs.contains(post.fullRef)) {
              info(
                'loadPostsForUser: delta - FOUND NEW REF ${json.encode(post)}',
              );
              feedStreams[userFeedKey]!.add(post);
              info(
                'loadPostsForUser: delta - FOUND NEW REF - added to stream',
              );
              // hasChanges = true;
            }
          }
          // if (hasChanges) {
          _bridgeFeedCache.put(userFeedKey, FeedPage(items: posts));
          // }
        });
        if (!useCache) {
          info('loadPostsForUser useCache mode false, waiting on response...');
          await future;
        }

        trustPostMediaUrls(oldPosts);
        return oldPosts;
      }
      // trustPostMediaUrls(posts);

    }

    info('loadPostsForUser $userFeedKey $beforeTimestamp');

    if (multiFeeds.containsKey(userFeedKey)) {
      return _loadMultiFeeds(multiFeeds[userFeedKey]!).fold<List<Post>>(
        <Post>[],
        (previous, element) => previous + element,
      );
    }

    earliestItemTimestampsPerPage[userFeedKey] ??= {};

    final map = earliestItemTimestampsPerPage[userFeedKey]!;

    if (beforeTimestamp == null) {
      FeedIndex? index;
      if (feedStreams.containsKey(userFeedKey)) {
        index = _getFeedIndexCached(userId, feedId);
      }

      index ??= await fetchIndex(feedId, userId: userId);

      currentPageNumbers[userFeedKey] = index.currentPageNumber;

      final page = await fetchPage(
        feedId,
        index.currentPageNumber,
        userId: userId,
        useCache: feedStreams.containsKey(userFeedKey),
      );

      map[index.currentPageNumber] =
          page.items.isEmpty ? 0 : page.items.first.ts!;
      return page.items.reversed.toList();
    } else {
      int fetchPageIndex = -1;
      for (int i = currentPageNumbers[userFeedKey]!; i >= 0; i--) {
        if (map.containsKey(i)) {
          if (map[i]! < beforeTimestamp) {
            fetchPageIndex = i;
            break;
          }
        } else {
          fetchPageIndex = i;
          break;
        }
      }

      info('LOAD PAGE ${fetchPageIndex}');

      if (fetchPageIndex == -1) return [];

      var page = await fetchPage(
        feedId,
        fetchPageIndex,
        userId: userId,
        useCache: true,
      );
      final feedIndex = _getFeedIndexCached(userId, feedId);

      if (feedIndex != null) {
        if (page.items.length < feedIndex.pageSize) {
          info(
              'detected invalid cached page, fetching again... ($userId/$feedId)');
          page = await fetchPage(
            feedId,
            fetchPageIndex,
            userId: userId,
            useCache: false,
          );
        }
      }

      map[fetchPageIndex] = page.items.first.ts!;

      return page.items.reversed.toList();
    }
  }

  // TODO Realtime updates (use stream -> following first, then add server fetched ones, maybe pagination later)
  @override
  Stream<CommentsPage> loadCommentsForPost(String ref) async* {
    final commentRefs = _commentRelationsCache.get(ref) ?? <String>{};

    final uri = Uri.parse(ref);

    final futures = <Future<Post>>[];
    for (final commentRef in commentRefs) {
      futures.add(loadPost(commentRef));
    }
    final comments = await Future.wait(futures);

    yield CommentsPage(
      posts: comments,
      isNew: false,
    );
    print('comment load 1');

    final queryPosts = <Post>[];

    for (final commentRef in await queryDAC.getPostComments(ref) ?? []) {
      if (!commentRefs.contains(commentRef)) {
        queryPosts.add(Post()..realRef = commentRef);
        print('comment load x $commentRef');
        // final post = await loadPost(commentRef);
        print('comment load xdone $commentRef');
      }
    }
    if (queryPosts.isNotEmpty) {
      yield CommentsPage(
        posts: queryPosts,
        isNew: false,
      );
    }
    print('comment load 2');

    if (uri.authority.contains('@')) {
      yield CommentsPage(
        posts: await bridgeDAC!.loadCommentsForPost(ref),
        isNew: false,
      );
    }
    yield* getCommentsStreamController(ref).stream.map(
          (post) => CommentsPage(
            posts: [post],
            isNew: true,
          ),
        );
  }

  Future<String> handleNewPost(
    String feedId,
    PostContent? content,
    bool isRepost,
    String? repostOf,
    String? commentTo,
    Post? parent,
    List<String> mentions,
  ) async {
    info("handleNewPost $feedId");

    final index = await fetchIndex(feedId);
    var page = await fetchPage(feedId, index.currentPageNumber);

    if (page.items.length >= index.pageSize) {
      page = FeedPage(
        items: [],
      );
      index.currentPageNumber += 1;
    }

    final newPost = Post(
      id: page.items.length,
    );

    if (isRepost && repostOf != null) {
      newPost.repostOf = repostOf;

      // parent?.content?.media?.aspectRatio = null;
      final parentMap = json.decode(json.encode(parent));
      newPost.parentHash =
          "1220" + sha256.convert(canonicalJson.encode(parentMap)).toString();
    } else {
      if (content == null) {
        throw 'No PostContent';
      }

      newPost.content = content;

      /* if (newPost.content == null) {
        newPost.content = null;
      } */

      if (commentTo != null) {
        newPost.commentTo = commentTo;

        // parent?.content?.media?.aspectRatio = null;
        final parentMap = json.decode(json.encode(parent));
        newPost.parentHash =
            "1220" + sha256.convert(canonicalJson.encode(parentMap)).toString();

        /*  usersToMention.addAll(parent.mentions ?? []); */

        // newPost.mentions = List.from(parent.mentions ?? []);

        /*       if (!usersToMention.contains(parent.userId)) {
          if (!bridges.isBridgedPost(parent.userId)) {
            usersToMention.add(parent.userId);
          }
        }
        usersToMention.remove(AppState.userId); */

        // usersToMention.addAll(newPost.mentions);
      }
    }
    // newPost.mentions = usersToMention.toSet().toList();

    // print('mentions ${newPost.mentions}');

    newPost.ts = DateTime.now().millisecondsSinceEpoch;

    /* newPost.content.postedAt = postedAt != null
        ? DateTime.fromMillisecondsSinceEpoch(postedAt)
        : DateTime.now(); */

    //    int currentPointer = pointerBox.get('${AppState.userId}/feed/$feedId') ?? 0;

    /* print('current{$feedId}Pointer $currentPointer');

    var fp =
        await feedPages.get('${AppState.userId}/feed/$feedId/$currentPointer'); */

    // String newFullPostId;

    info("newPost $newPost");

    page.items.add(newPost);

    info("page ${page.items}");

    index.latestItemTimestamp = newPost.ts!;
    index.currentPageItemCount = page.items.length;

    final feedPagePath =
        '$dataDomain/feed/$feedId/page_${index.currentPageNumber}.json';

    await mySkyProvider.setJSON(feedPagePath, page, page.revision + 1);

    await updateIndex(feedId, index);

    return buildFeedUri(
      userId: await mySkyProvider.userId(),
      feedId: feedId,
      pageNumber: index.currentPageNumber,
      postId: newPost.id,
    );
  }

  String buildFeedUri({
    required String userId,
    required String feedId,
    required int pageNumber,
    int? postId,
  }) {
    if (postId == null) {
      return 'skyfeed://$userId/feed/$feedId/$pageNumber';
    } else {
      return 'skyfeed://$userId/feed/$feedId/$pageNumber/$postId';
    }
  }

  // updateIndex is called after a new entry got inserted and will update the
  // index to reflect this recently inserted entry.
  Future<void> updateIndex(String feedId, FeedIndex index) async {
    final indexPath = '$dataDomain/feed/$feedId/index.json';

    final p = msgpack.Packer();

    p.packListLength(index.toList().length);

    for (final item in index.toList()) {
      if (item is int) {
        p.packInt(item);
      } else {
        p.packString(item);
      }
    }
    final bytes = p.takeBytes();

    final rv = RegistryEntry(
      datakey: null,
      data: Uint8List.fromList([128] + bytes),
      revision: index.revision + 1,
    );

    rv.hashedDatakey = deriveDiscoverableTweak(indexPath);

    final userId = await mySkyProvider.userId();

    final sig = Signature(
      await mySkyProvider.signRegistryEntry(rv, indexPath),
      publicKey: SimplePublicKey(hex.decode(userId), type: KeyPairType.ed25519),
    );

    final srv = SignedRegistryEntry(signature: sig, entry: rv);

    // update the registry
    final updated = await mySkyProvider.client.registry.setEntryRaw(
      SkynetUser.fromId(userId),
      '',
      srv,
      hashedDatakey: hex.encode(rv.hashedDatakey!),
    );

    if (!updated) throw 'Could not update registry entry';
  }

  // fetchIndex downloads the index, if the index does not exist yet it will
  // return the default index.
  Future<FeedIndex> fetchIndex(String feedId, {String? userId}) async {
    final indexPath = '$dataDomain/feed/$feedId/index.json';

    final tweak = deriveDiscoverableTweak(indexPath);

    userId ??= await mySkyProvider.userId();

    final sre = await mySkyProvider.client.registry.getEntry(
        SkynetUser.fromId(userId), '',
        hashedDatakey: hex.encode(tweak));

    if (sre == null) {
      return FeedIndex();
    }

    final bytes = sre.entry.data.sublist(1);

    _cacheFeedIndex(userId, feedId, bytes);

    final p = msgpack.Unpacker(bytes);

    final list = p.unpackList();

    info('fetchIndex ${list}');

    return FeedIndex.fromList(
      list,
      sre.entry.revision,
    );
  }

  FeedIndex? _getFeedIndexCached(String userId, String feedId) {
    final bytes = _feedIndexCache.get('$userId/$feedId');
    if (bytes != null) {
      return FeedIndex.fromList(
        msgpack.Unpacker(bytes).unpackList(),
        -1,
      );
    }
  }

  void _cacheFeedIndex(String userId, String feedId, Uint8List bytes) {
    _feedIndexCache.put('$userId/$feedId', bytes);
  }

  // fetchPage downloads the current page for given index, if the page does not
  // exist yet it will return the default page.
  Future<FeedPage> fetchPage(
    String feedId,
    int currentPageNumber, {
    String? userId,
    bool useCache = false,
  }) async {
    final feedPagePath =
        '$dataDomain/feed/$feedId/page_${currentPageNumber}.json';

    userId ??= await mySkyProvider.userId();

    final cacheKey = '$userId/$feedPagePath';

    if (useCache) {
      final cachedEntry = _feedPageCache.get(cacheKey);
      if (cachedEntry != null) {
        final data = json.decode(cachedEntry.data);

        if (data != null) {
          return FeedPage(
            items: data['items']
                .map<Post>((m) => Post.fromJson(
                      m,
                      feedPageUri: buildFeedUri(
                        userId: userId!,
                        feedId: feedId,
                        pageNumber: currentPageNumber,
                      ),
                    ))
                .toList(),
            revision: cachedEntry.revision,
          );
        }
      }
    }

    final res = await mySkyProvider.client.file.getJSONWithRevision(
      userId,
      feedPagePath,
    );

    if (res.data == null) {
      return FeedPage(
        items: [],
      );
    }

    _feedPageCache.put(
      cacheKey,
      CachedEntry(
        revision: res.revision,
        data: json.encode(res.data),
      ),
    );

    final items = (res.data['items'] as List)
        .map<Post>((m) => Post.fromJson(
              m,
              feedPageUri: buildFeedUri(
                userId: userId!,
                feedId: feedId,
                pageNumber: currentPageNumber,
              ),
            ))
        .toList();

    for (final item in items) {
      if (item.commentTo != null) {
        print('comment cache add ${item.commentTo}');
        final set = _commentRelationsCache.get(item.commentTo) ?? <String>{};

        if (set.add(item.fullRef)) {
          getCommentsStreamController(item.commentTo!).add(item);

          _commentRelationsCache.put(
            item.commentTo,
            set,
          );
        }
      }
    }

    //

    return FeedPage(
      items: items,
      revision: res.revision,
    );
  }

  @override
  Stream<int> getCommentsCount(String ref) async* {
    // print('getCommentsCount $ref ${_commentRelationsCache.get(ref)?.length}');
    yield _commentRelationsCache.get(ref)?.length ?? 0;
  }
}

class SetAdapter extends TypeAdapter<Set> {
  @override
  final typeId = 105;

  @override
  Set<String> read(BinaryReader reader) {
    return Set<String>.from(reader.read());
  }

  @override
  void write(BinaryWriter writer, Set obj) {
    writer.write(obj.cast<String>().toList());
  }
}
