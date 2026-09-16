# Weekra

Weekra is a calm, week-first calendar built with Flutter.

## MVP

The first version focuses on one job: letting people understand and edit their
week quickly.

- Overview day stream and seven-column Hourly layouts
- Mobile and desktop layout switcher
- Create, edit, move, and delete events
- Navigate across days and return to today
- Local-first persistence
- Android and Windows targets

See [docs/MVP.md](docs/MVP.md) for the product boundary.

## Development

Flutter is required. After cloning the repository, generate the platform
runners if they are not present:

```bash
flutter create . --platforms=android,windows
flutter pub get
flutter run
```

## Install on Windows

Download `weekra-setup-x64.exe` from the latest GitHub Release and run it.
The installer places the production app in the current user's local Programs
folder, adds Start menu integration, and optionally creates a desktop shortcut.
Flutter is not required on the user's computer.

Weekra checks for updates shortly after launch, every six hours, and when
resumed. Settings shows the installed version and provides a manual check with
visible connection errors. On Windows the updater honors the same per-user
system proxy used by browsers and desktop proxy clients, retries interrupted
requests, and records persistent diagnostics. When a newer version is
available, it downloads the installer, verifies its SHA-256 digest, installs
it, and restarts automatically after the user confirms. Calendar data stays in
the user's documents directory during updates.

An unsigned portable build, `weekra-windows-x64.zip`, is also attached to each
release. Extract the complete folder before opening `weekra.exe`.

## Publish a Windows update

1. Increase `version` in `pubspec.yaml` and `appVersion` in `lib/app/app_version.dart`. Existing release versions cannot be reused.
2. Push the change to `main`, or run the `Windows Release` workflow manually.
3. Wait for the workflow to test, build, package, and publish the GitHub Release.

The release contains the installer, portable app, and `update.json` manifest.
Because the app reads the latest release automatically, no update URL needs to
be edited for future versions. The repository and its Releases must be public
unless a separate public update host is configured at build time with
`WEEKRA_UPDATE_MANIFEST_URL`.

Pull requests that change the updater run a real Windows upgrade smoke test. It
builds a deliberately old client, downloads the current public release,
verifies and installs it, then confirms that the executable was replaced and
Weekra restarted. This test is separate from unit tests that inspect the helper
script.

## Current progress

The first UI slice is in place:

- Timepage-inspired Overview stream and seven-column Hourly layouts
- Overview / Hourly switching on phones, tablets, and desktops
- The Overview runs continuously by day, opening on today and extending past
  either end as you keep scrolling
- A compact day strip with its own surface separates the weekday and date from
  the event area, and day boundaries are drawn as notebook-style rules
- Full 00:00–24:00 timeline fitted into the available viewport without scrolling
- Two-hour focus lens with 15-minute guides for precise local editing
- Current-day and current-time emphasis
- Previous/next week navigation, including horizontal swipe
- Responsive event blocks backed by a small domain model
- Timepage-style direct manipulation in Hourly view: click for a one-hour event
  aligned to the containing hour, or drag with 15-minute precision; press and
  drag the event body to move, or hover and pull either edge to resize
- Draft creation keeps the 24-hour timeline at its current scale, reuses cached
  event placement, and treats the first surrounding click as cancel instead of
  creating a second event
- Compact right-click menu for editing, copying, deleting, or recategorizing
  an event without opening its details first
- A visible 24:00 label and bottom rule keep the full-day boundary explicit
- Compact glass event editor with date, time, category, and optional location
- Offline JSON persistence in the app documents directory
- Event detail, editing, and confirmed deletion flows
- System-driven English and Simplified Chinese UI
- Centered glass settings card with instant calendar anchoring, category
  names/colors, theme/language changes, and update status
- Rounded hover surfaces, distinct pressed colors, and restrained press motion
  across toolbar, dialog, and settings controls
- Layered glass surfaces with lighter tinting, dual-edge definition, and a
  restrained highlight that follows the pointer on compact desktop controls;
  dialog-sized glass stays static to avoid high-frequency repainting
- Pseudo-localization plus small-screen and large-type layout tests

Direct event manipulation uses 15-minute snapping, tactile feedback, and live
previews. Short events keep their true visual duration while retaining a larger
transparent pointer target, so the week stays accurate without becoming hard to
edit.

## Internationalization

Weekra generates its localized resources from ARB files in `lib/l10n`.
English is the source locale, Simplified Chinese is supported in production,
and `en_XA` is an intentionally expanded pseudo-locale used by widget tests.

```bash
flutter gen-l10n
flutter test
```

See [docs/I18N.md](docs/I18N.md) for the UI contract every new screen must
follow.

The legacy six-color event format is documented in
[docs/CATEGORIES.md](docs/CATEGORIES.md), including its stable-ID migration and
the category names that still need product confirmation.

## Design reference

Timepage is used as a product and interaction reference. Weekra will use its
own brand, visual assets, copy, and implementation.

See [the glass and update correction notes](docs/GLASS_AND_UPDATES.md) for references, platform limits and validation scope.
