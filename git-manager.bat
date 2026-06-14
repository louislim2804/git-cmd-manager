@echo off
setlocal enabledelayedexpansion

:: ============================================================
::  git-manager.bat - Solo Dev Git Toolkit
::  Usage: drop this anywhere, call it from any project folder
::  Or add to PATH so you can call it from anywhere
:: ============================================================

set GITHUB_USERNAME=YOUR_GITHUB_USERNAME
set GITHUB_TOKEN=YOUR_PERSONAL_ACCESS_TOKEN

:MENU
cls
echo.
echo  ================================
echo   GIT MANAGER - %cd%
echo  ================================
echo.
echo   [1]  Status         - See what changed
echo   [2]  Save + Push    - Commit and upload to GitHub
echo   [3]  Pull           - Get latest from GitHub
echo   [4]  New Branch     - Create and switch to a new branch
echo   [5]  Merge Branch   - Merge a branch into current
echo   [6]  Switch Branch  - Jump to another branch
echo   [7]  View History   - Pretty commit log
echo   [8]  First-Time Setup - Init repo and push to GitHub
echo   [9]  Unstage Files   - Remove files from staging area
echo   [10] Edit .gitignore - Update what Git ignores
echo   [0]  Exit
echo.
set /p CHOICE=  Pick an option: 

if "%CHOICE%"=="1" goto STATUS
if "%CHOICE%"=="2" goto SAVE_PUSH
if "%CHOICE%"=="3" goto PULL
if "%CHOICE%"=="4" goto NEW_BRANCH
if "%CHOICE%"=="5" goto MERGE_BRANCH
if "%CHOICE%"=="6" goto SWITCH_BRANCH
if "%CHOICE%"=="7" goto HISTORY
if "%CHOICE%"=="8" goto FIRST_TIME
if "%CHOICE%"=="9" goto UNSTAGE
if "%CHOICE%"=="10" goto EDIT_GITIGNORE
if "%CHOICE%"=="0" goto EXIT

echo  Invalid option. Try again.
pause
goto MENU


:: ============================================================
:STATUS
:: ============================================================
cls
echo.
echo  === STATUS ===
echo.
git status
echo.
echo  --- Recent commits ---
git log --oneline -5
echo.
pause
goto MENU


:: ============================================================
:SAVE_PUSH
:: ============================================================
cls
echo.
echo  === SAVE + PUSH ===
echo.

:: Step 1: Ensure blocked-extensions config exists next to this script
set CONFIG_FILE=%~dp0git-manager-ignore-ext.txt
if not exist "%CONFIG_FILE%" (
    echo  No blocked-extensions config found. Creating default at:
    echo  %CONFIG_FILE%
    echo.
    (
        echo # git-manager blocked extensions
        echo # Files with these extensions are NEVER committed to GitHub
        echo # Add one extension per line. Lines starting with # are comments.
        echo.
        echo # Executables and binaries
        echo .exe
        echo .dll
        echo .bin
        echo .msi
        echo.
        echo # Media files
        echo .mp4
        echo .mp3
        echo .wav
        echo .mov
        echo .avi
        echo .mkv
        echo .flac
        echo .aac
        echo .srt
        echo.
        echo # Archives
        echo .zip
        echo .rar
        echo .7z
        echo .tar
        echo .gz
    ) > "%CONFIG_FILE%"
    echo  Default config created.
    echo.
)

:: Step 2: Stage everything first (state must change before we can read it)
git add .

:: Step 3: Auto-block files whose extensions are in the config
:: (Per-file work is done in the :BLOCK_ONE subroutine to safely handle
::  filenames with spaces, parentheses, and special characters.)
echo  Checking staged files against blocked-extensions list...
echo.
set BLOCKED_COUNT=0
git diff --cached --name-only > "%TEMP%\staged.txt" 2>nul
for /f "usebackq delims=" %%F in ("%TEMP%\staged.txt") do call :BLOCK_ONE "%%F"
if !BLOCKED_COUNT! gtr 0 (
    echo.
    echo  !BLOCKED_COUNT! file^(s^) auto-removed from staging.
    echo  To change blocked types, edit: %CONFIG_FILE%
    echo.
) else (
    echo  No blocked file types found. Good.
    echo.
)

