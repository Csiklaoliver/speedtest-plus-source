# Device review checklist

This checklist is written for the friend reviewing on a real iPhone because the
current development machine cannot run or sign the iOS build.

## Launch safety

- Cold launch reaches the official onboarding or main Speed screen.
- Returning-user launch reaches GO without a crash.
- Map, Video, Downdetector, and official onboarding still open normally.
- Selecting another test server still works and the following test connects.

## Original gauge behavior

- Pressing GO starts the original opening animation.
- The blue arc opens first and the gray trailing bar follows it.
- The gauge begins in its original vertical position with no large empty chin.
- The number starts at zero, rises continuously, and never alternates between 1
  and the entered value.
- Near the target, small rises and drops remain visible.
- The last value equals the finalized result exactly.
- The original 1k gauge labels and scale remain unchanged.

## Controls

- Blank fields preserve real values.
- Equal minimum and maximum produces the exact entered speed.
- A range chooses one target per test and does not change that target while saving.
- Large finite speeds work up to the accepted raw integer limit.
- Invalid, negative, reversed, or non-finite values show a specific message.
- Ping and jitter accept only whole values from 0 to 9999.
- Packet loss works at 0.0, 99.9, and 100.0.
- ISP, server provider, and location trim whitespace and enforce 64 characters.
- Disable All restores measured presentation without deleting profiles or theme.

## Profiles and access

- Save, load, overwrite confirmation, and delete confirmation work in all 3 slots.
- Loading fills the fields but does not activate them until Apply.
- The active badge is hidden with zero overrides.
- The badge count matches the eight override categories.
- Hiding the panel removes the visible S+ button.
- Long-press opens the unlock prompt and a valid password opens controls.
- The guide appears once and can be reopened from the info button.

## Results

- Final Speed screen labels match the last live values.
- Local result details match download, upload, ping, jitter, loss, ISP, provider,
  and location.
- Compare Your Speed shows the same user values without clipping.
- Feedback asks about the custom ISP when one is active.
- Local text sharing contains no public Speedtest URL.
- CSV retains original columns and appends the four Speedtest+ columns.
- Old saved results are unchanged.
- The official remote result is still measured and is not modified by Speedtest+.

## Themes and updates

- All ten themes are readable in portrait and landscape on iPhone SE-size,
  standard, Plus/Max, and iPad layouts.
- Map, Video, Downdetector, ads outside the Speed screen, and splash stay stable.
- Theme selection survives process termination.
- Update checks do nothing when no `ios` manifest entry exists.
- A newer iOS entry displays one prompt and opens the signed download page.
- Disabling checks persists.

## Reviewer notes to return

Please include the device model, iOS version, signing method, app version, exact
steps, a screen recording, and any crash log from Settings > Privacy & Security >
Analytics & Improvements > Analytics Data.

