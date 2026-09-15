# Sample Search

(Formerly *Trigger Search*. Existing metadata, settings and the Trigger browser folder location are
carried over automatically on first launch.)

A small native macOS app for browsing a library of Slate **Trigger 2** `.tci` instrument files and
plain `.wav` / `.aiff` one-shots and effects. It replaces Trigger's folder-only browser with search,
tags and favourites, and feeds them back to Trigger 2 through a folder its own browser can navigate.

## Features

- **Modes** in the toolbar: *Instruments* (`.tci`), *One-Shots* (`.wav`, `.aif`, `.aiff`), *All Trigger*
  (both) and *Effects*, a completely separate library of `.wav` / `.aiff`
  sound effects (risers, downlifters, impacts, hits, cymbals, whooshes, drones, reverses) scanned from its
  own folders, classified by type from names, and never written to the Trigger browser folder.
  Effects share tags, favourites, notes, packs, kits, vendors, preview and search with the rest.
  The mode is remembered between launches.
- **One-shot preview**: play button on each row and in the inspector, Space to play the selection,
  ⌘. to stop, and an optional "Play on Select" toggle for quick auditioning. The inspector shows
  duration, sample rate, channels and bit depth. (`.tci` files cannot be played outside Trigger.)
- **Scans any folders you choose** for those files (iCloud Drive folders work). "Find TCI Files
  Automatically" uses Spotlight to suggest folders across the whole Mac.
- **Auto-metadata from names**: category (kick / snare / tom / hi-hat / cymbal / percussion),
  source (Direct / Overheads / Rooms / FX, from tokens such as `OH`, `RM`, `Room`, `Amb`, `FX`;
  Direct by default), pack, sub-folder, and variant suffix such as `SSDR`, `NRG`, `Z1`, `Z3`.
  Category and source can be overridden per file. The pack is the first folder under a library root, unless
  that folder is really a category ("Trigger2 Snares", "01a Kick"), in which case the root is the pack.
  Inside a pack, the next folder is a **kit** unless it is a category folder, so Vendor One's
  "Kit C" / "Kit D" show as kits nested under the pack in the sidebar. Wrapper folders such
  as "TCI" or "Samples" are ignored. Pack names can be renamed in the inspector or by
  right-clicking them in the sidebar; the name applies to every file in that folder.
- **Kits are also assignable by hand**: select any files (across folders), type a kit name in the
  inspector or click an existing kit chip, and they group under that kit in the sidebar. Useful for
  libraries like the stock Trigger 2 one where every kit lives in one folder.
- **Vendor column**: guessed from folder names (Steven Slate Drums, MixWave, Vendor One, Vendor Two,
  GetGood Drums, Toontrack, XLN, and "Vendor - Product" style pack names). Type a vendor in the
  inspector to set it for the whole pack. The sidebar has a Vendors section.
- **Search** across name, folder, pack, kit, vendor, category, source, variant, tags and notes. Every
  word must match. A search covers everything in the current mode and ignores the sidebar selection.
  If the current library has no matches it falls through in order: Instruments → One-Shots → Effects
  (One-Shots → Instruments → Effects; All Trigger → Effects; Effects → All Trigger), with a banner
  saying where the results came from and a button to switch there. Clicking a sidebar item clears
  the search.
- **Tags** with quick-add suggestions from tags you already use. Select several rows to tag them at once.
  Rename or delete a tag from its sidebar context menu.
- **Notes**: free text per sample in the inspector, saved as you type, shown in a Notes column and
  included in search. Notes are not exported to the browser folder.
- **Favourites** (star column, ⌘D, or the inspector button).
- **Drag and drop for one-shots and effects**: drag WAV/AIFF rows, or the drag tile in the inspector,
  onto a DAW track or sampler. Nothing is ever moved or renamed. Trigger 2 does not accept file drops
  at all (Logic never delivers them to the plugin window), so `.tci` files have no drag tile; use the
  browser folder below instead.
