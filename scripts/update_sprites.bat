@echo off
rem One command: art -> mem\player.mem + mem\tileset.mem -> previews -> iverilog sprite test -> python checks.
rem   scripts\update_sprites.bat
cd /d "%~dp0\.."
echo == 1/4 build mem\player.mem + previews
python scripts\build_player_mem.py --preview
set RC=%ERRORLEVEL%
if %RC%==2 (echo == STOP: config or fallback file is broken, see ERROR above. mem\player.mem was NOT changed.& exit /b 2)
if %RC%==1 echo == NOTE: an art file could not be read, see ERROR above. Its frames use old art.
echo.
echo == 2/4 build mem\tileset.mem + previews
python scripts\build_tileset_mem.py --preview
if %ERRORLEVEL%==2 (echo == STOP: tileset config broken, mem\tileset.mem NOT changed.& exit /b 2)
echo.
echo == 3/4 iverilog sprite test
where iverilog >nul 2>nul
if %ERRORLEVEL%==0 (
  pushd mem
  iverilog -g2012 -I..\rtl -I..\sim -o ..\sim\tb_sprites.vvp ..\sim\tb_sprites.v ..\rtl\roms.v ^&^& vvp ..\sim\tb_sprites.vvp
  popd
) else (
  where wsl >nul 2>nul
  if %ERRORLEVEL%==0 (wsl bash -c "./scripts/run_sim.sh sprites") else (echo iverilog and WSL not found - sprite test skipped)
)
echo.
echo == 4/4 python checks
python tests\test_sprite_pipeline.py
python tests\test_tileset_pipeline.py
echo.
echo Done. Look at: preview\tileset_all_floors.png preview\tileset_rooms.png (map)  preview\all_forms.png  preview\form1_contact.png ... form4_contact.png
echo        preview\form^<N^>_^<dir^>_walk.gif  (red border = old art / fallback)
echo Changed frames/tiles are listed above under "Changed since previous".