:: Step 4: Warn about any remaining files over 5MB
set LARGE_COUNT=0
git diff --cached --name-only > "%TEMP%\staged.txt" 2>nul
for /f "usebackq delims=" %%F in ("%TEMP%\staged.txt") do call :CHECK_LARGE "%%F"
if !LARGE_COUNT! gtr 0 (
    echo.
    echo  WARNING: !LARGE_COUNT! large file^(s^) detected ^(over 5MB^).
    echo  These are usually generated output or downloaded tools, not source code.
    set /p LARGE_OK=  Unstage all large files? ^(y/n^): 
    if /i "!LARGE_OK!"=="y" (
        git diff --cached --name-only > "%TEMP%\staged.txt" 2>nul
        for /f "usebackq delims=" %%F in ("%TEMP%\staged.txt") do call :UNSTAGE_LARGE "%%F"
        echo.
    )
)

:: Step 5: Check if anything remains staged
git diff --quiet --cached 2>nul
if not errorlevel 1 (
    echo  Nothing left to commit after filtering.
    set HAS_PENDING=
    for /f %%i in ('git log origin/main..HEAD --oneline 2^>nul') do set HAS_PENDING=%%i
    if defined HAS_PENDING (
        echo  You have unpushed commits. Pushing now...
        echo.
        git push 2>"%TEMP%\push_err.txt"
        if errorlevel 1 (
            findstr /i "upstream" "%TEMP%\push_err.txt" >nul
            if not errorlevel 1 (
                echo  No upstream set. Linking to origin/main...
                git push --set-upstream origin main
            ) else (
                findstr /i "fetch first" "%TEMP%\push_err.txt" >nul
                if not errorlevel 1 (
                    echo  Remote has changes you don't have locally. Pulling first...
                    git pull --rebase
                    git push
                ) else (
                    type "%TEMP%\push_err.txt"
                )
            )
        )
    ) else (
        echo  Everything is already up to date on GitHub.
    )
    echo.
    pause
    goto MENU
)

:: Step 6: Show final preview and ask confirmation
echo  Files that will be committed:
echo  --------------------------------
git diff --cached --name-status
echo  --------------------------------
echo.
set /p PREVIEW_OK=  Commit these files? ^(y/n^) [0=Back]: 
if "%PREVIEW_OK%"=="0" (
    git restore --staged .
    echo  Unstaged everything. Back to menu.
    pause
    goto MENU
)
if /i not "%PREVIEW_OK%"=="y" (
    :: Inline recovery options so user doesn't have to go back to menu
    echo.
    echo  What do you want to do?
    echo   [1]  Unstage a specific file or folder
    echo   [2]  Edit .gitignore ^(then re-run Save + Push^)
    echo   [0]  Back to menu ^(unstages everything^)
    echo.
    set /p RECOVER=  Pick an option: 
    if "!RECOVER!"=="1" (
        echo.
        echo  Type the filename or folder exactly as shown above.
        echo  Example: ytget.ps1   or   transcript download/
        echo.
        set /p UFILE=  File or folder to unstage: 
        if not "!UFILE!"=="" (
            git restore --staged -- "!UFILE!"
            echo  Unstaged: !UFILE!
            echo  Re-running preview...
            echo.
            pause
            goto SAVE_PUSH
        )
    )
    if "!RECOVER!"=="2" (
        notepad .gitignore
        git restore --staged .
        echo  .gitignore updated. Unstaged everything. Re-run Save + Push when ready.
        pause
        goto MENU
    )
    git restore --staged .
    echo  Unstaged everything. Back to menu.
    pause
    goto MENU
)

:: Step 7: Commit message
echo.
set /p MSG=  Commit message (describe what you did) [0=Back]: 
if "%MSG%"=="0" (
    git restore --staged .
    goto MENU
)
if "%MSG%"=="" (
    echo  Message cannot be empty.
    git restore --staged .
    pause
    goto MENU
)
git commit -m "%MSG%"

:: Step 8: Push with error recovery
git push 2>"%TEMP%\push_err.txt"
if errorlevel 1 (
    findstr /i "upstream" "%TEMP%\push_err.txt" >nul
    if not errorlevel 1 (
        echo  No upstream set. Linking to origin/main automatically...
        git push --set-upstream origin main
    ) else (
        findstr /i "fetch first" "%TEMP%\push_err.txt" >nul
        if not errorlevel 1 (
            echo  Remote has changes you don't have locally. Pulling first...
            git pull --rebase
            git push
        ) else (
            echo  Push failed. Error:
            type "%TEMP%\push_err.txt"
        )
    )
)
echo.
echo  Done! Changes pushed to GitHub.
pause
goto MENU



