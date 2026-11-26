# Vision: what Mirror should feel like

A living draft, built from interviews with the owner. Every agent reads it
before design or build work. It says what the game is for the player. The
rules live in `GAME_DESIGN.md`; when the two disagree, raise it with the
owner before changing either.

## The feeling: light after rain

DECIDED (2026-10-30). The one feeling the whole game aims at: mysterious,
holy, hopeful, sad, grieving, like light after rain. The owner's touchstones
are three pieces from the Nier Automata soundtrack: "City Ruins - Rays of
Light", "Copied City" and "Weight of the World". The owner calls this the
most important feeling and the closest description of the game. Test every
screen, sound and story beat against it.

Each item is marked **DECIDED** (with the date), **DRAFT** (proposed, not yet
agreed) or **OPEN** (not yet discussed). Only the owner decides.

## Fantasy

- DECIDED (2026-10-30): an emotional puzzle game about mirrors and
  reflections. Through the mirror the player uses another dimension to make
  paths and solutions that seem not to be there. Solving the puzzles uncovers
  the tragic past of the main character, helps her reach the end, and is
  about putting down: loss and acceptance. ("Her" is a girl; see below.)
- DECIDED (2026-10-30): the line to a friend: "If you love Monument Valley,
  you will love this."

## Her

- DECIDED (2026-10-30): the twins are always side by side, but a little
  different: one is right-handed and one left-handed, fitting the mirror.
- DECIDED (2026-10-30): pictured like the little girl in Deemo. The small
  hooded traveller in the game is the owner's version of her for this game.
- DECIDED (2026-10-30): her model may change to fit the story (a small girl
  in winter, the left mitten). A Gemini Flash mockup round comes first; the
  owner picks before any Blender work.
- DECIDED (2026-10-31): her look is round 2's variant 2
  (`docs/art/her/beanie_b.jpg`): a dark bob with a fringe, a cream knitted
  beanie with a pompom, a mist-blue duffle coat with toggles and a hood
  down, grey tights, dark boots, and one red-ochre mitten on her LEFT hand
  (the drawing puts it on the right). Her twin is the mirror image: mitten
  on the right hand, parting on the right.
- AGENT DECISION (2026-10-31, under the owner's delegation): she is
  modelled and animated in Blender (`art_sources/girl/`) and replaces the
  traveller in the game; her walk is a careful 1.1 u/s.
- DRAFT (2026-10-30): alone on screen, like Ida; a second figure is optional.
- OPEN: whether the sister appears in reflections or as a figure on the copy
  side; it depends on the story. The prologue's glimpse (grey box,
  2026-10-31) shows her as a pale reflection behind a frost pane.
