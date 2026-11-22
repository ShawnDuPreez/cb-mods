@echo off
rem Puts the mod folder into the Black Ops 3 folder's mods directory as a junction,
rem so the Mod Tools build straight into this project.
rem
rem   install.bat                 use the default Steam folder
rem   install.bat "<bo3 folder>"  use that folder (the one that holds BlackOps3.exe)
rem   install.bat /remove ["<bo3 folder>"]   take the junction out again
setlocal

set "MOD_NAME=more_players"
set "SOURCE=%~dp0%MOD_NAME%"
set "ACTION=link"

if /i "%~1"=="/remove" (
	set "ACTION=remove"
	shift
)

set "GAME=%~1"
if "%GAME%"=="" set "GAME=%ProgramFiles(x86)%\Steam\steamapps\common\Call of Duty Black Ops III"

if not exist "%GAME%\BlackOps3.exe" (
	echo No BlackOps3.exe in "%GAME%".
	echo Pass the Black Ops 3 folder as an argument. In Steam: right-click the game, Manage, Browse local files.
	exit /b 1
)

if not exist "%SOURCE%\zone_source" (
	echo Mod folder is missing: "%SOURCE%"
	exit /b 1
)

set "TARGET=%GAME%\mods\%MOD_NAME%"

if "%ACTION%"=="remove" (
	if exist "%TARGET%" (
		rem rmdir without /s removes a junction and leaves what it points at alone
		rmdir "%TARGET%"
		echo Removed "%TARGET%"
	) else (
		echo Nothing to remove at "%TARGET%"
	)
	exit /b 0
)

if exist "%TARGET%" (
	echo "%TARGET%" already exists. Run install.bat /remove first if it is an old junction.
	exit /b 1
)

if not exist "%GAME%\mods" mkdir "%GAME%\mods"
mklink /J "%TARGET%" "%SOURCE%"
if errorlevel 1 (
	echo Could not create the junction. Copy the "%MOD_NAME%" folder into "%GAME%\mods" by hand instead.
	exit /b 1
)

if not exist "%GAME%\bin\linker_modtools.exe" (
	echo The Mod Tools are not installed in this folder: bin\linker_modtools.exe is missing.
)
echo Done. Build it with the Mod Tools Launcher, see README.md.
endlocal