:: ============================================================
:PULL
:: ============================================================
cls
echo.
echo  === PULL - Getting latest from GitHub ===
echo.
git pull
echo.
pause
goto MENU


:: ============================================================
:NEW_BRANCH
:: ============================================================
cls
echo.
echo  === NEW BRANCH ===
echo.
echo  Current branches:
git branch
echo.
set /p BRANCH=  New branch name (e.g. feature/dark-mode) [0=Back]: 
if "%BRANCH%"=="0" goto MENU
if "%BRANCH%"=="" (
    echo  Branch name cannot be empty.
    pause
    goto MENU
)
git checkout -b %BRANCH%
echo.
echo  Created and switched to branch: %BRANCH%
pause
goto MENU


:: ============================================================
:MERGE_BRANCH
:: ============================================================
cls
echo.
echo  === MERGE BRANCH ===
echo.
echo  You are on:
git branch --show-current
echo.
echo  Available branches:
git branch
echo.
set /p BRANCH=  Branch to merge INTO current branch [0=Back]: 
if "%BRANCH%"=="0" goto MENU
if "%BRANCH%"=="" (
    echo  Branch name cannot be empty.
    pause
    goto MENU
)
git merge %BRANCH%
echo.
echo  Merged %BRANCH% into current branch.
echo  Tip: if you are done with that branch, you can delete it: git branch -d %BRANCH%
pause
goto MENU


:: ============================================================
:SWITCH_BRANCH
:: ============================================================
cls
echo.
echo  === SWITCH BRANCH ===
echo.
echo  Available branches:
git branch
echo.
set /p BRANCH=  Branch to switch to [0=Back]: 
if "%BRANCH%"=="0" goto MENU
if "%BRANCH%"=="" (
    echo  Branch name cannot be empty.
    pause
    goto MENU
)
git checkout %BRANCH%
echo.
pause
goto MENU


:: ============================================================
:HISTORY
:: ============================================================
cls
echo.
echo  === COMMIT HISTORY ===
echo.
git log --oneline --graph --all --decorate
echo.
pause
goto MENU


:: ============================================================
:FIRST_TIME
:: ============================================================
cls
echo.
echo  === FIRST-TIME SETUP ===
echo.
echo  This will initialize git and push to a NEW GitHub repo.
echo  Make sure you have already created the empty repo on GitHub first!
echo.
set /p REPO=  GitHub repo name (e.g. yt-transcript-chrome-ext) [0=Back]: 
if "%REPO%"=="0" goto MENU
if "%REPO%"=="" (
    echo  Repo name cannot be empty.
    pause
    goto MENU
)
echo.
echo  Remote URL will be: https://github.com/%GITHUB_USERNAME%/%REPO%.git
set /p CONFIRM=  Looks right? ^(y/n^): 
if /i not "%CONFIRM%"=="y" goto MENU

echo.
echo  --- Step 1: Generate .gitignore ---
echo.
echo  What type of project is this?
echo   [1]  Chrome Extension
echo   [2]  Web App / Node.js
echo   [3]  Python Tool
echo   [4]  General (catch-all)
echo.
set /p PTYPE=  Project type [0=Back]: 

if "%PTYPE%"=="0" goto MENU
if "%PTYPE%"=="1" goto GITIGNORE_EXTENSION
if "%PTYPE%"=="2" goto GITIGNORE_NODE
if "%PTYPE%"=="3" goto GITIGNORE_PYTHON
if "%PTYPE%"=="4" goto GITIGNORE_GENERAL
echo  Invalid choice, using General.
goto GITIGNORE_GENERAL


:GITIGNORE_EXTENSION
echo # Chrome Extension> .gitignore
echo.>> .gitignore
echo # Dependencies>> .gitignore
echo node_modules/>> .gitignore
echo.>> .gitignore
echo # Secrets - NEVER upload these>> .gitignore
echo .env>> .gitignore
echo .env.local>> .gitignore
echo config.secret.*>> .gitignore
echo secrets.*>> .gitignore
echo.>> .gitignore
echo # Packaged builds>> .gitignore
echo dist/>> .gitignore
echo *.zip>> .gitignore
echo *.crx>> .gitignore
echo.>> .gitignore
echo # Logs>> .gitignore
echo *.log>> .gitignore
echo logs/>> .gitignore
echo.>> .gitignore
echo # OS junk>> .gitignore
echo .DS_Store>> .gitignore
echo Thumbs.db>> .gitignore
echo desktop.ini>> .gitignore
goto GITIGNORE_DONE


