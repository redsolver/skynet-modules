## Introducing the Permission DAC

Right now all DAC/module APIs can be called by any skapp or module without any permissions. This is an issue for (public) shared data like social graphs, profiles and feeds. So I just created a new Permission DAC that takes care of this! The new permissions are not enforced yet until all projects using the modules have been migrated. Permissions are not synced across multiple devices, they are local for now.

**How to request permissions**
1. Make sure you are using `skynet-dacs-library` version `0.1.9` or later.

you can now use the Permission DAC to check if all permissions your app needs have been granted and open a permission popup if not like this:

```ts
const permissionDAC = new PermissionDAC();

let ungrantedPermissions = await permissionDAC.checkPermissions([
  "social-dac.hns/relation/following/create",
  "social-dac.hns/relation/following/delete",
  "feed-dac.hns/post/create/feed/posts",
  "feed-dac.hns/post/create/feed/comments",
  "query-dac.hns/enable",
  "profile-dac.hns/profile/update",
]);

if (ungrantedPermissions.length > 0) {
  let req = {
    domain: "localhost", // your app domain
    permissions: ungrantedPermissions,
  };
  const w = 640;
  const h = 750;
  const y = window.top.outerHeight / 2 + window.top.screenY - h / 2;
  const x = window.top.outerWidth / 2 + window.top.screenX - w / 2;
  const newWindow = window.open(
    "https://auth.solver.red/#" +
      btoa(JSON.stringify(req)).replace("/", "_").replace("+", "-"),
    "Grant permissions",
    `toolbar=no, location=no, directories=no, status=no, menubar=no, scrollbars=yes, copyhistory=no, width=${w}, height=${h}, top=${y}, left=${x}`
  );
  if (newWindow.focus) {
    newWindow.focus();
  }
}
```

This snippet also contains a list of all available permissions right now. Some of them are dynamic, for example a custom feed for the Feed DAC would look like this: `feed-dac.hns/post/create/feed/customfeedname`. Keep in mind that most browsers require a user interaction like clicking a button before you are allowed to open a popup.