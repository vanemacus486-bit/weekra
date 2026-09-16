# Glass and update correction

## References inspected

- Flutter's BSD-licensed Cupertino sliding segmented control:
  https://github.com/flutter/flutter/blob/stable/packages/flutter/lib/src/cupertino/sliding_segmented_control.dart
  Its persistent thumb, spring motion and direct manipulation informed the
  interaction. Weekra keeps the current spring velocity when retargeting.
- https://github.com/whynotmake-it/flutter_liquid_glass
- https://github.com/sdegenaar/liquid_glass_widgets/blob/main/docs/PLATFORM_SUPPORT.md
  Windows uses Skia; that project's premium backdrop refraction is unavailable
  there. Weekra uses clipped backdrop blur, layered tint/specular gradients, a
  dual directional rim, and restrained pointer-responsive light with no shader
  dependency. This is responsive frosted glass, not a claim of pixel-identical
  Liquid Glass refraction. Whole-calendar lateral motion has been removed.

## Behavior

The timeline always contains 00:00–24:00. It initially scrolls to 07:00 and
preserves the scroll position across mode changes. A 23:45 selection can end at
midnight. Scroll upwards for early hours; downwards for late hours.

Settings is a centered, bounded, scrollable glass card. Event creation uses a
compact card near the selected time on desktop and a centered card otherwise.
Click/drag empty hourly space, tap a date row in Overview, or use Ctrl/Cmd+N.
There is no permanent floating add button.

Interactive controls expose their state before an action occurs: pointer hover
adds a rounded surface and stronger foreground, while press adds a darker state
and a short compression/release. Ripple splashes are intentionally disabled so
the response stays anchored to the control. Press motion becomes instantaneous
when the operating system requests reduced animation.

Glass light starts at the upper-left edge and follows the pointer within the
surface on compact desktop controls. Dialog-sized surfaces keep the same base
tint, transmission, rim, and shadow layers but use static lighting so mouse
movement cannot continuously rebuild an editor while the user is typing. Touch
platforms retain the validated static frosted profile instead of paying for
pointer-only lighting. The selected segmented thumb stays brighter but does not
run a second pointer response inside its parent. When reduced motion is enabled,
light and shadow changes settle immediately.

## Update delivery

The runtime fallback version must match pubspec.yaml (enforced by a test).
Windows Release rejects existing or older stable version numbers rather than
overwriting an existing version's binaries. Releases are pinned to the exact
build commit. Increase both version declarations for every release.

Checks run after launch, every six hours, on resume after ten minutes, and via
Settings. Failures are visible and retryable; Settings shows the current version
and latest check status. The Windows client reads the per-user system proxy that
browsers and desktop proxy clients use, while preserving environment-proxy and
direct fallbacks. Manifest and installer requests retry transient connection
failures. Downloads time out if the connection stops transmitting and still
require the release SHA-256 digest before installation. Check, download, and
installer results are appended to
`%LOCALAPPDATA%\Weekra\Logs\update.log` without relying on a Flutter plugin.

The detached PowerShell installer receives Weekra's process ID explicitly and
must create a ready marker before Weekra exits. That handshake prevents the app
from closing before the detached installer has actually taken ownership of the
update. The helper then waits for Weekra's process before replacing files. Do
not use PowerShell's `$PID`
for this wait: variable names are case-insensitive and `$PID` always identifies
the PowerShell host itself, which would deadlock the update indefinitely.

Updater pull requests run a Windows end-to-end job in addition to unit tests.
The job launches a deliberately old client, consumes the public release
manifest, downloads and verifies the installer, waits for process handoff,
checks that the executable changed, and confirms that Weekra restarted.

A functioning GitHub connection is required for this release channel. This does
not bypass network restrictions or retrofit an updater into a binary that never
contained one. Windows replacement/relaunch needs Windows validation; Linux
widget tests alone cannot establish that it works end to end.