- AGENT DECISION (2026-10-31, under the owner's delegation): she finds a
  hand mirror on the ice in the first minute, and every raised pane is that
  mirror, grown. Built in grey box; the owner can reverse it.

## Players

- DECIDED (2026-10-30): players who love Monument Valley, Journey and
  Viewfinder.
- DRAFT: they play for wonder and feeling more than for difficulty. They
  expect every screen to be beautiful and every puzzle to be fair. They will
  finish an hour-long game in one sitting if it pulls them on.

## Pillars

DRAFT (2026-10-30), from round 1. Each pillar is a test a feature must pass.

1. **The way that isn't there.** Every solution is a shift in how the player
   sees the place: a path appears from the other side of the mirror. The
   moment of insight is the reward. Difficulty comes from insight, never from
   misreading the space or from trial and error.
2. **The mirror looks inward.** The other side is a glimpse of another
   dimension: what was, what might have been, what lies deep within her. What
   the player does with the mirror is what the story means. Raising it is
   looking back; lowering it is letting go; the ending is putting it down.
3. **Light after rain.** Grim on the way, hopeful at the end. Nearly
   wordless: light, music, place and motion carry the emotion. A late reveal
   reframes what the player has seen, as Nier Automata reframes the androids
   and the machines.
4. **Made by hand, every screen a picture.** One coherent, intentional look,
   curated frame by frame. Nothing generic, nothing that reads as AI slop.
5. **Respect the hour.** One sitting, no grind, no cash grab. Every chapter
   moves the story and adds one idea.

## Moment-to-moment feel

How each verb should feel. A feature brief cites these. DECIDED
(2026-10-30): the owner approved this section. Each entry: the feeling, the motion, the
sound, and what changes from today.

**Rules for every moment**

- Slower and softer than today. Only the response to a touch is instant: a
  press is answered in the same frame, by light or sound.
- Nothing appears or vanishes in a cut. Things grow, frost, bloom, settle.
- Every change has a cause the player can see in the world.
- Silence is allowed. The music thins at the important moments.
- Words never teach. The world shows; the player tries.
- **A reflection always looks like a reflection** (owner, 2026-10-30). The
  copy may differ in look (season, colour, light), but its shape and its
  behaviour are always those of the mirrored object: the same form, mirrored,
  standing and acting exactly as the reflected original would.
- **Attention to detail is a rule** (owner, 2026-11-17). Small details
  matter a lot, and in this game more than in most. Each control and each
  change gets the small details that make it feel made by hand, and a design
  is not complete until they are in it. The owner's example: a knob that is
  held changes its shape a little toward the direction of the drag, with
  more resistance near its limit.

**Opening the game.** Feeling: stillness, a held breath before a story.
Motion: the snowed garden from far above, snow drifting, the title in the
sky; a tap anywhere and the camera sinks down into the first place, with no
cut and no menu. Sound: wind, one piano note on the tap. Today: a pale veil
with a button.

**Walking.** Feeling: careful and small, a child in snow. Motion: she
starts and stops at once, with no ease, because that is how people walk
(owner, 2026-11-17, built; this replaces "she eases in and out"); short
steps; footprints in the snow that slowly fill. The way she
would walk shows as soft light on the ground, not a line. Sound: soft steps
that change with the ground. Today: a ring, a capsule glide and a thin line.

**Turning the view.** Feeling: walking round a model on a table; "look
again" (pillar 1). Motion: unhurried, about 0.7 s, easing out, the stage
staying centred. Sound: a soft swell of wind. Today: 0.4 s with no sound.

**Raising the mirror.** The signature moment. Feeling: looking back; wonder
with an ache. Motion: the glass rises out of the ground like ice forming,
about 0.8 s. The copy blooms outward from the glass in summer colour; the
ground it replaces frosts over and fades, never vanishing at once. The
summer colour is a difference of look only: the copy keeps the exact
mirrored shape of what it reflects. (Since 2026-11-17 the copy is mirror
glass, not summer; see the art decisions below.) Sound: a
sustained glass tone that opens into a chord of the chapter's theme. Today:
the frame appears and the ground is deleted at once.
DECIDED (owner, 2026-11-12): the change follows the pane. The pane rises
from its lower edge; the copy appears from the bottom up in step with the
pane's upper edge, and the ground it replaces is cut away from the bottom
up. This replaces "blooms outward from the glass". Built 2026-11-12.
DECIDED (owner, 2026-11-17): the moving edge never shows the inside of a
structure. Where the edge cuts a copy, the cut is closed with a flat sheet
of the pane's light. A face that lies in the edge does not flash, and a
shadow comes with the block that casts it. Built 2026-11-17.

**Sliding the mirror.** Feeling: tuning, like moving a lamp to see better;
precise and in control. Motion: the copy follows the hand with no lag; each
half step settles softly. Sound: each grid position plays a note of the
chapter's scale, so a slide plays a phrase. Today: silent snaps.

**Turning the mirror.** Feeling: choosing where to look. Motion: the glass
swings about its centre with a little weight, settling at each direction.
Sound: a rising or falling interval. Today (owner, 2026-11-23: "much more
slower, like moving a real large structure, but not too too slow"; then
2026-11-24: "a tit bit too slow"): the turn and the tilt gather speed, go
at most about 140 degrees a second, and slow to a stop on the step; one
step of 45 degrees takes about 0.53 s, two about 0.87 s, and a step asked
for while it moves keeps its speed. A held push keeps it turning at full
speed, and quick pushes join into one turn. The tilt goes all the way round
(2026-11-25). The lift knob moves the mirror up and down in the same way
(2026-11-25), at twice the pace (2026-11-26: "too slow"): a step of half a
unit takes about 0.4 s, and a held push goes about 6 steps a second. A tap
changes nothing. Before: 0.67 s and 1.12 s (from
2026-11-23); first 0.18 s for a step while held, 0.10 s for a tap.

**Lowering the mirror.** Feeling: letting go; an exhale, bittersweet. Motion:
the copy (mirror glass since 2026-11-17) goes back into the pane, and the
real ground returns and settles; the light dims a little. Sound: the raised chord resolves.
Today: an instant swap.
AGENT DECISION (2026-11-12, from the owner's rule for raising): the reverse.
The glass sinks from its upper edge down, takes the copy with it from the
top down, and the ground returns from the top down. The owner can reverse it.

**Falling.** Feeling: a drop, then a gentle catch; never punishing. Motion: a
short, slightly slowed fall; she lands in a small puff of snow and crouches.
No change is refused (owner, 2026-11-18): a fall off the world is a real
fall, the stage goes dark quickly, and it comes back at the move before, with
no sentence. Today: built; the fall has no sound of its own and no snow.

**Undo.** Feeling: time rewinds kindly. Motion: a quick reverse of the last
change, with a soft breath of sound. An icon, not a word.

**The glimpse of her sister.** Feeling: was that her? Never explained.
Motion: for under a second her sister appears in the glass only, waving with
her right hand; the music thins; then only snow.

**Reaching the goal.** Feeling: a small homecoming. The goal is where her
sister was a moment ago. Motion: the light warms, she pauses, a held note,
one to two seconds of stillness before anything moves. Today: a ring, 1.2 s
of stillness, then she moves on.

**Moving on.** DECIDED (2026-10-30, replaces "keep the mirror sweep"): the
places of a chapter sit in one continuous garden. She walks out of one place
and the camera travels with her to the next, with no transition effect.
Between chapters, a short wordless memory scene carries the change, and the
chapter title is written on the world, not on a card. Built in grey box
(2026-10-31): the next place grows from her feet while the camera travels,
and the old place drifts away. The chapter world (all places loaded at once)
is not built yet.

**The interface.** Feeling: almost absent. Icons only, in one drawn style;
they appear when they can be used and leave quietly. Today: four button
styles and words.

## The one-hour arc

- DECIDED (2026-10-06): about an hour, perhaps a little longer, like the
  first Monument Valley; the depth of the mechanics decides.
- DECIDED (2026-10-06): the four turning views stay for the whole game.
- DECIDED (2026-10-30): played in one sitting of about an hour, on Steam or
  on a phone. Each chapter moves the story on meaningfully and brings
  slightly more complex places.
- DRAFT (owner's idea, 2026-10-30): in the finale she uses two parallel
  mirrors to build an infinite pathway, to reach something she has long hoped
  for. Inspired by Inception. The mechanic arc builds toward it.
- DECIDED (2026-10-30): the last minutes feel light-hearted and hopeful.
- DECIDED (2026-10-30): a prologue, five chapters and an epilogue, seven
  parts in all. The five stages of grief run underneath the chapters, never
  as titles. About 12 minutes a chapter.
- DECIDED (2026-10-30): the story is arc A, "the pond", in
  [story arcs](story-arcs.md): the ice of the garden pond is the first
  mirror, the game takes place on its far side, and the chapters run from
  winter to spring. The keepsake is a pair of mittens. The drowning is never
  shown directly.

## Story and telling

- DECIDED (2026-10-06): nearly wordless, with chapter titles; the world and
  the art carry the story.
- DECIDED (2026-10-30): the story scenes are wordless too: staging, light,
  music, at most a single line. No dialogue boxes.
- DECIDED (2026-10-30): the emotional heart is loss and acceptance: putting
  down. The main character is a girl, and the story uncovers her tragic
  past. (Replaces the 2026-10-06 shortlist, in which possible lives led.
  `GAME_DESIGN.md` updated 2026-10-30.)
- DECIDED (2026-10-30): the mirror means reflection on oneself; a glimpse of,
  or portal to, another dimension; uncovering the unknown; exploring what is
  deep within.
- DECIDED (2026-10-30): the story is written together with the owner, from
  scratch. Inspirations: Inception, Nier Automata, Death Stranding. It can be
  grim, but it stays uplifting and hopeful.
- DECIDED (2026-10-30): the mirror shows the mirrored structures, as the
  rules require; it may also show something more on the other side. The life
  that might have been is a good fit (DRAFT), depending on the story.
- DRAFT (2026-10-30): "putting down" is not literal; whether the last puzzle
  is solved without the mirror stays an open idea.
- DECIDED (2026-10-30): the spine is twin sisters (seed B of round 2). She
  goes through the puzzles hoping to save her twin sister, who she believes
  has died. At the end she realises that she is the one who died. The twin
  resonates with a mirror's reflection.
- DRAFT: let the mechanic carry the reveal. All game the player reads the
  original side as real and the copy as the other side; the reveal is that
  she has been on the other side all along.
- OPEN: how a dead girl's realisation becomes a light-hearted, hopeful last
  few minutes. DRAFT recommendation: her acceptance frees her sister to live;
  the last scene is the living twin walking into morning light.
- DRAFT (2026-10-06): a few characters who give a line or two of quiet lore
  or a hint when the traveller walks up to them.

## First five minutes

- DECIDED (2026-10-30): a title screen like Monument Valley's: the first
  place seen from afar, and a tap begins.
- DECIDED (2026-10-30): by minute five, one glimpse of the sister in the
  mirror, then she is gone.
- DECIDED (owner, 2026-11-17): the start stage as it is now is too explicit
  and its choreography is poor. It will be made again, later. The direction:
  the girl only wakes up, and the scene explains nothing. The story is
  uncovered while the player plays. In the start stage she shows only two
  things: her urge to find her sister, who is drowning, and that she picks
  up a mirror, which she thinks her sister possibly left. Not built; the
  owner starts this work.
- DECIDED (owner, 2026-11-17), the meaning of "drowning" in the entry
  above: when she wakes up, she thinks that her sister is lost to the lake
  and is drowning at this moment (the owner put a question mark on the
  word). She thus starts a journey to find her missing sister, on the
  assumption that her sister possibly survived. This agrees with the spine
  in "Story and telling": she goes through the puzzles in the hope to save
  her sister.
- DECIDED (owner, 2026-11-17, built): when she arrives at a new stage, she
  turns to the stage's starting direction. The owner had no concern either
  way and asked the agent, who recommended to keep the turn.
- OPEN: what the player has learned and wants by minute five.

## Art reference

- DECIDED (2026-10-29): overgrown garden is the art direction to try, on a
  real stage before it replaces anything ([look pilot](look-pilot.md)).
- DECIDED (2026-10-06): agents make all art and music; music uses Lyria.
- DECIDED (2026-10-30), reference moments:
  - Monument Valley: first discovering the impossible geometry.
  - Viewfinder: making geometry out of a photograph, walking round it, and
    realising it is now part of the real place.
  - Nier Automata: realising the androids and the machines are the same.
- DECIDED (2026-11-10): the reference for mood, light and colour is a
  painterly, wordless journey over still water (see `docs/art/STYLE.md`):
  each place one painting with its own colour and weather, simple shapes,
  reflections, one small warm light. The puzzle view cannot show a sky, so
  the places stand over the pond's ice, which mirrors them.
- DECIDED (2026-11-11): no fixed reference picture; chasing a target frame
  damaged earlier rounds. The agent proposes a style with a proof frame from
  the engine, the owner agrees, then the agent builds. The owner agreed to
  "still water" on this basis: a film of thaw water lies on the pond's ice
  and mirrors the place (the five rules in `docs/art/STYLE.md`). This
  replaces the painterly reference of 2026-11-10 as the thing to match.
- DECIDED (owner, 2026-11-16): the anime "Girls' Last Tour" is a reference
  for the feeling of the story and the world: two small, simple figures in a
  very large, quiet, empty place; almost no colour; snow and haze; one small
  warm light. It is a reference for feeling and for rules, not a frame to
  match, and no frame of it is kept in the repository.
- DRAFT (owner's thought, 2026-11-16): the film "The Place Promised in Our
  Early Days", for the feeling of its story, its emptiness and its open
  shots. The owner: its art style may not match ours.
- DECIDED (owner, 2026-11-16): the world is decided before more work on the
  look. The puzzle camera keeps its angle (a test at 24 and 18 degrees showed
  no horizon and thinner tops). The garden stands up round the pond: tall
  things on its far sides, and mist behind them. Not built.
- OPEN (owner's doubts, 2026-11-16): the mirror reads as a portal that makes
  a new thing, not as a reflection; and the summer copy does not look like a
  reflection of the winter original. The owner: the contrast of winter and
  summer "is not a must". A test with the copy in the original's look is in
  `VALIDATION.md`.
- DECIDED (owner, 2026-11-16): the direction of the world proof is agreed
  (the garden round the pond, the pale palette, the copy in the original's
  look). It is only a proof: the background needs more work. See
  `VALIDATION.md`.
- DECIDED (owner, 2026-11-18, built): soft snow lies on the garden's roofs,
  walls and trees. The mirror bar and the place are higher in a tall frame,
  so the place is nearer the middle and a slide has room below the bar. The
  bar does not move while the view turns. The bar's changes are smooth, with
  a very small overshoot, and the other controls fade while a knob is held.
- DECIDED (owner, 2026-11-18), built: the marks of the mirror bar
  (`_draw_mark` in `world/mirror_bar.gd`). On the first proposal (the pane
  with arrows) the owner said: "Icon should be more simplified, almost zen,
  and be more designed". On the second: "A is nice. For the controls it
  looks good." The rule: the dark part of a mark is the mirror, and the pale
  part is where it can go, or the light on its glass. A knob is a dark dot
  on a pale trace: two lines along the ground (move), an open ring (turn),
  an upright line (lift). The mirror to raise is an empty upright frame.
  The mirror to lower is the frame with two pale lines of light in it. Undo
  is one open arc that turns back over the top, with a short, wide chevron
  head with round ends: the owner found the usual hooked arrow "too
  traditional and not zen enough". No mark has an outline of the pane in
  the view, and only Undo has an arrow.
- TRIAL (owner, 2026-11-18: "let's do a trial according to your
  suggestion"), built: the sign of the mirror's freedom is the pale part of
  the held knob's mark, made large at the mirror (`_sign_traces` in
  `game.gd`, `_draw_sign` in `world/placement_guide.gd`). Move: a grey line
  along each way of the ground, and a small dot at each step. Lift: an
  upright line. Turn: a ring round the foot, with a dot at each step of 45
  degrees. The mirror is a dark dot with a pale rim, and the step under the
  slide has a pale ring. The lines fade with distance from the mirror. The
  owner said "The sign looks good", and asked for a sign of both ways of
  the turn knob that does not make the screen busy. Built: the side that the
  mirror faces goes on a ball round its foot. A slide to the side follows a
  flat ring, and a slide up or down follows an upright half ring over the
  foot; the two cross where the mirror faces. Before the slide goes one way
  both are faint; after half a step, only the ring of that way is bright.
  The owner judges the trial in play.
- TRIAL (owner, 2026-11-18: "Try 1."), built: a direct slide on the mirror.
  The owner found that the mind goes to the mirror itself to move it on the
  ground. A slide that starts on the glass now moves the mirror on the
  ground, under the finger (one to one), with the sign of the move knob. A
  tap through the glass still walks. A slide that starts on the glass does
  not turn the view. The move knob stays while the owner judges the trial;
  if the slide on the glass is sufficient, the knob can go. (It went:
  see the decision on the controls below.)
- TRIAL (owner, 2026-11-18: "Yes, make the proof for the disc for the turn
  knob"), built: the held turn knob grows into a dial. The idea came to the
  owner from another player: a held knob grows into a round pad, the finger
  stays on the pad, so the control has a limit, and the pad shows which path
  of the finger changes the mirror in which way. The agent's view: it fits
  the turn best (the move may go to the slide on the glass; the lift is a
  straight line). The dial: the angle round the centre is the turn, one turn
  of the finger for one turn of the mirror; the distance from the centre is
  the tilt (the centre faces the sky, the middle ring stands upright, the
  rim faces the ground). The finger starts on the middle ring below the
  centre, so a short slide to the right still turns the mirror +45 degrees.
  A dark hand shows where the mirror faces. The world sign of the turn knob
  (the two rings round the foot) is removed in this trial; the world shows
  only the foot and the side the mirror will face. On the first proof the
  owner said: "The disc seems to be only catering one axis of rotation, no?
  Also looks a bit flat with the hard shadows. I want it to be more zen
  too." The owner then asked for "crossing tracks, with the sphere like
  disc", and for blind agents to suggest design patterns. A try with the
  ceramic knob on a glass ball: "Doesn't look good. I don't prefer the knob
  still existing." Three blind agents (Opus; lenses: 3D orientation input,
  calm visual language, first-time player) gave nine patterns
  (`test-output/polish/dial-patterns.html`). Two put a sky map first, one a
  turntable with one axis for each hold. The owner: "Lets do sky map".
- TRIAL (owner, 2026-11-18), built: the sky map. The held turn knob opens
  into a disc of frosted ice, tinted from the pale sky at the centre to the
  slate water at the rim, with no shadow. No knob stays on it: one dark bead
  is the mirror, a little above the thumb, and the thumb moves it as on a
  laptop pad. The owner then said: "The disc should opened centered to the
  original knob position." Now the map opens on the knob, and the bead
  starts at the top of its ring. Two long guides cross at the bead: the ring of its tilt (the
  turn) and the line from the centre (the tilt). The guide that the slide
  uses is clear. A hollow ring marks the start; a ring spreads from the
  bead at each step; a resting thumb lets the stage show. The owner judges
  it in play.
- DECIDED (owner, 2026-11-18), built: the controls after play on the
  owner's iPhone. "I think the directly dragging the mirror is much more
  intuitive": the move knob goes, and a slide on the glass is the one way
  to move the mirror with a finger. The sky map goes too: "The closer it
  got to the center, the more difficult the control gets due to smaller
  separation distance with smaller radius. I think we need the two axis
  option (Turntable?), and maybe allow them to move both axis
  independently, no need lift and rehold." The held turn knob opens into a
  turntable pad: sideways turns, up and down tilts, both in one hold, each
  axis with its own steps of 40 points and its own margin. Two gauges in
  the pad, away from a right thumb: a flat ring for the turn and an arc on
  the left rim for the tilt (the "glass globe" of the blind agents).
- DECIDED (owner, 2026-11-18), built: one unit is one point. The bar was
  much larger on the iPhone than on the Mac, because the phone counted a
  unit by its pixel density and the Mac by its pixels. The owner: "I don't
  want the case where we shrink the size for iPhone just to find it also
  get smaller on mac. Any way to map these correctly?" Now both count a
  unit as one point of the device's own interface, and a desktop window
  opens phone-shaped. Then the bar set is smaller and lower: knobs of 46
  points, Undo and remove of 38, the bar at 0.84 of the play area's height.
- TRIAL (owner, 2026-11-19), built: stepping stones on a ball. On the
  phone the owner said: "The arc lines on the turn disc is weird, doesn't
  look good. Can we make is simpler and more intuitive", and asked for blind
  advisors with no direction from him. Three blind agents (Opus; lenses:
  motion and touch, calm visual language, first-time player) gave nine
  patterns (`test-output/polish/pad-patterns.html`). All three first choices
  were straight rows of dots with no lines; two ranked rails first, one
  stepping stones. The owner: "Leaning towards stepping stone", then, while
  it was built: "maybe the placement of the stepping stones should look
  like on a sphere, i.e. they should be curved. In fact, the disc itself
  should be use a sphere as the concept". Built: the pad is a ball of ice;
  one pale stone for each facing the hold can reach lies on it, in rows of
  tilt round its poles and columns of turn, seen a little from above. The
  thumb rolls the ball as a trackball, and the stone that comes to the
  press point is the facing the mirror goes to. No stone past a limit; no
  dark mark on the ball. The owner judges it in play.
- DECIDED (owner, 2026-11-18), to do after the controls: (1) some
  reflections are wrong; the owner will give the cases. (2) When the
  mirror moves the block that the traveller stands on, she moves with it.
  (3) A change that makes her fall is applied: she falls through the
  level, the stage fades quickly to dark, and she comes back where she was
  before that change. The mirror no longer snaps back. (4) The fall-path
  sign goes, because a fall is now shown as it happens. Items 2 to 4 were
  built on 2026-11-19; see the BUILT entry below.
- DECIDED (owner, 2026-11-19, during the night's reflection fixes): "The
  cut away of existing structures should be bounded by width and height of
  the mirror", then "Yes, depth bounded by width and height". Built: the
  mirror copies from a box behind it and replaces the matching box in front,
  each as wide and high as the pane and as deep as its larger side (3 for
  the 3×3 pane). Before, the reach along the normal had no end, so the
  mirror cut stones and drew seams far from the glass. The depth of an
  oblong pane is not decided, and it does not need to be: see the next
  entry.
- DECIDED (owner, 2026-11-19): "A: fixed 3×3". The pane is always 3×3 and
  the player gets no size control, so the mirror always swaps one 3×3×3
  box with another. The owner asked for an independent opinion first.
  Three blind advisors (Opus; lenses: puzzle design, touch on a phone,
  clarity of the rule) did not see the agent's recommendation. None chose a
  size control for the player: lift and slide already select what Resize
  did, a large pane wins most stages in one step, and the bar has no good
  place for it. Two chose the fixed pane; one chose a size set by each
  stage, which plays the same while every stage uses 3×3. The `width` and
  `height` of a stage file stay unused, in reserve. If a stage needs another
  size later, keep the pane square, so the frame still tells all three
  sizes of the box. The risk the advisors named: gaps of 3 and towers of 3
  can make stages feel the same, so the variety must come from the world
  (absolutes, safe falls, a flat pane, a second mirror).
- BUILT (2026-11-19): the rule changes of 2026-11-18, in the owner's words
  of that night: "1: Character stick to the current platform, move along
  with it. 2: Falling will result in actually falling, and fade to black and
  restart in previous move (No more invalid move and snap back to the
  previous move automatically, which feels weird) 3: No more falling
  indicators." With the direct controls every change applies. She goes with
  the copy she stands on, also during the drag. A fall off the world goes
  dark in 0.22 s and comes back at the move before. No ghost shows and
  nothing is predicted. AGENT DECISIONS, for the owner to judge in play: a
  change that puts a block on her ends as a fall does (dark, then back),
  because no move is refused; she rides only while her copy is still a floor
  under her at the new place, and stays if not; her facing does not turn
  with the copy; the classic editor keeps its ghost.
- FOUND (2026-11-19): riding is a new way to travel. In `01_route` she can
  stand on the copy, slide the mirror from 2.5 to 4.0, ride from 3.5 to 6.5
  and walk to the goal. The rest platform is no longer needed, so the
  stage's lesson ("Rest, then rebuild the route") can be passed by. The
  other stages are not searched for such ways. A copy carries her at most 6
  from its source, because the mirror reaches 3.
- FIXED (2026-11-19), after the owner's report in play: "when the mirror is
  deactivated, she rode down the part with her body clipped inside the part
  a bit". The collision changed at once, but the pane's edge cuts the copy
  away over 0.8 s, so she fell into a copy that was still drawn. A raise or
  a lower that takes her ground now waits until the edge is at her feet.
  Found in the same check and fixed: a copy that passed through a fixed
  block of the same height sent her back to her start place for those
  frames. That block is now her floor.
- DECIDED (2026-11-19, owner: "Fall where copy left") and BUILT: when a
  slide or a turn takes her part of the stone out of the pane's frame, she
  keeps the last place where the copy held her. While the finger is down
  she stays in the air there; when the change applies, she falls from
  there. Before, she went back to her start place in one frame. AGENT
  DECISIONS: the same rule applies when the copy is not a floor at the new
  place (a wall stands there, or a tilt makes the face too steep); the copy
  takes her again if the mirror comes back while the finger is down; the
  place depends on the way the mirror went, not only on where it ends.
- DECIDED (2026-11-19, owner, after play on the phone: riding "creates
  quite a chaotic and stage breaking behaviour"; then "remove the riding")
  and BUILT: she no longer rides her copy. She keeps her place in the
  world, and falls when the change applies and no floor is under her. The
  two entries above are history. Three blind advisors (touch interaction,
  puzzle design, a first-time player) and the agent each gave the same
  answer: the result must depend only on where the mirror ends, and stage
  2 already says "Find a place that stays still".
- WITHDRAWN (2026-11-20, owner: "Nah, then rather we use the current
  control."): the rail lock below. At 45 degrees the rail lock keeps the
  present gesture, hold the glass and slide on a diagonal, and only stops a
  step on the other axis. The move control stays as it is. The owner's
  words for the larger fault: the "player cannot visually distinguish a
  mirror going up vs the mirror going a similar distance in both axis",
  and "it is hard to tell visually about the mirror's position, until we
  turn the camera angle". OPEN: how the mirror shows its place. Measured in
  the engine at phone size (2026-11-20): a lift of a half unit and a move
  back of a half unit on the two ground axes put the pane 4 points apart
  on the screen. A proof tried three marks, with no decision yet: a line
  where the pane's plane meets each top and the water, a stem at each
  lower corner while the pane is above the water, and the mirror's two
  boxes (what it reads, where it writes) laid on the water. The water is
  the one flat surface that every stage has. The present contact seam is
  white on the white tops, so it does not show there. The owner's answer to
  that proof (2026-11-20): "Seems like a very patchy way of doing it. Can
  we rethink our approach?"
- ADVICE (2026-11-20), no decision yet: three blind advisors (how the eye
  reads depth with no perspective; puzzle design; touch and a first-time
  player) each got the owner's words, the measured facts and the decisions,
  and none of the agent's ideas. All three gave the same answer. Cause: the
  mirror floats and touches nothing, and it has three freedoms on a screen
  that shows two. Remedy: the mirror stands on the world, the free height
  goes, and no sign is added. All three rejected fixed sockets, more
  signs, and a view that turns by itself. The agent agrees with the cause
  and the remedy, and corrects two points from the tested solutions:
  (1) steps of a half unit on the ground must stay, because the copy moves
  two units for each unit of the mirror (Route uses 2.5 and 4.0; Turn and
  Together use a slide of a half unit); (2) the height is used: "Only the
  ground" and "Together" are each solved by a mirror one unit lower, and
  the pane cannot stand on a top, because it must pass through the stones
  that it copies. The agent's brief said wrongly that no tested solution
  uses the height. The agent's direction: the mirror is an object that
  stands in the pond (posts that always reach the water, glass with a
  body that hides what is behind it), the ground steps stay, and the
  height is in whole units and only on the stages whose idea is height
  (each stage file already has its own limits).
- DECIDED (2026-11-20, owner: "But the height is a core part of the
  puzzle's freedom"): the height stays a freedom of the mirror on every
  stage. It is not removed and not limited to some stages. So the mirror
  must show its own height and its own place on the ground. First engine
  proof of that at phone size (a scratch script, nothing built): the two
  side posts always reach the water, each post stands in a small mound of
  snow, and the glass has a light body (0.14 in its middle, where today it
  is 0.012). In a lift the feet stay and the glass goes up its posts; in a
  move on the ground the feet go with it. For a half step the two are
  still close in a still image; the motion is not yet proved.
- OPEN (2026-11-20), the owner's first intent: "The initial stage's blocks
  and structures are initially intended to be floating, just like how
  Monument Valley does it, and by extension, the mirror should be floating
  as well. [...] If it does make sense, the water below can still stay or
  be gone." The agent's view: floating fits this game better than the
  standing mirror. "Together" floats 3 units above the water, and "Only
  the ground" and "Together" each have a stone that hovers; on "Together"
  the standing mirror needs posts 3 units long, which shows that the
  standing form fits only the stages that touch the water. So the standing
  mirror is withdrawn as the general answer. But Monument Valley floats
  for two reasons that this game does not have: there the screen is the
  truth (what looks joined is joined), and each part that moves is fixed
  to the structure with one freedom. Here the depth is real and the view
  turns. In one fixed view with no perspective, nothing can tell the
  height of a free thing from its depth unless a surface below shows it.
  So the agent's advice is to keep the water as the one floor of a world
  that floats: each stone, copy and mirror has a soft shadow straight
  below it on the water, the water then holds the plan of the stage, and
  the height of a thing is its distance from its shadow. Not proved. Two
  costs: the stages that stand in the water must float higher, and the
  rule that an image in the water is gone 1.1 units up ("never taken for
  ground") stays, so the sign is a shadow, not an image.
- PROOF (2026-11-20, owner: "Proof with water"), no decision yet: an
  engine proof at phone size of the floating world (scratch script only,
  nothing built; images in `test-output/polish/float/`, git-ignored). On
  "Turn" and "Together" the water is 2 units below the lowest stone, and
  the pond and the garden are built again at that height. The rule of the
  drop shadow, which the game has on tops, is laid on the water also: the
  stones and the copies make one shadow, and the pane has its own shadow
  on top of it. The glass has a light body. Nothing else is added.
  Results: the look holds (the stage floats, the reeds and the garden stay
  at the water). In a lift the plan on the water does not change; in a
  move on the ground the line of the pane moves with the mirror. On
  "Turn" the pane's lower edge is about 70 points above its shadow at the
  start, about 94 points after a lift of a half unit, and about 70 points
  after a move back of a half unit on both axes (read from the image). On
  "Together" the shadows show that the upper path is not above the low
  path, which one view could not show before. Weak points: the shadow of
  the pane is a thin dark line on dark water (about 10 points wide), and
  on "Together" it is about 170 points below the pane, so the eye has a
  long way to go; the stones lose their image in the water (the 1.1 rule),
  only the reeds and the garden keep one; the sign is not proved in motion
  or in play. Three heights of the water were compared on "Turn": at a
  half unit the image and the shadow mix; at 1 unit the stones hide a part
  of their shadow, and a mirror that is 1 unit lower goes into the water;
  at 2 units the plan is whole and apart from the stones. The agent's
  advice: 2 units, and a trial in play before a decision.
- ACCEPTED AS THE SIGN, the look is in tuning (2026-11-20, owner: "I think
  the shadow gives a clear indication about the position of the mirror,
  but would need to be fine tuned a bit. Now the shadow seems too sharp").
  The build is not yet approved. Second engine proof (scratch script only;
  `test-output/polish/float/soft-*.jpg`, git-ignored), four looks of the
  soft rim on "Turn" and "Together": 0.12 units (the first proof), 0.4,
  0.7, and a rim by height (0.2 units for each unit that the thing is
  above the water, at most 0.6). Results: at 0.4 the edge is soft and the
  line of the pane stays clear on the two stages. At 0.7 the plan becomes
  a blur and the line of the pane is weak. With the rim by height, the
  line of the pane is sharp when the mirror is near the water and soft
  when it is high, so a lift changes the shadow although its place stays;
  the cost is a weaker line when the mirror is high (on "Together" it is
  weaker than at 0.4, but it shows). Two corrections in the proof: the
  shade on the water is a cool dark blue (0.07, 0.10, 0.16), because the
  game's shade for snow (0.16, 0.13, 0.2) made a purple line where the
  shadow of the pane lay on the shadow of the stones; and the depth of the
  rim is measured from the edge of the whole shadow, so that two blocks
  that touch have no light line between them. The agent's advice: the rim
  by height.
- DECIDED (2026-11-20, owner: "By height."): the soft rim of a shadow on
  the water is by height: 0.2 units for each unit that the thing is above
  the water, at most 0.6. Not built.
- OPEN (2026-11-20), the owner's question: "would it work if the mirror
  has a different shadow tint?" Third engine proof (scratch script only;
  `test-output/polish/float/tint-*.jpg`, git-ignored), four tints for the
  shadow of the pane on "Turn" and "Together", each with the rim by
  height: the same shade as the stones; a deep teal (0.0, 0.30, 0.38); a
  pale ice (0.80, 0.90, 0.96), which is a light and not a shade; a warm
  tint (0.95, 0.72, 0.42). Results: a different tint works, and it tells
  the mirror from the stones at once. On dark water a dark tint has
  little room: the deep teal is weaker than the same shade. The pale ice
  is the clearest at each height, also where it lies on the shadow of the
  stones, and it is the colour of the glass and of the copies. The warm
  tint is as clear, but it is loud and it takes the colour of the ring,
  which is the sign of the goal. The agent's advice: the pale ice; its
  strength (0.3 in the proof) can go down if it is too much like a mark.
- OPEN (2026-11-20), the owner's idea: "the mirror might not be casting a
  shadow, but lets assume it's edge is glowing, and therefore emitting
  light onto the water. How would that look?" Fourth engine proof (scratch
  script only; `test-output/polish/float/glow-*.jpg`, git-ignored) on
  "Turn" and "Together". The frame glows in the colour that it has today
  for the grab cue (`9ee9f2` in `world/mirror_frame.gd`). The lower edge
  puts a pool of light on the water straight below it; the light is added
  to the water, and it is wider and weaker when the edge is higher (its
  width follows the rim by height). The stones and the copies keep their
  dark shadow. Three levels: the energy of the frame is 0.9, 1.6 or 2.6,
  and the strength of the light is 0.22, 0.34 or 0.48. Results: the glow
  and the light read as one thing with a cause, not as a mark. The glow
  also makes the outline of the whole pane clear. The low level fits the
  quiet look; the high level is loud. The light shows on "Together",
  where the edge is 4.5 units above the water. Not in the proof: the glow
  puts no light on the stones or the snow. One result for the controls:
  the glow of the frame is today the cue that the pointer rests on the
  mirror, so that cue must become a second level. The agent's advice: the
  low level at rest, and the medium level while the mirror is held.
- DECIDED (2026-11-20, owner: "Yes, keep it"): the edge of the mirror
  glows and puts light on the water straight below its lower edge. The
  glow is at the low level at rest (energy 0.9, light 0.22) and at the
  medium level while the mirror is held (energy 1.6, light 0.34). The
  mirror has no dark shadow and no tinted shadow. Not built; the build of
  the floating world needs an approved plan.
- BUILT (2026-11-20, owner: "Approve the plan"): the floating world. The
  water is 2 units below the lowest stone of a stage (`FLOAT_GAP` in
  `world/trial_lighting.gd`); the fall limit of "Together" is -8, below
  its water. Each stone and each copy has one soft shadow straight below
  it on the water (`world/water_shadow.gd`): a picture from above that
  holds the darkest value at each point, so shadows that overlap do not
  add up and a plan with a hole is correct. The rim goes outward only:
  0.15 units for each unit above the water, from 0.05 to 0.45. The frame
  of the mirror glows at 0.9 at rest and at 1.6 while the mirror is held,
  and each edge puts light on the water straight below it
  (`world/mirror_light.gdshader`), 0.22 at rest and 0.34 while held; the
  light of an edge that is much higher than the lowest edge is almost
  nothing. The glass has a body of 0.14. Three decisions that the agent
  made in the build: (1) while a finger holds the mirror, the frame is
  the metal that glows and not the pale ghost of before, because the
  ghost has no glow; (2) when the mirror comes up or goes down, the plan
  before goes out while the new plan comes in, so the shadows of stones
  that stay do not go out; (3) the view also holds the shadows and the
  light on the water, so a stage sits a little higher on the screen (the
  size of the view did not change on any of the seven stages). Not built:
  light of the glow on stones and snow. Known: the place that she leaves
  has no shadow on the water while it drifts away. Not proved: play on
  the phone, the cost on the phone, motion seen by a person. Captures:
  `test-output/polish/float/build-*.jpg` (git-ignored).
- ADVICE (2026-11-20, owner: "An independent board of blind advisors for
  look judgement and give directions"), no decision yet: three blind
  advisors (Opus; eyes: a new player, an art director, a critic of finish
  on a small screen) each got 22 engine frames of the build at phone size,
  the rules of the game, the fixed decisions, and none of the agent's
  opinions. First a blind test: two pairs of frames in which the pane is
  at the same place on the screen to 2 points, one time lifted 2 units and
  one time moved back 2.5 units on each ground axis. All three named both
  pairs correctly (6 of 6), 70 to 85 percent sure. All three used one cue,
  the light on the water, and all three said: the pane itself tells
  nothing, and the cue is faint, far from the pane, and lost behind stones
  that are in front of it. Limit: the advisors read stills with care and
  with no limit of time; a glance by a person is not proved. All three
  keep: the water and the fog, the soft shadows on the water (named the
  best sign of depth), the snow tops, gold for the ring alone, the empty
  space. All three mark the mirror as the weak part. Their directions, by
  agreement: (1) all three: the light of the frame must also fall on the
  stone and snow that the pane crosses, as light and not as a mark (the
  item "not built" above); (2) all three: the light on the water must be
  stronger and wider, and must not go faint when the pane is high;
  (3) all three: the glass hides the traveller (measured: her darkest
  tone is 27 of 255 in front of the pane and 86 behind it), so the frost
  and the body of 0.14 go down by 40 to 60 percent, or stay near the
  frame only; (4) two, and measured: the frame is a thin even line that
  reads as an outline and not as a glow, and rest and held do not differ
  (the peak of the line is 219 of 255 at rest and 237 held; the brightest
  point of the light on the water is 13 percent brighter held); (5) all
  three: the dashed lower edge of a mirror that is down or goes down reads
  as a selection sign; (6) two: the on/off button of the mirror is salmon
  pink, which is warm on the cool tool; (7) the ice copies read as soap
  (two), and their tops merge with the snow (one); (8) two: the grip rings
  look like the rain rings on the water. Not agreed: the control bar (two:
  generic and heavy; one: quiet) and the far buildings (one: unfinished;
  two: keep). One advisor each: a stone that the mirror replaces goes with
  no trace; the blotches on tall stone faces; the dotted rim of the snow.
  The agent's corrections: the light on the water is straight below the
  lower edge (one advisor read the gap of 1.5 units as an offset: the gap
  is the fault, not the place); light that shows through stones in front
  of it would be a sign, so "never hidden" cannot be met in full; the
  agent's brief said "gold and warm tints belong to the goal alone" where
  the rule names gold, so the finding on the warm windows has little
  weight. Images: `test-output/polish/float/board-lift-or-slide-*.jpg`;
  the three reports in full: `test-output/polish/float/board-reports.md`
  (git-ignored).
- PROOF (2026-11-21, owner: "Make the proof"), no decision yet: the four
  main directions of the board for the mirror, in the engine at phone
  size, as scratch code (no file of the game changed). The second
  version, by its values: (1) the stone shader gets the place of the pane
  and makes the light of the mirror on stone, snow and copies: a line of
  light where the glass passes through a surface (clear to 0.16 units,
  soft to 0.55), light near the frame, and light on the tops straight
  below the lower edge by the rule of the water. White snow cannot become
  brighter, so it takes a cool tint (0.35, 0.80, 1.0) and darker stone
  gets added light; strength 0.85 at rest, 1.0 held. A first try with
  decals failed: added light does not show on the snow. (2) The light on
  the water is a pool: width 0.2 + 0.18 for each unit of height (0.3 to
  0.9), 1.3 times the strength, a paler tint (`c4eef5`). (3) The glass
  has a body of 0.07 in the middle and at the foot and 0.17 at the top
  and the sides; half the frost. (4) The frame has a glow around it in
  the plane of the pane, brightest at the lower edge (strength 0.3 and
  width 0.08 at rest; 0.6 and 0.13 held); the metal glows at 0.9 at rest
  and 2.0 held. Measured against the build: held now differs from rest
  (peak of the frame 224 and 246 of 255, width of its glow 24 and 37
  pixels; the build: 219 and 237, 20 and 19). Her darkest tone behind the
  glass is 75 to 85 (the build: 83 to 104; the first version, with a body
  of 0.03: 54 to 70). Blind tests, the same two pairs, new advisors each
  time, all Opus. The build: 6 of 6, 75 percent sure, one cue (the light
  on the water). The first version (a full board of three): 6 of 6, 80
  percent, one cue; two called its stronger light on the water "a neon
  bar"; two said its clear glass "disappears", where the first board said
  that the glass hid her (the body of the glass is a trade between the
  pane and the traveller); none saw its light on the snow; two praised
  the held state. The second version (three readers, the pairs only): 6
  of 6, 79 percent, two cues: all three also used the line of light on
  the block top, and two took it for ice. All three readers said that a
  player cannot tell a lift from a slide in one second from a still, and
  all three asked for a mark from the frame down to the water, which the
  owner rejected. So the proof makes the mirror a better object and adds
  a second cue, but it does not make the place of the mirror clear at a
  glance in a still. Not proved: motion (in a lift the light on the water
  stays in its place and gets wider; in a slide it travels with the pane)
  and the eye of a person. New ideas of the second board, not tried: an
  image of the glowing frame in the water (one advisor); the glass fills
  from its foot as the mirror comes up (one). Images:
  `test-output/polish/float/proof-*.jpg`; the reports:
  `test-output/polish/float/proof-board-reports.md`; the code of the
  proof: `test-output/polish/float/proof-code/` (all git-ignored).
- CLIP (2026-11-21, owner: "Make the clip"), no decision yet: a motion
  clip of the second version of the proof, 19 seconds at phone size, on
  the stages `01_route` and `14_turn`. On each stage a held knob lifts
  the mirror 2 units and brings it back, then the mirror slides 2.5 units
  back on each ground axis, to the same place on the screen, and comes
  back. A second clip shows the build and the proof side by side, frame
  for frame. Seen in the frames: in a lift the light on the water stays
  in its place and gets wider and paler; in a slide it travels with the
  pane. The game moves the mirror in half steps, and during a drag it
  already draws a guide in the pane (a ring and an upright line for a
  lift, ground lines for a slide). Not judged: no advisor saw the clip,
  because an advisor reads stills only; the clip is for the eye of the
  owner. Clips: `test-output/polish/float/proof-motion.mp4` and
  `proof-motion-compare.mp4`; the code: `proof-code/motion_clip.gd` (all
  git-ignored).
- LENS TEST (2026-11-21, owner: "Make the test"), decided in LENS below. The
  owner saw in the clip that a lift and a slide still look the same, and
  asked if the ortho camera makes this unavoidable. In an ortho view, a
  point's distance along the line of sight does not show, so a pane
  lifted 2 units and a pane slid about 2.5 units back on each ground axis
  make the same image. A perspective lens makes the size of the pane show
  its distance. The test, as scratch code on the build (not the proof):
  a perspective stage camera at 30 and 45 degrees of vertical view, with
  the same angles (30 degrees down, 45 degrees to the grid). The plane
  through the middle of the view keeps the ortho scale, the framing
  follows the ortho rules, and the image in the water gets the same lens.
  Each pair is seen in one view that does not move. Measured: on the
  screen the lifted pane is 13 and 16 percent taller than the slid pane
  at 30 degrees, and 19 and 27 percent at 45 degrees (the same size in
  ortho). On the half grid, the slide that matches a 2-unit lift is half
  a step longer in perspective, and it lands within 6 to 12 points of the
  lift on the screen (2 in ortho). Blind test, three new Opus readers for
  each lens, the same task as before: ortho 6 of 6, 88 percent sure; 30
  degrees 6 of 6, 90 percent; 45 degrees 6 of 6, 92 percent. All six
  perspective readers measured the size of the pane and used it, but as
  their second or third cue, after the light on the water (and the
  traveller in front of or behind the glass, which the ortho readers
  used too). All nine said no to a one-second read; one called the
  change of size "too small to see quickly". The earlier 75 percent came
  from older frames, not from the lens. So, in stills, a perspective lens
  adds a true cue, but a weak one, and it does not make the place of the
  mirror clear at a glance. The look changes: the view shows more of the
  walls, windows and tree behind the stage, and at 45 degrees far blocks
  are a little smaller. Not judged: motion (in a lift the pane grows a
  little; in a slide it shrinks), the puzzle read, and the eye of the
  owner. Clips: `test-output/polish/float/lens-motion-compare.mp4` (ortho,
  30 and 45 degrees side by side) and `lens-motion-30.mp4`,
  `lens-motion-45.mp4`; stills: `lens-stages.jpg`, `lens-pairs.jpg`; the
  reports: `lens-board-reports.md`; the code: `proof-code/lens/` (all
  git-ignored).
- LENS (2026-11-21, owner: "Although the difference is subtle it really
  helped with the read", then "Try it"; 2026-11-22: "Yes, keep 30°"),
  built and kept: the
  stage camera has a perspective lens of 30 degrees from the top to the
  bottom of the view. The angles of the view do not change. Each pose is
  made as a flat pose, and the lens then stands back on the same line, so
  that the middle of the view keeps the flat scale (31 to 42 units from
  the middle on the seven stages). The fit is exact through the lens: a few
  passes fit each point where the lens shows it (16 points of margin at
  the sides of every stage). The image in the water uses the same lens.
  The rings and the motes take their scale at the mirror. The reach of the
  view and of the shadow map follow the distance (60 and 40 units past the
  middle). Measured on the seven stages: the back of a stage looks 17 to
  21 percent smaller than its front, and a lift and its matching slide
  differ in size by 5 to 6 percent for each unit. At 45 degrees these are
  26 to 31 percent and 7.5 to 10 percent: the cue and the shrink are one
  effect, and the angle turns both up or down. The angle is one value,
  `LENS_ANGLE` in `world/stage_camera.gd`; 0 gives the flat view. A slide
  counts the finger's travel as if it began at the mirror. Through a lens,
  one unit shows at a different size at the bar, so a slide from the bar
  moved the mirror an incorrect distance (found by
  `tests/direct_controls_tests.gd`). The move hint of the mirror bar
  takes its direction at the mirror too (2026-11-22, owner: "Yes, fix
  it"): through a lens, the direction of an axis changes a little across
  the stage. The owner kept 30 degrees;
  45 degrees is not built. Review:
  `test-output/polish/float/lens-build-motion.mp4`, `lens-build-stages.jpg`
  and `lens-build-turns.jpg` (git-ignored).
- NARROW LENS TEST (2026-11-25, owner: "Can we try this trick?"), decided
  (owner, 2026-11-25: "Keep 30°"): the lens stays at 30 degrees, and no
  narrow lens is built. The owner's idea: a narrow lens of 10 to 15 degrees with
  the camera far back looks almost flat, but keeps a little perspective,
  and many games that look flat use it. The game already does this at 30
  degrees (the lens stands 31 to 42 units from the middle). The test, as
  scratch code on the build: the same framing at 30, 15, 12 and 10
  degrees, at phone size. Measured on three stages:

  | Lens | Distance (units) | Back of the stage smaller | Lift against the matching slide |
  | --- | --- | --- | --- |
  | 30 (now) | 32 to 40 | 17 percent | 6 to 7 percent larger |
  | 15 | 65 to 81 | 9 percent | 3 percent |
  | 12 | 81 to 102 | 7 percent | 2 to 2.6 percent |
  | 10 | 97 to 122 | 6 percent | 2 percent |

  On "Another way round", the slide that matches a lift of 1.5 units lands
  8.7 points from it on the screen at 30 degrees, and 2.1 to 2.4 points at
  15 and 10 degrees (2 in the old flat view). So a narrow lens takes back
  most of the depth cue that the owner said "really helped with the read";
  the light of the mirror on the water stays the main cue. The look: the
  stage is almost the same, with edges nearer to parallel; the houses,
  fence and trees behind it look flatter and larger. One side effect: the
  shadow map must cover a longer view, so her shadow on the snow becomes
  weak; when the view starts 40 units before its middle (`near`), the
  shadow is as clear as at 30 degrees. Nothing else changes: the fit, the
  touch, the image in the ice and the snow follow the lens. Review:
  `test-output/polish/lens-narrow/` (stills, `lift-slide.jpg`,
  `lens-narrow-compare.mp4`, `proof-code/`; git-ignored).
- HISTORY (2026-11-19, owner: "Yes. That is it."), not built: the move
  control is a rail lock. A slide that starts on the glass picks the
  nearest of the two ground axes in its first points of travel, the mirror
  then moves along that axis only, and the lock stays until release. The
  owner's words for the fault: "panning right now moves the mirror in user
  unintended direction, making movement not confident". Cause, calculated:
  the ground is seen at 30 degrees, so a finger move up or down counts
  twice as much as a move sideways; a slip of 8 to 12 points steps both
  axes. All four views agreed.
- DECIDED (2026-11-20, owner: "Keep 45."): the camera stays at 45 degrees
  to the ground axes. The owner considered other angles. Engine proof at
  phone size (2026-11-19, four angles, each with its quarter turn): a level
  slide is 0 degrees from a tie between the rails at 45, 8 at 35, 12 at 30
  and 22 at 20. Away from 45 the four views fit at different sizes: a long
  stage changes size 1.5 times at a camera turn at 30 degrees and 2 times
  at 20, where the stage also looks almost front-on. At 45 degrees each
  rail is a diagonal on the screen, 27 degrees from level, so the quarter
  of the screen that the slide goes into picks the rail, and a level slide
  or an upright slide is a tie.
- DECIDED (2026-11-19, owner: "The ball disc is a bit hard to use"), form
  not yet decided: the ball pad of the turn knob goes. All four views: one
  axis for each gesture, the stage stays in view, the steps show at the
  mirror. OPEN: the facings. The puzzle advisor and the agent: quarter
  turns by a tap, and one control to lay the pane flat (the tested routes
  of the six stages use quarter turns only, with no tilt). The other two
  advisors: 45 degree steps by a slide.
- IDEAS (2026-11-22, owner: "Next up lets fix the rotation control", then
  "Can we do a round of ideation and mockup?"), not decided: three blind
  advisors (Opus; lenses: touch and thumb, calm visual language, first-time
  player) gave nine forms, each drawn over frames of the game at phone
  size (`test-output/polish/turn-ideas/index.html`, git-ignored). First
  choices: Nudge (one short push of the turn knob for each 45 degree step),
  Glide stone (hold and slide, a set distance for each step, five dots at
  the mirror), Pull the edge (a slide from an edge of the glass turns it).
  All nine have no pad; seven show a small sign of dots at the mirror.
  Checked: the solution of "Another way round" turns the yaw from 90 to 0
  degrees, the other way from a slide to the right now, so both ways must
  be equally easy. The agent's advice: a trial of Nudge with the ring of
  eight dots at the mirror. The owner decides.
- TRIAL (2026-11-23, owner: "Try the nudge. I also love the tap idea, with
  the tap maybe going 45º turn instead of whole 90 and hide the 45 behind a
  gesture. The main question is that how to tilt."), built: the ball pad is
  gone. The held turn knob nudges: a push of 16 points is one step of 45
  degrees, and a way back of 8 points readies the next push. Sideways turns
  and up or down tilts, in one hold; a push more than 30 degrees from an
  axis gives no step, and a long push is one step. A tap turns the mirror
  one step clockwise on the screen, so "Another way round" needs two taps;
  the prompt there is "Tap the knob to turn" (both changed 2026-11-25: a
  tap changes nothing). While the knob is held, the
  sign at the mirror is a faint ring with a dot at each of the eight
  facings (for a tilt, the upright half ring of five), a dark dot where the
  mirror faces now and a pale ring where the hold began. The knob's mark is
  a dark dot with four small pale dots. The tilt in this trial is a push up
  or down on the same knob; the owner judges it in play. Seen at phone
  size: when the mirror faces the camera, the half ring of the tilt is seen
  edge-on and shows as an upright line. Review:
  `test-output/polish/turn-ideas/nudge/` (git-ignored). The owner kept the
  push up or down for the tilt (2026-11-23: "Keep it.") and asked for a
  slower turn, like a real large structure. Built: the heavy turn (see
  "Turning the mirror" above; `TURN_SPEED` and `TURN_ACCELERATION` in
  `game.gd`). Changes of the turn knob made while the last change settles
  wait, and their steps add up. A tap or a push that waits starts after
  the last change applies, so two taps are two turns with a short stop
  between, not one long turn. Review: `test-output/polish/turn-ideas/heavy/`
  (git-ignored).
- BUILT (2026-11-24, after play on the phone; owner: "Rotation is a tit bit
  too slow. Also, the two quick pushes doesn't work well since I cannot
  trigger the second rotation, and I also think we would probably need to
  figure out a way for turning multiple times continuously. Lifting finger
  is okay but must be smooth and intuitive to use." and "the rings
  indicator should always have origin in the center of mirror, even when it
  is tilted, just use the lit up orb to indication current position"; the
  plan was approved: "Yes, build it"). The cause of the lost second push:
  the next push started where the thumb came back, so the way back to the
  press counted as a push the other way and turned the mirror back. Now
  the start of the next push follows the thumb back, as far as the press.
  A push that holds keeps the mirror turning at full speed, one step after
  another, with a tick at each; when the thumb comes back or lifts, the
  mirror stops on the next facing it can reach smoothly (changed
  2026-11-25: on the facing it turns to then). A press while the
  last turn still moves joins that turn, so quick taps and pushes make one
  smooth turn and one change (one Undo). The level ring of the eight
  facings goes through the mirror's centre at full size, also when the
  mirror is tilted; the dark dot moves on it. The turn is a little faster
  (0.53 s for a step). Review: `test-output/polish/turn-ideas/joystick/`
  (git-ignored).
- BUILT (2026-11-25, after play on the phone; owner: "It feels nice, with
  some rotation snapping being non confident / uncertain enough." and "the
  turn ring is now shown even if the mirror is tilting when the mirror
  reaches the middle point. Also, the tilting of the mirror should be full
  360º" and "make sure the indication ring and components fades in and
  out"). The cause of the turn ring in a tilt: the sign showed the tilt
  ring only while the tilt went to another pitch than where the hold
  began, so a tilt back to that pitch (often the level middle) showed the
  level ring. Now the last push of the hold chooses the ring (`aim_ring`).
  The tilt goes all the way round, as the turn does: a held tilt rolls the
  pane on past the sky about its own level axis, and the upright ring
  shows the eight tilts. A pane past the sky faces back; the level ring
  shows its dark dot on that side. One whole roll is no change. The sign
  (the rings, the dots, the lines, the dark dot and the pale ring) fades in
  when a knob is held (0.36 s) and fades out after the change (0.24 s).
  Before, it showed at once, and the apply cut its fade-out. The uncertain
  snap: see the next entry. Review:
  `test-output/polish/turn-ideas/full-tilt/` (git-ignored).
- BUILT (2026-11-25; owner, asked which snap felt uncertain: "Overshoot on
  release"). Cause, measured: while a push holds, the next step is added
  about 20 degrees before each facing, so that the mirror does not slow
  down; when the thumb came back, the mirror went on for 21 to 60 degrees.
  A thumb that came back at 0.4 s, with the mirror at 38 degrees, gave 90
  degrees, not 45. Now, when the thumb comes back or lifts, the mirror
  stops on the facing it turns to then, and starts no step that the hold
  added; it never stops short of what the pushes asked for. It brakes as
  hard as that stop needs, up to `TURN_STOP` (20 radians per second per
  second, 8 degrees from full speed; the normal brake is 9); a facing
  nearer than one frame of travel stops it at once. The release gives no
  tick, because a tick is a new step. Seen at phone size: thumb out 0.4 s,
  mirror at 33 degrees, stops at 45 (before: 90); thumb out 0.5 s, mirror
  at 47, stops at 90; thumb out 1.0 s, mirror at 116, stops at 135.
  Review: `test-output/polish/turn-ideas/release-stop/` (git-ignored).
- BUILT (2026-11-25, after play on the phone; owner: "The slide up and down
  button should have the same behaviour as the rotation, holding should
  move to that direction continuously. Also, tapping the rotation button
  should probably not rotate the mirror since there are no direction
  indication."). Three blind advisors (touch feel, puzzle design, code
  risk) agreed with both. They also found that the old lift knob needed
  40 points of drag for each half step, so the full height (about 480
  points) went past the bottom of the screen. The plan was approved
  ("Approve the plan"). Now the lift knob works as the turn knob on its
  one axis: a push up or down of 16 points is one step of half a unit, a
  held push keeps the mirror going, and when the thumb comes back or
  lifts, the mirror stops on the step it goes to. A push to the side gives
  nothing. The height has the heavy motion of the turn, scaled so that a
  step takes as long (about 0.53 s; at most about 1.5 units a second). A
  press while the last lift still moves joins it (one change). At the
  edge of the placement area it stops on the last step, with one firmer
  bump and the edge hint. A tap on either knob changes nothing: the
  press shows the knob's sign, which now stays at least 1 s, so a tap is
  a look at what the knob does. The prompts say "Push the knob sideways
  to turn" and "Push the knob down to lower"; the finger mark on a knob
  shows a short push and a hold. Lost: the quick quarter turn by a tap.
  Review: `test-output/polish/lift-push/` (git-ignored).
- BUILT (2026-11-26, after play on the phone; owner: "Feels like the
  height change of the mirror is too slow."). Cause: a step of height took
  as long as a step of turn, but it is a much smaller move on the screen
  (about 20 to 25 points). Now the lift goes at twice the pace
  (`LIFT_PACE` 2): one step takes about 0.4 s (before 0.55), a held push
  goes about 6 steps a second (before 3), and the full height of "Only
  the ground" (8 units) takes about 3 s (before 5.5). The turn is not
  changed.
- OPEN (2026-11-26; owner: "position hint dots seems too concentrated, for
  both move and height. They are correct tho. I was thinking either shrink
  them, or to not allow non-half step positions."). The half steps stay:
  the copy moves two units for each unit of the mirror, so whole-unit
  steps would let a copy reach only every second block place, and the
  stages use half places. Proof of three ways (smaller dots; a ruler with
  whole units as now and half units small and faint; only the stops within
  one unit), at about the phone's pixel density:
  `test-output/polish/dots/` (git-ignored). Note: the sign of a held knob
  draws each dot at 2.4 points (`_draw_sign` in
  `world/placement_guide.gd`); the style's size does not change it.
  2026-11-27, the owner: "Can we ask Fable agents to reimagine the system,
  with codex image mockups?" Three blind Fable designers (lenses: the look,
  the puzzle read, touch and motion) gave three concepts, with image
  mockups (not engine proofs): "Rain rings" (no overlay; at each step the
  light pool on the water leaves a ring; height as rings round the pool),
  "Seam light" (where a copy meets a stone at the same height, the shared
  edge glows; at the mirror only its stop and the next stop each way) and
  "The Beat" (the mirror's stop, an open ring on the next stop, a short
  fading trail; a tick ladder beside the lift knob). All three remove the
  field of dots and the axis lines; two chose the same core (the mirror's
  stop and the next stop in each direction, four for a move, two for a
  lift). The agent's advice: an engine proof of that core first, then
  each addition alone. Review: `test-output/polish/sign-ideas/index.html`
  and `sign-ideas-sheet.jpg` (git-ignored). The owner decides.
- OPEN (2026-11-19): a warning before a fall. Owner: "would be nice but it
  depends on how we achieve it. Don't want it to hinder the puzzle
  experience." OPEN: what a block that comes onto her does (now: dark, then
  back; two advisors asked for a rule). OPEN: with no riding, the copy
  slides under her feet again while the finger is down.
- FOUND (2026-11-19, the rule-clarity advisor; checked): nothing shows how
  far the mirror reaches. The guides along its normal have an alpha of
  0.005 and fade within about 2.7 units (`world/mirror_guides.gdshader`).
  The player learns the depth only from results. This goes with the doubt
  of 2026-11-16 below and with how the mirror appears.
- FOUND (2026-11-19, the owner's seven screenshots of `01_route`): all had a
  pane on a diagonal. Two faults in the drawing, both fixed: a stone cut on a
  slant was drawn on the wrong side of its cut, and drop shadows were boxes
  (on a diagonal piece they were too large, or hung in the air). Four of the
  screenshots (4, 5, 8, 9) show the rule itself: a diagonal pane splits a
  block into a stone half and a glass half, shows flat cut faces, and turns
  the row of copies by 90°. Whether that reads as a reflection is for the
  owner.
- DECIDED (owner, 2026-11-17): the pale winter look is the look of the
  game, and the copy is mirror glass, not summer: "Copy as cool glass seems
  to fit the story more", then "C, mirror glass", then "Yes, build it". The
  pond's ice is the first mirror and the sister shows behind a frost pane,
  so the copy is the thing seen in glass. The lit window of the garden's
  house is the one warm light. Built 2026-11-17 (`docs/art/STYLE.md`). This
  answers the doubt above that the summer copy does not look like a
  reflection. The doubt that the mirror reads as a portal stays open.
- OPEN (owner's doubts, 2026-11-16): the player cannot tell what the mirror
  can copy or hide and what it cannot, nor why. That the mirror replaces
  what is behind it is not well shown: is the rule sound, is an alternative
  better, and how is it shown? A ring as the goal is odd.
- OPEN (owner, 2026-11-16, after the rules proof): a lane on the water is
  not enough, because a mirror can lie flat and copy up or down; the space
  that the mirror changes needs a mark in three dimensions, or a different
  mark. The image of a block in the water may be mistaken for the mirror's
  copy; the owner's two ideas are a more scattered image, or blocks that
  stand some distance above the water. Not decided.
- DRAFT (owner's thought, 2026-11-16, after the shaft proof): the trouble
  comes from the scoped mirror. The first version had a mirror that spanned
  the whole world, and its image read as a true reflection, but it limited
  play. A scoped mirror gives the puzzles more freedom, but it shows an
  image outside the glass, and no person knows that from life. The copy
  rises from the ground only because the pane does; the pane and its image
  could appear at an instant. Not decided.
- DRAFT (owner's experiment, 2026-11-16): the reflection shows only on the
  face of the pane and the other face is an opaque plane; a button changes
  to the reflected world, where only the copy stands in the world and the
  original stage shows only in the glass. The rules stay. The owner expects
  that the whole puzzle is then hard to see, and leaves that for later. A
  sketch and its frames are in `VALIDATION.md`. Not decided.
- DRAFT (owner's proposal, 2026-11-16, after the experiment): the image in
  the glass is cleaner and clearer, but two views by a button are not. In
  place of the button, the view follows the girl: when she crosses the
  mirror, she sees the other world. The other world shows in her world as a
  faded form (a shadow or a silhouette), also in the place of the ground
  that the copy replaced, so that the player sees where a tap can send her.
  Each world has its tint (the owner's example: blue for the normal world,
  red for the reflected world). If more levels of reflection come later,
  each deeper level is darker. The owner's answers: her world follows the
  ground below her feet, and the answer must also hold for a flat pane and
  for a fall (the sketch uses the space behind the glass, which gives both);
  the glass keeps a clear image; the tint is on the whole view. After the
  first frames, the owner: the faded form must be more of a phantom and look
  as it does in the other world; and each world keeps its colour, so a
  thing of the blue world stays visibly blue in the red world, and a thing
  of the red world stays visibly red in the blue world. A sketch and its
  frames are in `VALIDATION.md`. Not decided.
- DRAFT (owner's play test with a visual designer, 2026-11-17): the proofs
  that explain the cut (the lane, the shaft, the glass, the view that
  follows the girl) came from too much attention to one question. A player
  who moves the mirror understands that it cuts off the things behind it;
  that is natural enough. A tint on the whole world is correct only if the
  reflected world has its own things to use, and then the mirror is a
  portal. For the game as it is, the world keeps its colours and only the
  reflected structures have a different look. That look must improve: now
  it reads as a structure that is not confirmed, not as a reflection, so
  red is possibly not the colour. Planned for later stages: puzzles that
  use the properties of a mirror image (a mechanism turns the opposite way
  in the image; a button with a left arrow has an image with a right arrow,
  which moves an absolute that way). The best thing in the game is to move
  the mirror and see the reflected structures change at once. Turns of 45
  degrees looked and played much better in an earlier trial and come back
  later. Two limits now. Control: a drag keeps one axis until release; the
  turn handle often lies on a platform and is not easy to use; the mirror
  cannot turn about all three axes, which is the vision. Earlier trials (a
  button for move or turn, controls on the mirror) went too far toward a
  3D program. Controls on the mirror are acceptable if they are clear, easy
  and look good. Visual: how the reflection shows, and how the girl looks
  in each area. Not decided.
- DECIDED (owner's design of the control, 2026-11-17), built: a pill bar that
  floats in the horizontal centre, below the centre of the screen; the stage
  moves up so that the stage and the bar together are centred. Before the
  mirror is up, a round mirror button is in the bar's place; a press changes
  it slowly and quietly into the bar. The bar has three round knobs: move,
  turn, lift. A knob is held and the finger then uses the full screen; the
  distance from the press gives the amount. Move: on the ground. Turn: a
  horizontal slide turns the mirror in steps (left is clockwise) and a
  vertical slide tilts it in steps. Lift: a vertical slide. Each step gives
  a haptic. A held knob changes shape toward the drag, with resistance near
  its limit. The bar is glass, as the liquid glass of iOS; the knobs and
  the other buttons are opaque white with a highlight, as ceramic. A round
  button in pastel red, near the bar, removes the mirror. No arrow shows the
  side of the copy; the look of the reflection does that later. The aims:
  one way for all controls, no finger on the mirror, nothing that overlaps
  the stage. The owner played the sketch (2026-11-17): "The control works
  great." The owner's
  corrections: the movement and the rotation a little slower, because they
  were abrupt; the knobs more rigid, with less change of shape; the bar a
  little below the stage for each window size; more ease in the change
  between the mirror button and the bar. After the second play: the bar
  nearer the bottom of the screen, between the stage and the bottom, and the
  control (mirror button, bar, knobs) larger. After the third play: the size
  and the place are "correct now". The owner then approved the build into
  the game: the bar is the one control of the mirror (`world/mirror_bar.gd`),
  and the drag on the glass, the arrow and the corner button are removed.
  The rules are in `GAME_DESIGN.md`.
- DECIDED (owner, 2026-11-17), built: the mirror, when it is raised for the
  first time on a stage, stands in front of the girl, in the direction she
  looks.
- DECIDED (owner, 2026-11-17), built: no view buttons at the bottom left.
  The sideways swipe turns the view; it is sufficient. Keys Q and E stay on
  desktop.
- DECIDED (owner, 2026-11-17), built: the prompts. The card in the top
  left with long text "does not feel good and user loses focus". The owner
  agreed to these rules. (1) A prompt is one line, centred, just above the
  bar: where the player looks and where the thumb is. (2) It has no card; it
  is written on the world, as the stage's name is. (3) It is short: a verb
  first, six words or fewer. It says what to do; the stage shows what the
  mirror does. Prompts that only explain a rule are removed. (4) The control
  that the line names answers: ripples leave it, and for a knob a finger
  mark comes down on it and slides the way of the gesture. (5) The line goes
  when the player does the action.
- DECIDED (owner, 2026-11-17), built: the Undo button is to the left of the
  bar.
- OPEN: vistas between puzzles with a low camera, perhaps as the opening.

## Sound

- DECIDED (2026-10-30): mysterious, holy, hopeful, sad, grieving: light
  after rain (see the top). References: Nier Automata, "City Ruins - Rays of
  Light", "Copied City", "Weight of the World".
- OPEN: what the mirror itself sounds like. First try (2026-10-31, agent):
  glass and ice in D Dorian; raising blooms into a soft chord, lowering
  resolves down, turning is a breath and a rising fourth. Nobody has
  listened yet; a Lyria draft theme is in `art_trial/audio/`.

## Money

- OPEN: the price model. DRAFT: one price, no in-game purchases (the "never"
  list rules out a cash grab).

## Platforms

- DECIDED (2026-10-06): Steam first, then iPhone and iPad, then Android.
- OPEN: controllers and the Steam Deck.

## Never

- DECIDED (2026-10-30): AI slop. The defence is craftsmanship and attention
  to detail, fine-tuned with the owner.
- DECIDED (2026-10-30): a cash-grab game, such as Kingshot.
- DECIDED (2026-10-30): grind.
- DRAFT: no scores or timers (stated in `GAME_DESIGN.md`, never dated).

## Process

DRAFT (2026-10-29), from the owner's feel and vision review:

```
vision and pillars ──> feature brief ──> grey-box feel test ──> build
   (interview)        (1 page, owner      (clip + owner       (to the
                       approves)           plays on Mac)       slice bar)
```

- A one-page brief before any feature: the fantasy, why it sparks joy, the
  mechanics that make it fun, links to other systems, what pulls the player
  on, and the art, sound, UI and motion it needs.
- One vertical slice first: the 2026-10-06 milestone, one chapter at release
  quality. It sets the quality bar.
- One UI and motion system, used on every screen.
- Feel reviews with video (Godot Movie Maker), not stills, plus the owner
  playing on a Mac.
- Sound from the first build of each feature.

## Order of work

DECIDED (2026-10-30): the owner approved this order of work.

1. **Write down how it should feel.** Fill in "Moment-to-moment feel" for the
   slice's verbs (walk, raise, slide, lower, fall, reach, move on), from
   light after rain. The owner approves it.
2. **The UI and motion system** (the first structural piece, below).
3. **The first five minutes** (DECIDED 2026-10-30, replaces the two-mirror
   spike here): the title, the wordless prologue scene, and the first garden
   place, as one continuous grey-box stretch with its feel and sound. See
   [its brief](briefs/first-five-minutes.md). The two-mirror finale waits;
   if the real mechanic cannot make the endless path, the end stage gets
   its own programming.
4. **The rest of the slice in grey box.** Chapter 1, "The Garden",
   designed from the story, taught without text, and readable
   before any art. One feature brief per new piece, approved before code.
   The stuck-on-a-ledge bug (playtest 2, fix 9) is fixed here, since the
   slice reuses the fall.
5. **Sound and music early.** A Lyria trial of the main theme against light
   after rain, and the interaction sounds, while the slice is still grey.
6. **Art on the slice.** The garden look in winter, the copy in mirror
   glass, the pond, her and the mittens.
7. **Feel reviews** at each step: a Movie Maker clip, and the owner playing
   on a Mac.

### The first slice

The title, the prologue and chapter 1, "The Garden", about 15 minutes. It is
the 2026-10-06 milestone (one chapter at release quality) with the story now
chosen. Done when: five first-time players finish it without help and can say
what happened; every screen holds up beside Monument Valley; nothing is
placeholder; and the owner says it feels like light after rain.

### The UI and motion system

- **Style:** `ui/style/` holds the tokens (colours, one typeface and its
  sizes, spacing, corner radius), one drawn icon set with one stroke weight,
  and a Godot `Theme` built from them. Every button and panel uses the theme;
  no per-button style overrides.
- **Motion:** one `Motion` module with a few named verbs and fixed timings
  and easing: appear, dismiss, press, settle, reveal, breathe, and the scene
  transition. Every tween in the game goes through it (about 20 today).
- **Screens:** the title (the first place from afar, tap to begin), pause and
  settings, the chapter card and the end, all built from the same pieces.
  The HUD becomes icons only.
- **Review:** a style gallery scene with every token, icon, button and
  motion, which the owner opens on a Mac; stills of each screen; and one
  Movie Maker clip of the motion verbs and of the title into the prologue.
- Status (2026-10-30): the look test is built and waits for the owner:
  `ui/style/` (`UiStyle`, `UiIcons`, the gallery scene), `ui/motion/motion.gd`
  (`Motion`), the typeface (see below, in `assets/fonts/`). Still and clip: `docs/ui-style/`. No screen uses it yet.
- DECIDED (2026-10-30): the owner approved the colours, the icons and the
  motion timings.
- DECIDED (2026-10-30): the typeface is Spectral (SIL Open Font License),
  chosen from eleven options (`docs/ui-style/typeface-options.jpg`) for its
  feel, its spacing and its clear weights. Light for titles and chapter
  names, Regular for the few other words.
- DECIDED (2026-10-30): use UI elements sparingly in the game. Show a control
  only when it can be used and is needed.
- Status (2026-10-30): every screen now uses the system, per
  [the screens brief](briefs/ui-screens.md): the title from afar with no
  buttons, icon-only HUD, frost prompt and hints, stage names on the world,
  the settings panel and the end card. Every tween goes through `Motion`.
  Stills and a clip: `docs/ui-style/screens/`. Waits for the owner's Mac
  review.

## Open tensions

Named after round 1 (2026-10-30), each with a recommendation.

1. **"Never AI slop" against "agents make all the art and music."** The
   largest risk. Slop reads as generic, inconsistent and without intent.
   DRAFT recommendation: a small, strict visual language built in the engine
   (kit, shaders, light) rather than generated images shipped as they are;
   the owner approves each screen; recurring motifs, not variety; music
   directed around one theme, with Lyria output curated, not used raw.
2. **The mirror today is a copy tool; the vision wants a window into another
   dimension.** Today the other side copies blocks that are already visible,
   and the puzzles are spatial bookkeeping. DRAFT recommendation: test,
   in grey box, a mirror whose other side shows a different version of the
   place (her past, or the life that might have been). Keep the current rules
   until the test shows it plays better.
3. **Insight against misreading.** Both playtests found the difficulty in
   reading height and distance, not in ideas. That breaks pillar 1. DRAFT
   recommendation: legibility is a first-class feature of the slice, not a
   later fix.
4. **A Nier-style reveal in a nearly wordless game.** A reframing twist
   usually needs words. DRAFT recommendation: carry it with a change the
   player has already learned to read, such as the mirror's other side
   turning out to be the real world.
5. **The garden look and a tragic past.** They fit: overgrowth is time since
   the loss; the copy in full bloom is what was. DRAFT recommendation: keep
   the garden and tie its two states to the story.
6. **The two-mirror finale needs a second mirror.** The game has one mirror
   today. DRAFT recommendation: plan the mechanic arc backwards from the
   finale, so a second mirror arrives a chapter or two before it, and test
   two facing mirrors in grey box early, since it is the game's biggest
   promise. DECIDED (2026-10-30): no early spike; if the real mechanic
   cannot do it, the end stage is programmed for it.
7. **Grim against light-hearted.** DRAFT recommendation: a tone curve, grim
   through the middle and lifting at the end, with small moments of light
   throughout so the dark never becomes despair.
8. **Deemo.** A small girl, a loss in the family, and a reveal about who is
   really gone is Deemo's combination. DRAFT recommendation: the twins and
   the mirror's rules make it ours, and the inversion (she is the one who
   died) differs from Deemo's; keep her look from echoing Deemo's girl too
   closely, and tell the reveal through the mirror, not a cutscene.
9. **One sitting against phone sessions.** DRAFT recommendation: short
   chapters that each end on a beat serve both.

### Where today's game breaks the draft pillars

- Text prompts teach every stage, and refusal messages are sentences:
  against "felt, not told".
- Stages are named after rules ("Only the ground") and are cubes in a void,
  with a ring as the goal: no place, no memory, against pillars 2 and 4.
- The tutorial is a separate six-stage block before any story.
- The HUD uses words ("Undo", "Restart stage") and four unrelated button
  styles.
- Stages 4 to 6 were solved by trial and error in the blind playtest.
