# Brief: the game's screens on the UI style and motion system

DRAFT, 2026-10-30, for the owner's approval before code. Step 2 of the order
of work in [the vision](../VISION.md). The style, icons, motion verbs and
typeface are approved; this brief moves the game onto them.

## The fantasy

The interface is almost absent. The world is the menu. A control shows only
when it can be used and is needed, and it arrives and leaves with the motion
verbs, never in a cut.

## Why it sparks joy

The first thing a player sees is a place, not a form. Every screen moves
with one calm rhythm, so the game feels made by one hand.

## What changes, screen by screen

| Screen | Today | After |
| --- | --- | --- |
| Title | A pale veil, "Mirror", Tap to begin / Continue / New game buttons | The first stage seen from far above, drifting slowly; "Mirror" in the sky. No buttons: after a moment a small light breathes where to tap. A tap anywhere sinks the camera into the stage (transition). With a save, the tap continues; "Start again" moves to settings. |
| Play | Four button styles, words ("Undo") | Frost icon buttons only, shown by the rules below. |
| Prompt card | Ivory text box | The frost panel in Spectral; appears and leaves with the verbs. Its wording is unchanged until the slice replaces prompts with the world. |
| Hints (refusals, "no path") | Ivory text box | The same frost, smaller. The slice later replaces them with world feedback. |
| Stage title | A hint box | Written on the world: chapter type, centred, appears, holds, leaves. |
| Settings | Plain panel with words | The frost panel: Music, Effects, Fullscreen (desktop), then Restart stage, Start again and Return to title as icon-and-word rows. Words stay here only. |
| End | Text card with two buttons | "The tutorial is complete." in chapter type on the world; Play again and Title as icon-and-word rows. |

## When each control shows (UI used sparingly)

- **Mirror** (primary, bottom right): on stages that have a mirror; hidden
  during the sweep and the title.
- **Undo** (beside it): appears after the first action that can be undone;
  leaves when nothing is left to undo.
- **Turn the view** (bottom left): desktop only; touch swipes. Rests faint
  and wakes on hover.
- **Settings** (top right): always there, faint until hovered or touched.
- **Help** (beside settings): only on stages that have prompts, as today.

## Motion

Every tween goes through `Motion`. About twenty today; the main ones:

| Today | Verb |
| --- | --- |
| Camera view turn, 0.4 s | reveal, 0.8 s (the feel section asks for about 0.7 s) |
| Camera fit, 0.28 s | settle, 0.34 s |
| Mirror turn, 0.22 s | settle |
| Prompt fade, 0.35 s | appear and dismiss |
| Unreachable mark, hover path, outlines | appear and dismiss |
| Title to play | transition, 1.6 s |

Gameplay timings (the 1.2 s refused-fall hold, the rewind after a fall) stay
as they are; they are rules, not motion.

## Links to other systems

Tests that find buttons by name or wait for fixed times will need small
updates: `app_flow_tests`, `prompt_tests`, `direct_controls_tests`,
`small_fix_tests`, `step_tests`, and the tutorial playthrough.

## Not in this brief

World art, snow, sound and music, the story, and the prompts' wording.

## Review

Stills of every screen at 1152×800, 844×390 and 390×844; one Movie Maker
clip from the title into the first stage and through one stage change; the
owner plays it on a Mac. Then the checks above, once.
