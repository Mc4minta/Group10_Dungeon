#!/usr/bin/env bash
# One command: art -> mem/player.mem -> previews -> iverilog sprite test -> summary.
#   ./scripts/update_sprites.sh
# Works with incomplete art (missing/empty frames use the old art, with warnings).
cd "$(dirname "$0")/.." || exit 2
PY=python3; command -v python3 >/dev/null 2>&1 || PY=python

echo "== 1/3 build mem/player.mem + previews"
$PY scripts/build_player_mem.py --preview
rc=$?
if [ $rc -eq 2 ]; then echo "== STOP: config or fallback file is broken (see ERROR above). mem/player.mem was NOT changed."; exit 2; fi
[ $rc -eq 1 ] && echo "== NOTE: an art file could not be read (see ERROR above); its frames use old art."

echo; echo "== 2/3 iverilog sprite test (player_rom reads mem/player.mem)"
if command -v iverilog >/dev/null 2>&1; then
  if ./scripts/run_sim.sh sprites > /tmp/update_sprites_tb.log 2>&1; then tail -3 /tmp/update_sprites_tb.log
  else cat /tmp/update_sprites_tb.log; echo "== SPRITE TEST FAILED"; exit 3; fi
else
  echo "iverilog not found - skipped (install it, or run on WSL)"
fi

echo; echo "== 3/3 python checks"
$PY tests/test_sprite_pipeline.py 2>&1 | tail -3

echo
echo "Done. Look at:  preview/all_forms.png   preview/form1_contact.png ... form4_contact.png"
echo "                preview/form<N>_<dir>_walk.gif   (red border = old art / fallback)"
echo "Changed frames are listed above under 'Changed since previous mem/player.mem'."
echo "Rebuild the board/sim: just run your normal flow - mem/player.mem is already updated."
exit 0
