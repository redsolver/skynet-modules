/**
 * Multihash of the unencrypted file, starts with 1220 for sha256
 */
export type Multihash = string

export interface Profile {
    version: number;
    username: string;
    firstName?: string;
    lastName?: string;
    emailID?: string;
    contact?: string;
    aboutMe?: string;
    location?: string;
    topics?: string[];
    avatar?: IAvatar[];
    connections?: any[];
}

export interface IAvatar {
    ext: string,
    w: number,
    h: number,
    url: string
}

/**
 * Specific version of a file. Immutable.
 */
export interface FileData {
    /**
     * Can be used by applications to add more metadata
     */
    ext?: { [key: string]: any };

    /**
     * URL where the encrypted file blob can be downloaded, usually a skylink (sia://)
     */
    url: string
    /**
     * The secret key used to encrypt this file, base64Url-encoded
     */
    key?: string
    /**
     * Which algorithm is used to encrypt and decrypt this file
     */
    encryptionType?: string

    /**
     * Unencrypted size of the file, in bytes
     */
    size: number

    /**
     * Padding bytes count
     */
    padding?: number

    /**
     * maxiumum size of every unencrypted file chunk in bytes
     */
    chunkSize?: number
    hash: Multihash
    /**
     * Unix timestamp (in milliseconds) when this version was added to the FileSystem DAC
     */
    ts: number
    [k: string]: unknown
}

/**
 * Metadata of a file, can contain multiple versions
 */
export interface DirectoryFile {

    /**
     * Can be used by applications to add more metadata
     */
    ext?: { [key: string]: any };

    /**
     * Name of this file
     */
    name: string
    /**
     * Unix timestamp (in milliseconds) when this file was created
     */
    created: number
    /**
     * Unix timestamp (in milliseconds) when this file was last modified
     */
    modified: number
    /**
     * MIME Type of the file, optional
     */
    mimeType?: string
    /**
     * Current version of the file. When this file was already modified 9 times, this value is 9
     */
    version: number
    /**
     * The current version of a file
     */
    file: FileData
    /**
     * Historic versions of a file
     */
    history?: {
        /**
         * A file version
         *
         * This interface was referenced by `undefined`'s JSON-Schema definition
         * via the `patternProperty` "^[0-9]+$".
         */
        [k: string]: FileData
    }
    [k: string]: unknown
}

/**
 * Index file of a directory, contains all directories and files in this specific directory
 */
export interface DirectoryIndex {
    /**
     * A subdirectory in this directory
     */
    directories: {
        /**
         * This interface was referenced by `undefined`'s JSON-Schema definition
         * via the `patternProperty` "^.+$".
         */
        [k: string]: {
            /**
             * Name of this directory
             */
            name?: string
            /**
             * Unix timestamp (in milliseconds) when this directory was created
             */
            created?: number
            [k: string]: unknown
        }
    }
    /**
     * A file in this directory
     */
    files: {
        /**
         * Metadata of a file, can contain multiple versions
         *
         * This interface was referenced by `undefined`'s JSON-Schema definition
         * via the `patternProperty` "^.+$".
         */
        [k: string]: DirectoryFile
    }
    [k: string]: unknown
}

// To parse this data:
//
//   import { Convert, Post } from "./file";
//
//   const post = Convert.toPost(json);
//
// These functions will throw an error if the JSON doesn't
// match the expected interface, even if the JSON is valid.

/**
 * A representation of a post
 */
export interface Post {
    /**
     * Full ID of the post this posts is commenting on
     */
    commentTo?: string;
    content?: PostContent;
    /**
     * This ID MUST be unique on the page this post is on. For example, this post could have the
     * full id d448f1562c20dbafa42badd9f88560cd1adb2f177b30f0aa048cb243e55d37bd/feed/posts/1/5
     * (userId/structure/feedId/pageId/postId)
     */
    id: number;
    /**
     * If this post is deleted
     */
    isDeleted?: boolean;
    /**
     * User IDs of users being mentioned in this post (also used for comments)
     */
    mentions?: string[];
    /**
     * Multihash of the Canonical JSON (http://wiki.laptop.org/go/Canonical_JSON) string of the
     * post being reposted or commented on to prevent unexpected edits
     */
    parentHash?: string;
    /**
     * Full ID of the post being reposted (If this key is present, this post is a repost and
     * does not need to contain a "content")
     */
    repostOf?: string;

    /**
     * Unix timestamp (in millisecons) when this post was created/posted
     */
    ts: number;

    /**
     * Full reference to this post, only set when using loadPostsForUser()
     */
    ref?: string;
}

/**
 * The content of a post
 */
