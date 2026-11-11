# Chunk patterns

The built-in patterns are written in a text DSL in `scripts/gameplay/track/pattern_data.gd`
(the legend is at the top of that file). Browse them with `scenes/obstacles/pattern_preview.tscn`.

To add patterns without touching code, create `ChunkDef` resources in this folder (Inspector:
id, difficulty, min / max difficulty, weight, tags, and exactly 10 `rows` of 3 characters) and
add them to `config/game_config.tres > Generation > extra_chunk_defs`.

Every pattern is checked by the solvability validator when the game loads; problems are printed
as warnings and listed in the pattern preview.