:GITIGNORE_NODE
echo # Web App / Node.js> .gitignore
echo.>> .gitignore
echo # Dependencies - can be restored with npm install>> .gitignore
echo node_modules/>> .gitignore
echo.>> .gitignore
echo # Secrets - NEVER upload these>> .gitignore
echo .env>> .gitignore
echo .env.local>> .gitignore
echo .env.development.local>> .gitignore
echo .env.production.local>> .gitignore
echo config.secret.*>> .gitignore
echo secrets.*>> .gitignore
echo.>> .gitignore
echo # Build output>> .gitignore
echo dist/>> .gitignore
echo build/>> .gitignore
echo .next/>> .gitignore
echo out/>> .gitignore
echo.>> .gitignore
echo # Logs>> .gitignore
echo *.log>> .gitignore
echo logs/>> .gitignore
echo npm-debug.log*>> .gitignore
echo.>> .gitignore
echo # Cache>> .gitignore
echo .cache/>> .gitignore
echo coverage/>> .gitignore
echo.>> .gitignore
echo # OS junk>> .gitignore
echo .DS_Store>> .gitignore
echo Thumbs.db>> .gitignore
echo desktop.ini>> .gitignore
goto GITIGNORE_DONE


:GITIGNORE_PYTHON
echo # Python Tool> .gitignore
echo.>> .gitignore
echo # Virtual environments>> .gitignore
echo venv/>> .gitignore
echo .venv/>> .gitignore
echo env/>> .gitignore
echo.>> .gitignore
echo # Secrets - NEVER upload these>> .gitignore
echo .env>> .gitignore
echo .env.local>> .gitignore
echo config.secret.*>> .gitignore
echo secrets.*>> .gitignore
echo.>> .gitignore
echo # Large binary tools - download separately, don't commit>> .gitignore
echo *.exe>> .gitignore
echo *.dll>> .gitignore
echo *.bin>> .gitignore
echo.>> .gitignore
echo # Python cache>> .gitignore
echo __pycache__/>> .gitignore
echo *.pyc>> .gitignore
echo *.pyo>> .gitignore
echo *.pyd>> .gitignore
echo.>> .gitignore
echo # Build/dist>> .gitignore
echo dist/>> .gitignore
echo build/>> .gitignore
echo *.egg-info/>> .gitignore
echo.>> .gitignore
echo # Logs>> .gitignore
echo *.log>> .gitignore
echo logs/>> .gitignore
echo.>> .gitignore
echo # OS junk>> .gitignore
echo .DS_Store>> .gitignore
echo Thumbs.db>> .gitignore
echo desktop.ini>> .gitignore
goto GITIGNORE_DONE


:GITIGNORE_GENERAL
echo # General Project> .gitignore
echo.>> .gitignore
echo # Secrets - NEVER upload these>> .gitignore
echo .env>> .gitignore
echo .env.local>> .gitignore
echo config.secret.*>> .gitignore
echo secrets.*>> .gitignore
echo.>> .gitignore
echo # Large binary tools - download separately, don't commit>> .gitignore
echo *.exe>> .gitignore
echo *.dll>> .gitignore
echo *.bin>> .gitignore
echo.>> .gitignore
echo # Dependencies>> .gitignore
echo node_modules/>> .gitignore
echo.>> .gitignore
echo # Python cache>> .gitignore
echo __pycache__/>> .gitignore
echo *.pyc>> .gitignore
echo.>> .gitignore
echo # Build output>> .gitignore
echo dist/>> .gitignore
echo build/>> .gitignore
echo.>> .gitignore
echo # Logs>> .gitignore
echo *.log>> .gitignore
echo logs/>> .gitignore
echo.>> .gitignore
echo # OS junk>> .gitignore
echo .DS_Store>> .gitignore
echo Thumbs.db>> .gitignore
echo desktop.ini>> .gitignore
goto GITIGNORE_DONE


