@echo off
rem Check the whole project (generated files, Python tests). The iverilog suite needs WSL: wsl bash scripts/check_all.sh
cd /d "%~dp0\.."
for %%b in (player tileset monster boss puzzle) do python scripts\build_%%b_mem.py >nul
python scripts\build_maps.py >nul
python scripts\make_music.py >nul
git status --porcelain -- mem rtl
for %%t in (tests\test_*.py) do (echo %%t & python -W error %%t 2>&1 | findstr /R "^OK FAILED Ran")
echo For the full iverilog suite run: wsl bash scripts/check_all.sh
