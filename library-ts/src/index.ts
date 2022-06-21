import * as kernel from "libkernel"


import { DirectoryFile, DirectoryIndex, FileData, Post, PostContent, Profile } from "./skystandards.js";

export * from "./skystandards.js";

const MODULE_SKYLINK_IdentityDAC = 'AQBmFdF14nfEQrERIknEBvZoTXxyxG8nejSjH6ebCqcFkQ';

export class IdentityDAC {
  public constructor() { }

  public async checkLogin(): Promise<boolean> {
    let [data, err] = await kernel.callModule(MODULE_SKYLINK_IdentityDAC, 'checkLogin', {});
    if (err !== null) throw err;
    return data as any;
  }

  public async userID(): Promise<string> {
    let [data, err] = await kernel.callModule(MODULE_SKYLINK_IdentityDAC, 'userID', {});
    if (err !== null) throw err;
    return data as any;
  }
}

const MODULE_SKYLINK_ProfileDAC = 'AQAXZpiIGQFT3lKGVwb8TAX3WymVsrM_LZ-A9cZzYNHWCw';

export class ProfileDAC {
  public constructor() { }
  /// getProfile
  public async getProfile(
    userId: string | null,
  ): Promise<Profile | null> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_ProfileDAC, 'getProfile', {
      'userId': userId,
    });
    if (err !== null) throw err;
    return data as any;
  }
  /// setProfile
  public async setProfile(
    profile: Profile,
  ): Promise<void> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_ProfileDAC, 'setProfile', {
      'profile': profile,
    });
    if (err !== null) throw err;
    return data as any;
  }
  /// searchUsers
  public async searchUsers(
    query: string,
  ): Promise<Profile[]> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_ProfileDAC, 'searchUsers', {
      'query': query,
    });
    if (err !== null) throw err;
    return data as any;
  }
}
const MODULE_SKYLINK_QueryDAC = 'AQAPFg2Wdtld0HoVP0sIAQjQlVnXC-KY34WWDxXBLtzfbw';

export class QueryDAC {
  public constructor() { }
  /// getUserStats
  public async getUserStats(
    userId: string,
  ): Promise<{ [key: string]: any } | null> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_QueryDAC, 'getUserStats', {
      'userId': userId,
    });
    if (err !== null) throw err;
    return data as any;
  }
  /// getUserExists
  public async getUserExists(
    userId: string,
  ): Promise<boolean> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_QueryDAC, 'getUserExists', {
      'userId': userId,
    });
    if (err !== null) throw err;
    return data as any;
  }
  /// getUserFollowers
  public async getUserFollowers(
    userId: string,
  ): Promise<string[] | null> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_QueryDAC, 'getUserFollowers', {
      'userId': userId,
    });
    if (err !== null) throw err;
    return data as any;
  }
  /// getPostStats
  public async getPostStats(
    ref: string,
  ): Promise<{ [key: string]: any } | null> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_QueryDAC, 'getPostStats', {
      'ref': ref,
    });
    if (err !== null) throw err;
    return data as any;
  }
  /// getPostComments
  public async getPostComments(
    ref: string,
  ): Promise<string[] | null> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_QueryDAC, 'getPostComments', {
      'ref': ref,
    });
    if (err !== null) throw err;
    return data as any;
  }
  /// searchUsers
  public async searchUsers(
    query: string,
  ): Promise<string[]> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_QueryDAC, 'searchUsers', {
      'query': query,
    });
    if (err !== null) throw err;
    return data as any;
  }
  /// enable
  public async enable(
  ): Promise<void> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_QueryDAC, 'enable', {
    });
    if (err !== null) throw err;
    return data as any;
  }
}
const MODULE_SKYLINK_SocialDAC = 'AQDETEWOzNYZu5YeOIPhvwpqIn3aL6ghf-ccLpbj3O1EIw';