:GITIGNORE_DONE
echo.
echo  .gitignore created. Here is what will be protected:
echo.
type .gitignore
echo.
set /p GICONFIRM=  Looks good? Continue? ^(y/n^): 
if /i not "%GICONFIRM%"=="y" goto MENU

echo.
echo  --- Step 2: Generate README.md ---
echo.
set /p DESC=  Short description of this project (1 sentence) [0=Back]: 
if "%DESC%"=="0" goto MENU
if "%DESC%"=="" set DESC=No description provided.

:: Set project type label for README
if "%PTYPE%"=="1" set PTYPE_LABEL=Chrome Extension
if "%PTYPE%"=="2" set PTYPE_LABEL=Web App / Node.js
if "%PTYPE%"=="3" set PTYPE_LABEL=Python Tool
if "%PTYPE%"=="4" set PTYPE_LABEL=General

:: Write README.md
echo # %REPO%> README.md
echo.>> README.md
echo %DESC%>> README.md
echo.>> README.md
echo ## Getting Started>> README.md
echo ^<!-- TODO: add setup instructions --^>>> README.md
echo.>> README.md
echo ## Usage>> README.md
echo ^<!-- TODO: describe how to use this --^>>> README.md
echo.>> README.md
echo ## Notes>> README.md
echo ^<!-- TODO: anything else worth knowing --^>>> README.md

echo.
echo  README.md preview:
echo  --------------------
type README.md
echo  --------------------
echo.
set /p RDCONFIRM=  Looks good? Continue? ^(y/n^): 
if /i not "%RDCONFIRM%"=="y" goto MENU

echo.
echo  --- Step 3: Creating repo on GitHub ---
echo.

echo.
echo  Should this repo be public or private?
echo   [1]  Public  - Anyone can see it
echo   [2]  Private - Only you can see it
echo.
set /p VISIBILITY=  Choose [0=Back]: 
if "%VISIBILITY%"=="0" goto MENU
if "%VISIBILITY%"=="2" (
    set REPO_VISIBILITY=true
) else (
    set REPO_VISIBILITY=false
)

:: Call GitHub API to create the repo
curl -s -o "%TEMP%\gh_response.json" -w "%%{http_code}" ^
  -X POST https://api.github.com/user/repos ^
  -H "Authorization: token %GITHUB_TOKEN%" ^
  -H "Content-Type: application/json" ^
  -d "{\"name\": \"%REPO%\", \"private\": !REPO_VISIBILITY!, \"auto_init\": false}" ^
  > "%TEMP%\gh_status.txt" 2>&1

set /p HTTP_STATUS=<"%TEMP%\gh_status.txt"

if "%HTTP_STATUS%"=="201" (
    echo  Repo created: https://github.com/%GITHUB_USERNAME%/%REPO%
) else if "%HTTP_STATUS%"=="422" (
    echo  Repo already exists on GitHub. Continuing with push...
) else (
    echo  GitHub API returned status: %HTTP_STATUS%
    echo  Check your GITHUB_TOKEN in the script is correct.
    pause
    goto MENU
)

echo.
echo  --- Step 4: Commit and Push ---
echo.
git init
git add .
echo.
echo  Files staged (secrets and junk excluded):
git status --short
echo.
set /p INITMSG=  Commit message [Enter=default, 0=Back]: 
if "%INITMSG%"=="0" goto MENU
if "%INITMSG%"=="" set INITMSG=feat: initial commit - %REPO%
git commit -m "%INITMSG%"
git branch -M main
git remote add origin https://github.com/%GITHUB_USERNAME%/%REPO%.git
git push -u origin main

echo.
echo  Done! Repo is live at: https://github.com/%GITHUB_USERNAME%/%REPO%
echo  Your .gitignore is protecting sensitive files automatically.
pause
goto MENU


:: ============================================================
:UNSTAGE
:: ============================================================
cls
echo.
echo  === UNSTAGE FILES ===
echo.
echo  This removes files from the staging area (the "ready to commit" pile).
echo  Your actual files on disk are NOT deleted or changed.
echo.
echo  Currently staged:
echo  --------------------------------
git diff --cached --name-status
echo  --------------------------------
echo.
echo  Examples:
echo    To unstage ONE file:  git restore --staged ytget.ps1
echo    To unstage A FOLDER:  git restore --staged "transcript download/"
echo    To unstage EVERYTHING: choose option 1 below
echo.
echo   [1]  Unstage EVERYTHING (safest - start fresh)
echo   [2]  Unstage a specific file or folder
echo   [0]  Back
echo.
set /p UCHOICE=  Pick an option: 

