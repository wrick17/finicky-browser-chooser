# Finicky Browser Chooser

A small macOS helper for [Finicky](https://github.com/johnste/finicky). When Finicky sends it a link, it shows a native panel asking whether to open the link in Island or Helium. The panel appears on the screen and Space you are using, including a fullscreen app, without switching Spaces. Finicky itself stays the stock app; this helper is installed next to it.

- Arrow keys move between choices, Return opens the selected browser, and Escape or Cancel opens nothing.
- The panel shows only the link's hostname, never the full URL.
- Several links queue one panel at a time, and each answer applies only to its own link.
- The chosen browser opens the original link and comes to the front.
- The helper has no Dock icon and quits a few seconds after its last panel closes.

Requirements: macOS 13 or later on Apple silicon, and Finicky 4.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/wrick17/finicky-browser-chooser/main/scripts/install.sh | bash
```

The installer downloads `FinickyBrowserChooser-arm64.tar.gz` and `SHA256SUMS` from the [latest release](https://github.com/wrick17/finicky-browser-chooser/releases) and checks the checksum, bundle ID, architecture, archive layout, and code signature before changing anything. It then installs `~/Applications/Finicky Browser Chooser.app`.

- An existing copy of the helper is replaced, and the old one is kept as `Finicky Browser Chooser.app.backup-<time>` next to it. The installer prints the rollback command.
- It does not use `sudo`, and it does not touch Finicky, `~/.finicky.js`, or your default browser.
- Set `CHOOSER_VERSION=<tag>` to pin a release. See the top of the script for other options.

Release builds are ad-hoc signed and not notarized. `curl` does not mark downloads as quarantined, so macOS does not show a Gatekeeper prompt for the installed app; you are trusting this repository's release.

## Configure Finicky

Add this handler first in `~/.finicky.js`:

```js
{
  match: ["claude.ai/*", "claude.com/*"],
  browser: {
    name: "io.github.wrick17.finicky-browser-chooser",
    appType: "bundleId",
    // Keep the helper in the background so macOS does not switch Spaces.
    openInBackground: true,
  },
},
```

## Try the panel without opening links

```sh
"$HOME/Applications/Finicky Browser Chooser.app/Contents/MacOS/FinickyBrowserChooser" --chooser-test
```

It shows two sample panels (`first.example.test`, `second.example.test`), prints each answer, and exits. It opens no links or browsers.

## Build from source

```sh
scripts/build.sh
```

This builds an ad-hoc signed `build/Finicky Browser Chooser.app` for arm64 with `clang`. It needs only the Xcode command line tools.

## License

[MIT](LICENSE)