export class SocialDAC {
  public constructor() { }
  /// follow
  public async follow(
    userId: string,
    ext?: { [key: string]: any },
  ): Promise<void> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_SocialDAC, 'follow', {
      'userId': userId,
      'ext': ext,
    });
    if (err !== null) throw err;
    return data as any;
  }
  /// unfollow
  public async unfollow(
    userId: string,
  ): Promise<void> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_SocialDAC, 'unfollow', {
      'userId': userId,
    });
    if (err !== null) throw err;
    return data as any;
  }
  /// isFollowing
  public async isFollowing(
    userId: string,
  ): Promise<boolean> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_SocialDAC, 'isFollowing', {
      'userId': userId,
    });
    if (err !== null) throw err;
    return data as any;
  }
  /// getFollowingForUser
  public async getFollowingForUser(
    userId: string,
  ): Promise<string[]> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_SocialDAC, 'getFollowingForUser', {
      'userId': userId,
    });
    if (err !== null) throw err;
    return data as any;
  }
  /// getFollowingMapForUser
  public async getFollowingMapForUser(
    userId: string,
  ): Promise<{ [key: string]: any }> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_SocialDAC, 'getFollowingMapForUser', {
      'userId': userId,
    });
    if (err !== null) throw err;
    return data as any;
  }
  /// getFollowingCountForUser
  public async getFollowingCountForUser(
    userId: string,
  ): Promise<number> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_SocialDAC, 'getFollowingCountForUser', {
      'userId': userId,
    });
    if (err !== null) throw err;
    return data as any;
  }
  /// getSuggestedUsers
  public async getSuggestedUsers(
  ): Promise<string[]> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_SocialDAC, 'getSuggestedUsers', {
    });
    if (err !== null) throw err;
    return data as any;
  }
}
const MODULE_SKYLINK_FeedDAC = 'AQCSRGL0vey8Nccy_Pqk3fYTMm0y2nE_dK0I8ro8bZyZ3Q';

export class FeedDAC {
  public constructor() { }
  /// loadPost
  public async loadPost(
    ref: string,
  ): Promise<Post> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_FeedDAC, 'loadPost', {
      'ref': ref,
    });
    if (err !== null) throw err;
    return data as any;
  }
  /// loadPostsForUser
  public async loadPostsForUser(
    userId: string,
    feedId: string,
    beforeTimestamp: number | null,
  ): Promise<Post[]> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_FeedDAC, 'loadPostsForUser', {
      'userId': userId,
      'feedId': feedId,
      'beforeTimestamp': beforeTimestamp,
    });
    if (err !== null) throw err;
    return data as any;
  }
  /// createPost
  public async createPost(
    content: PostContent,
  ): Promise<string> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_FeedDAC, 'createPost', {
      'content': content,
    });
    if (err !== null) throw err;
    return data as any;
  }
  /// createComment
  public async createComment(
    content: PostContent,
    commentTo: string,
    parent: Post,
  ): Promise<string> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_FeedDAC, 'createComment', {
      'content': content,
      'commentTo': commentTo,
      'parent': parent,
    });
    if (err !== null) throw err;
    return data as any;
  }
  /// createRepost
  public async createRepost(
    repostOf: string,
    parent: Post,
  ): Promise<string> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_FeedDAC, 'createRepost', {
      'repostOf': repostOf,
      'parent': parent,
    });
    if (err !== null) throw err;
    return data as any;
  }
  /// deletePost
  public async deletePost(
    ref: string,
  ): Promise<void> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_FeedDAC, 'deletePost', {
      'ref': ref,
    });
    if (err !== null) throw err;
    return data as any;
  }
}
const MODULE_SKYLINK_BridgeDAC = 'AQAKn33Pm9WPcm872JuxnRhowH5UA3Mm_hCb6CMT79nQdw';

export class BridgeDAC {
  public constructor() { }
  /// getProfile
  public async getProfile(
    userId: string,
  ): Promise<Profile | null> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_BridgeDAC, 'getProfile', {
      'userId': userId,
    });
    if (err !== null) throw err;
    return data as any;
  }
  /// loadPost
  public async loadPost(
    ref: string,
  ): Promise<Post> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_BridgeDAC, 'loadPost', {
      'ref': ref,
    });
    if (err !== null) throw err;
    return data as any;
  }
  /// loadPostsForUser
  public async loadPostsForUser(
    userId: string,
    feedId: string,
    beforeTimestamp: number | null,
  ): Promise<Post[]> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_BridgeDAC, 'loadPostsForUser', {
      'userId': userId,
      'feedId': feedId,
      'beforeTimestamp': beforeTimestamp,
    });
    if (err !== null) throw err;
    return data as any;
  }
  /// loadCommentsForPost
  public async loadCommentsForPost(
    ref: string,
  ): Promise<Post[]> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_BridgeDAC, 'loadCommentsForPost', {
      'ref': ref,
    });
    if (err !== null) throw err;
    return data as any;
  }
  /// searchUsers
  public async searchUsers(
    query: string,
  ): Promise<Profile[]> {

    let [data, err] = await kernel.callModule(MODULE_SKYLINK_BridgeDAC, 'searchUsers', {
      'query': query,
    });
    if (err !== null) throw err;
    "moduleResolution": "node",
    return data as any;
  }
}
