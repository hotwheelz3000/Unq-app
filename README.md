# Unq

An iPhone app for [unqx.site/sclib](https://unqx.site/sclib/), the unqforge Shortcut builder. Unofficial; not made by or affiliated with the site.

- **Full-screen site:** the builder in an app instead of a Safari tab. Pull down to reload.
- **Paste button:** one tap replaces the code in the editor with what you copied (no Select All, then Paste).
- **Signed shortcuts open in Shortcuts:** tapping "Sign & download .shortcut" saves the file and opens the share sheet, so you can pick Shortcuts straight away.
- Links to other sites open in Safari.

## Download

Every push to `main` builds an unsigned IPA and publishes it as the `latest` release. The release notes have the direct link. Sign it when installing (Signulous, Sideloadly, AltStore).

## Build

Built with [xtool](https://xtool.sh) on GitHub Actions (`.github/workflows/build-ipa.yml`). The app's text is in `Sources/Unq/Resources/en.lproj/Localizable.strings`. The script that finds the editor and pastes into it is `Sources/Unq/PasteScript.swift`.

Made from the template hotwheelz3000/my-ios-app-template.