- **Trigger browser folder** (File › Update Trigger Browser Folder, ⌘E): writes a folder of symlinks
  (default `~/Music/Sample Search`) organised as `Favourites/`, `Tags/<tag>/`, `Kits/<pack>/<kit>/`,
  `Categories/<category>/<source>/`, `Sources/<source>/` and `Vendors/<vendor>/<pack>/<kit>/`.
  The files currently selected in the app are also linked directly at the top level of that folder,
  updated a moment after the selection changes. With nothing selected, the whole group the sidebar
  or search is showing (a pack, kit, tag, category, search hits… but not "All Samples") is mirrored
  instead, capped at 2000 links. Switch off in the Folders sheet. Point Trigger 2's built-in browser at it and your tags and kits are
  navigable inside the plugin. Useful in hosts such as Logic (AU), where file drops never reach the
  plugin window. The folder is rebuilt automatically a couple of seconds after any tag, favourite,
  kit, pack or vendor change and after each rescan (switch this off in the Folders sheet). It is
  rebuilt from scratch each time and is only ever cleared if it contains the marker file the app wrote.
- **Copy Path** (⌘C) for pasting into Trigger's open dialog with ⇧⌘G, and **Reveal in Finder** (⇧⌘R). Metadata follows a file that you move to a different folder, as long
  as its name and size still match.

Tags, favourites and the folder list are stored in
`~/Library/Application Support/Sample Search/library.json`.

## Build

Requires Xcode 15+ / Swift 5.9+ and macOS 14+.

```sh
./scripts/make-app.sh            # builds build/Sample Search.app
./scripts/make-app.sh --install  # …and copies it to /Applications (quits the running copy first)
swift test                       # classifier, scanner, exporter and metadata-migration tests
swift scripts/make-icon.swift Resources && iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns  # regenerate the icon
```

## Updates and releases

Sample Search › Check for Updates… compares the app's version with the latest release on
GitHub and offers the download. It also checks quietly once a day at launch (toggle in the Folders
sheet). To publish a release:

```sh
echo 0.3.0 > VERSION            # bump
./scripts/make-release.sh       # builds, zips build/Sample-Search-0.3.0.zip, tags v0.3.0
git push origin main v0.3.0
```

Then create the GitHub release for that tag and attach the zip. If the repository is private, enter
a GitHub token (fine-grained, read access to Contents; or classic with `repo`) in the Folders sheet
under GitHub; it is stored in the Keychain and sent only to api.github.com. Downloads open in the
browser, where your GitHub login applies. The app is ad-hoc signed, so on
first launch of a downloaded copy right-click › Open (or `xattr -dr com.apple.quarantine`).

## Window

Table columns can be reordered by dragging their headers and shown or hidden from the header's
right-click menu; order, visibility and widths are remembered. Name and the favourite star stay put.

First launch opens at 1280×780 (minimum 900×500) with the sidebar at ~220pt and the inspector at
~300pt. The window's size and position are saved on close and restored on the next launch. Drag the
column dividers to resize the sidebar or inspector. The toolbar's sidebar button (⌃⌘S) hides the
sidebar and the inspector button (⌥⌘I) hides the inspector; both states are remembered.

## Layout

- `Sources/SampleSearchKit` – models, filename classifier, scanner, JSON store, Spotlight discovery.
- `Sources/SampleSearch` – SwiftUI app: sidebar, sortable table, inspector, tag editor, AppKit drag source.
- `Tests/SampleSearchKitTests` – unit tests (one test scans your real library when present).

## Notes

- The `.tci` format carries no readable metadata (just a `TRIGGER COMPRESSED INSTRUMENT 2` header and
  compressed audio), so all automatic classification comes from file and folder names.
- macOS will ask once for permission to read iCloud Drive / Downloads / Documents; grant it or the scan
  finds nothing.
