# Weekra

Weekra is a calm, week-first calendar built with Flutter.

## MVP

The first version focuses on one job: letting people understand and edit their
week quickly.

- Seven-day Grid summary and Hourly layouts
- Mobile and desktop layout switcher
- Create, edit, move, and delete events
- Navigate between weeks and return to today
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

Weekra checks for updates shortly after launch. When a newer version is
available, it downloads the portable release, verifies its SHA-256 digest,
installs it, and restarts automatically after the user confirms. Calendar data
stays in the user's documents directory during updates.

An unsigned portable build, `weekra-windows-x64.zip`, is also attached to each
release. Extract the complete folder before opening `weekra.exe`.

## Publish a Windows update

1. Increase `version` in `pubspec.yaml`.
2. Push the change to `main`, or run the `Windows Release` workflow manually.
3. Wait for the workflow to test, build, package, and publish the GitHub Release.

The release contains the installer, portable app, and `update.json` manifest.
Because the app reads the latest release automatically, no update URL needs to
be edited for future versions. The repository and its Releases must be public
unless a separate public update host is configured at build time with
`WEEKRA_UPDATE_MANIFEST_URL`.

## Current progress

The first UI slice is in place:

- Timepage-inspired Grid summary and seven-column Hourly layouts
- Hourly / Grid switching on phones, tablets, and desktops
- Narrow-screen hourly density with adaptive event and time ranges
- Current-day and current-time emphasis
- Previous/next week navigation, including horizontal swipe
- Responsive event blocks backed by a small domain model
- Working event form with date, time, location, and color
- Offline JSON persistence in the app documents directory
- Event detail, editing, and confirmed deletion flows
- System-driven English and Simplified Chinese UI
- Pseudo-localization plus small-screen and large-type layout tests

Drag-to-create and drag-to-reschedule interactions are the next MVP slice.

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

## Design reference

Timepage is used as a product and interaction reference. Weekra will use its
own brand, visual assets, copy, and implementation.