export interface PostContent {
    /**
     * Can be used by applications to add more metadata
     */
    ext?: { [key: string]: any };
    /**
     * List of media objects in a "gallery", can be show in a carousel or list
     * useful for app screenshots or galleries
     * NOT TO BE USED for something like music albums, because it prevents individual tracks
     * from being referenced, saved, rated, reposted...
     */
    gallery?: Media[];
    /**
     * Can be used as a link to a url referred by this post
     */
    link?: string;
    /**
     * title of the url, only used for preview
     */
    linkTitle?: string;
    /**
     * A media object can contain an image, video, audio or combination of all of them
     */
    media?: Media;
    /**
     * Used for polls
     */
    pollOptions?: { [key: string]: string };
    /**
     * Defines special attributes of this post which have a special meaning which can be
     * interpreted by the application showing this post
     */
    tags?: string[];
    /**
     * Text content of the post or description
     */
    text?: string;
    /**
     * The content type of text
     */
    textContentType?: string;
    /**
     * higlighted and used as title of the post when available
     */
    title?: string;
    /**
     * Can contain multiple topics (hashtags) this post fits into
     */
    topics?: string[];
}

/**
 * A media object (image, audio or video). More specific media formats should be listed
 * first
 *
 * A media object can contain an image, video, audio or combination of all of them
 */
export interface Media {
    /**
     * Aspect ratio of the image and/or video
     */
    aspectRatio?: number;
    audio?: Audio[];
    /**
     * BlurHash of the image shown while loading or not shown due to tags (spoiler or nsfw)
     */
    blurHash?: string;
    image?: Image[];
    /**
     * Duration of the audio or video in milliseconds
     */
    mediaDuration?: number;
    video?: Video[];
}

/**
 * An available media format listed in a media object
 */
export interface Audio {
    /**
     * file extension of this media format
     */
    ext: string;
    url: string;
    /**
     * quality of the audio in kbps
     */
    abr?: string;
    /**
     * audio codec used by this format
     */
    acodec?: string;
}

/**
 * An available media format listed in a media object
 */
export interface Image {
    /**
     * file extension of this media format
     */
    ext: string;
    url: string;
    /**
     * Height of the image
     */
    h: number;
    /**
     * Width of the image
     */
    w: number;
}

/**
 * An available media format listed in a media object
 */
export interface Video {
    /**
     * file extension of this media format
     */
    ext: string;
    url: string;
    /**
     * Frames per second of this format
     */
    fps?: number;
    /**
     * video codec used by this format
     */
    vcodec?: string;
}

// Converts JSON strings to/from your types
// and asserts the results of JSON.parse at runtime
export class Convert {
    public static toPost(json: string): Post {
        return cast(JSON.parse(json), r("Post"));
    }
    public static toPostContent(json: string): PostContent {
        return cast(JSON.parse(json), r("PostContent"));
    }

    public static postToJson(value: Post): string {
        return JSON.stringify(uncast(value, r("Post")), null, 2);
    }
}

function invalidValue(typ: any, val: any, key: any = ''): never {
    if (key) {
        throw Error(`Invalid value for key "${key}". Expected type ${JSON.stringify(typ)} but got ${JSON.stringify(val)}`);
    }
    throw Error(`Invalid value ${JSON.stringify(val)} for type ${JSON.stringify(typ)}`,);
}

function jsonToJSProps(typ: any): any {
    if (typ.jsonToJS === undefined) {
        const map: any = {};
        typ.props.forEach((p: any) => map[p.json] = { key: p.js, typ: p.typ });
        typ.jsonToJS = map;
    }
    return typ.jsonToJS;
}

function jsToJSONProps(typ: any): any {
    if (typ.jsToJSON === undefined) {
        const map: any = {};
        typ.props.forEach((p: any) => map[p.js] = { key: p.json, typ: p.typ });
        typ.jsToJSON = map;
    }
    return typ.jsToJSON;
}

