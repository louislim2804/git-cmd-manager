# git-cmd-manager

A Windows batch script that provides an interactive menu for common Git operations — no need to memorize commands.

## Features

- ✅ Check status and recent commits
- ✅ Stage, commit, and push in one step
- ✅ Pull latest from GitHub
- ✅ Create, switch, and merge branches
- ✅ View commit history (with branch graph)
- ✅ First-time repo setup with auto-generated `.gitignore` and `README.md`
- ✅ Auto-creates GitHub repo via API (no browser needed)

## Setup

1. Download `git-manager.bat`
2. Save it somewhere permanent, e.g. `C:\scripts\`
3. Add `C:\scripts` to your Windows PATH
4. Open `git-manager.bat` in Notepad and update these two lines:
set GITHUB_USERNAME=YOUR_GITHUB_USERNAME
set GITHUB_TOKEN=YOUR_PERSONAL_ACCESS_TOKEN

### Getting a GitHub Personal Access Token
1. GitHub → Settings → Developer settings
2. Personal access tokens → Tokens (classic)
3. Generate new token → tick `repo` scope → copy it

## Usage

Navigate to any project folder in terminal, then:

```bash
cd C:\your-project
git-manager
```

Pick from the menu — that's it.

## Requirements

- Windows 10 or later
- [Git for Windows](https://git-scm.com/download/win)
