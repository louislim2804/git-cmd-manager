@echo off
setlocal enabledelayedexpansion

:: ============================================================
::  git-manager.bat — Solo Dev Git Toolkit
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
git status
echo.

:: Check if there is anything new to commit
git diff --quiet --cached 2>nul
git diff --quiet 2>nul
for /f %%i in ('git status --porcelain') do set HAS_CHANGES=%%i

if not defined HAS_CHANGES (
    :: Nothing new to stage — check if there are unpushed commits
    echo  Nothing new to commit.
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

set /p MSG=  Commit message (describe what you did) [0=Back]: 
if "%MSG%"=="0" goto MENU
if "%MSG%"=="" (
    echo  Message cannot be empty.
    pause
    goto MENU
)
git add .
git commit -m "%MSG%"

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
echo  === PULL — Getting latest from GitHub ===
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
set /p CONFIRM=  Looks right? (y/n): 
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
set /p GICONFIRM=  Looks good? Continue? (y/n): 
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
set /p RDCONFIRM=  Looks good? Continue? (y/n): 
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
:EXIT
:: ============================================================
echo.
echo  Goodbye!
exit /b 0
