@echo off
rem One command: art -> mem\player.mem -> previews -> iverilog sprite test -> summary.
rem   scripts\update_sprites.bat
cd /d "%~dp0\.."
echo == 1/3 build mem\player.mem + previews
python scripts\build_player_mem.py --preview
set RC=%ERRORLEVEL%
if %RC%==2 (echo == STOP: config or fallback file is broken, see ERROR above. mem\player.mem was NOT changed.& exit /b 2)
if %RC%==1 echo == NOTE: an art file could not be read, see ERROR above. Its frames use old art.
echo.
echo == 2/3 iverilog sprite test
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
echo == 3/3 python checks
python tests\test_sprite_pipeline.py
echo.
echo Done. Look at: preview\all_forms.png  preview\form1_contact.png ... form4_contact.png
echo        preview\form^<N^>_^<dir^>_walk.gif  (red border = old art / fallback)
echo Changed frames are listed above under "Changed since previous mem/player.mem".