function transform(val: any, typ: any, getProps: any, key: any = ''): any {
    function transformPrimitive(typ: string, val: any): any {
        if (typeof typ === typeof val) return val;
        return invalidValue(typ, val, key);
    }

    function transformUnion(typs: any[], val: any): any {
        // val must validate against one typ in typs
        const l = typs.length;
        for (let i = 0; i < l; i++) {
            const typ = typs[i];
            try {
                return transform(val, typ, getProps);
            } catch (_) { }
        }
        return invalidValue(typs, val);
    }

    function transformEnum(cases: string[], val: any): any {
        if (cases.indexOf(val) !== -1) return val;
        return invalidValue(cases, val);
    }

    function transformArray(typ: any, val: any): any {
        // val must be an array with no invalid elements
        if (!Array.isArray(val)) return invalidValue("array", val);
        return val.map(el => transform(el, typ, getProps));
    }

    function transformDate(val: any): any {
        if (val === null) {
            return null;
        }
        const d = new Date(val);
        if (isNaN(d.valueOf())) {
            return invalidValue("Date", val);
        }
        return d;
    }

    function transformObject(props: { [k: string]: any }, additional: any, val: any): any {
        if (val === null || typeof val !== "object" || Array.isArray(val)) {
            return invalidValue("object", val);
        }
        const result: any = {};
        Object.getOwnPropertyNames(props).forEach(key => {
            const prop = props[key];
            const v = Object.prototype.hasOwnProperty.call(val, key) ? val[key] : undefined;
            result[prop.key] = transform(v, prop.typ, getProps, prop.key);
        });
        Object.getOwnPropertyNames(val).forEach(key => {
            if (!Object.prototype.hasOwnProperty.call(props, key)) {
                result[key] = transform(val[key], additional, getProps, key);
            }
        });
        return result;
    }

    if (typ === "any") return val;
    if (typ === null) {
        if (val === null) return val;
        return invalidValue(typ, val);
    }
    if (typ === false) return invalidValue(typ, val);
    while (typeof typ === "object" && typ.ref !== undefined) {
        typ = typeMap[typ.ref];
    }
    if (Array.isArray(typ)) return transformEnum(typ, val);
    if (typeof typ === "object") {
        return typ.hasOwnProperty("unionMembers") ? transformUnion(typ.unionMembers, val)
            : typ.hasOwnProperty("arrayItems") ? transformArray(typ.arrayItems, val)
                : typ.hasOwnProperty("props") ? transformObject(getProps(typ), typ.additional, val)
                    : invalidValue(typ, val);
    }
    // Numbers can be parsed by Date but shouldn't be.
    if (typ === Date && typeof val !== "number") return transformDate(val);
    return transformPrimitive(typ, val);
}

function cast<T>(val: any, typ: any): T {
    return transform(val, typ, jsonToJSProps);
}

function uncast<T>(val: T, typ: any): any {
    return transform(val, typ, jsToJSONProps);
}

function a(typ: any) {
    return { arrayItems: typ };
}

function u(...typs: any[]) {
    return { unionMembers: typs };
}

function o(props: any[], additional: any) {
    return { props, additional };
}

function m(additional: any) {
    return { props: [], additional };
}

function r(name: string) {
    return { ref: name };
}

const typeMap: any = {
    "Post": o([
        { json: "commentTo", js: "commentTo", typ: u(undefined, "") },
        { json: "content", js: "content", typ: u(undefined, r("PostContent")) },
        { json: "id", js: "id", typ: 0 },
        { json: "isDeleted", js: "isDeleted", typ: u(undefined, true) },
        { json: "mentions", js: "mentions", typ: u(undefined, a("")) },
        { json: "parentHash", js: "parentHash", typ: u(undefined, "") },
        { json: "repostOf", js: "repostOf", typ: u(undefined, "") },
        { json: "ts", js: "ts", typ: u(undefined, 0) },
    ], "any"),
    "PostContent": o([
        { json: "ext", js: "ext", typ: u(undefined, m("any")) },
        { json: "gallery", js: "gallery", typ: u(undefined, a(r("Media"))) },
        { json: "link", js: "link", typ: u(undefined, "") },
        { json: "linkTitle", js: "linkTitle", typ: u(undefined, "") },
        { json: "media", js: "media", typ: u(undefined, r("Media")) },
        { json: "pollOptions", js: "pollOptions", typ: u(undefined, m("")) },
        { json: "tags", js: "tags", typ: u(undefined, a("")) },
        { json: "text", js: "text", typ: u(undefined, "") },
        { json: "textContentType", js: "textContentType", typ: u(undefined, "") },
        { json: "title", js: "title", typ: u(undefined, "") },
        { json: "topics", js: "topics", typ: u(undefined, a("")) },
    ], "any"),
    "Media": o([
        { json: "aspectRatio", js: "aspectRatio", typ: u(undefined, 3.14) },
        { json: "audio", js: "audio", typ: u(undefined, a(r("Audio"))) },
        { json: "blurHash", js: "blurHash", typ: u(undefined, "") },
        { json: "image", js: "image", typ: u(undefined, a(r("Image"))) },
        { json: "mediaDuration", js: "mediaDuration", typ: u(undefined, 0) },
        { json: "video", js: "video", typ: u(undefined, a(r("Video"))) },
    ], "any"),
    "Audio": o([
        { json: "ext", js: "ext", typ: "" },
        { json: "url", js: "url", typ: "" },
        { json: "abr", js: "abr", typ: u(undefined, "") },
        { json: "acodec", js: "acodec", typ: u(undefined, "") },
    ], "any"),
    "Image": o([
        { json: "ext", js: "ext", typ: "" },
        { json: "url", js: "url", typ: "" },
        { json: "h", js: "h", typ: 0 },
        { json: "w", js: "w", typ: 0 },
    ], "any"),
    "Video": o([
        { json: "ext", js: "ext", typ: "" },
        { json: "url", js: "url", typ: "" },
        { json: "fps", js: "fps", typ: u(undefined, 3.14) },
        { json: "vcodec", js: "vcodec", typ: u(undefined, "") },
    ], "any"),
};
