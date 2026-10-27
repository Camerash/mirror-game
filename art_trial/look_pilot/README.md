# Look pilot, 2026-10

One small level-like diorama, built in the game project, shown in several
looks. Findings: [`docs/look-pilot.md`](../../docs/look-pilot.md).

- `diorama.gd` builds the fixed diorama: blocks, the mirror and its copy,
  the gate and bonsai from `models/` (rebuilt from
  `art_trial/pipeline_pilot/godot`), the goal ring and the traveller.
- `look.gd` is the base look (the grey box) and its helpers. Each file in
  `looks/` overrides the environment, lights and materials.
- `shaders/` holds the look shaders: the screen-space backdrop, the
  underside shade, the mirror glass, and the ink surface, outline and wash.
- `capture.gd` renders each look from the game's four views and at the hero
  framing:

  ```sh
  xvfb-run -a godot --path . --rendering-method mobile -s res://art_trial/look_pilot/capture.gd -- --looks greybox,ceramic,ink,twilight --out /abs/dir
  ```

- `boards/` holds the style-board prompts and `board.py`, which restyles the
  grey-box render with a Gemini image model. It reads `GEMINI_API_KEY`:

  ```sh
  cat boards/common.txt boards/ink.txt > prompt.txt
  python3 -I boards/board.py gemini-3.1-flash-image greybox_hero.png prompt.txt board_ink.png
  ```

Nothing here is used by the game.