if "%UCHOICE%"=="0" goto MENU
if "%UCHOICE%"=="1" (
    git restore --staged .
    echo.
    echo  Done. Everything unstaged. Your files are untouched.
    pause
    goto MENU
)
if "%UCHOICE%"=="2" (
    echo.
    echo  Type the filename or folder exactly as shown above.
    echo  Example: ytget.ps1   or   transcript download/
    echo.
    set /p UFILE=  File or folder to unstage [0=Back]: 
    if "%UFILE%"=="0" goto MENU
    if "%UFILE%"=="" (
        echo  Cannot be empty.
        pause
        goto UNSTAGE
    )
    git restore --staged "%UFILE%"
    echo.
    echo  Unstaged: %UFILE%
    echo  Remaining staged files:
    git diff --cached --name-status
    pause
    goto MENU
)
echo  Invalid option.
pause
goto UNSTAGE


:: ============================================================
:EDIT_GITIGNORE
:: ============================================================
cls
echo.
echo  === EDIT .GITIGNORE ===
echo.

if not exist ".gitignore" (
    echo  No .gitignore found in this folder.
    echo  Run Option 8 (First-Time Setup) to generate one,
    echo  or create a blank one now.
    echo.
    set /p CREATEGI=  Create a blank .gitignore now? ^(y/n^): 
    if /i "%CREATEGI%"=="y" (
        echo # Add patterns below to exclude files from Git> .gitignore
        echo  Created blank .gitignore.
    ) else (
        goto MENU
    )
)

echo  Current .gitignore contents:
echo  --------------------------------
type .gitignore
echo  --------------------------------
echo.
echo  Opening .gitignore in Notepad. Save and close when done.
echo  After you close Notepad, this tool will automatically untrack
echo  any files that are now newly ignored.
echo.
pause
notepad .gitignore
echo.
echo  Notepad closed. Checking for files that need to be untracked...
echo.

:: Untrack files that are now covered by .gitignore but were previously committed
git ls-files -z --ignored --exclude-standard | findstr "." >nul 2>&1
if not errorlevel 1 (
    echo  Found files that are now ignored but still tracked by Git.
    echo  Removing them from tracking (files stay on your disk):
    echo.
    git ls-files --ignored --exclude-standard
    echo.
    set /p RMCACHED=  Remove these from Git tracking? ^(y/n^): 
    if /i "%RMCACHED%"=="y" (
        for /f "delims=" %%f in ('git ls-files --ignored --exclude-standard') do (
            git rm --cached "%%f" 2>nul
        )
        echo.
        echo  Done. These files will no longer be tracked by Git.
        echo  Tip: run Option 2 (Save + Push) to commit this change.
    )
) else (
    echo  All good - no previously tracked files need untracking.
)
echo.
pause
goto MENU


:: ============================================================
::  SUBROUTINES (called with a single quoted filename as %1)
::  Using subroutines instead of inline loops keeps the parser
::  safe against filenames with spaces, parentheses, and Unicode.
:: ============================================================

:BLOCK_ONE
:: %1 = quoted filename. Unstage it if its extension is in the config.
set "FEXT=%~x1"
if "%FEXT%"=="" goto :eof
findstr /x /i /l "%FEXT%" "%CONFIG_FILE%" >nul 2>&1
if not errorlevel 1 (
    git restore --staged -- "%~1" 2>nul
    echo    Auto-blocked: %~1
    set /a BLOCKED_COUNT+=1
)
goto :eof


:CHECK_LARGE
:: %1 = quoted filename. Count it if it exists and is over 5MB.
if not exist "%~1" goto :eof
if %~z1 gtr 5242880 (
    echo    Large file ^(over 5MB^): %~1
    set /a LARGE_COUNT+=1
)
goto :eof


:UNSTAGE_LARGE
:: %1 = quoted filename. Unstage it if it exists and is over 5MB.
if not exist "%~1" goto :eof
if %~z1 gtr 5242880 (
    git restore --staged -- "%~1" 2>nul
    echo    Unstaged: %~1
)
goto :eof


:: ============================================================
:EXIT
:: ============================================================
echo.
echo  Goodbye!
exit /b 0
