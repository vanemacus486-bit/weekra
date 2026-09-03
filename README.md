# Weekra

Weekra is a calm, week-first calendar built with Flutter.

## MVP

The first version focuses on one job: letting people understand and edit their
week quickly.

- Seven-day week view
- Vertical time axis
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

## Current progress

The first UI slice is in place:

- Timepage-inspired continuous week agenda on phones
- Seven-column hourly grid on wider screens
- Current-day and current-time emphasis
- Previous/next week navigation, including horizontal swipe
- Responsive event blocks backed by a small domain model

Event creation currently opens a preview sheet. Editing and local persistence
are the next MVP slice.

## Design reference

Timepage is used as a product and interaction reference. Weekra will use its
own brand, visual assets, copy, and implementation.
