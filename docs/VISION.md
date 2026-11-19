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
Sound: a rising or falling interval. Today: a 0.22 s turn.

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
- OPEN (2026-11-19), found in the same check, not changed: when a slide or a
  turn takes her part of the stone out of the pane's frame, she goes back
  to her start place in one frame and stays in the air there until the
  release. Then she falls. The owner decides if she must fall from the
  place where the copy left her.
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
