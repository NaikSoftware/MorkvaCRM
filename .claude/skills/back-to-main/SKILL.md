---
name: back-to-main
description: Use when the user asks to go back to main, reset to main, clean up the current branch/worktree, or finish a release/feature. Switches to main, pulls latest, and removes the previous branch and worktree if they exist.
---

# Back to main

Return the local checkout to a clean `main` and discard the working branch and worktree the session was using.

## Instructions

1. **Detect the current location:**
   - Run `pwd` and check whether the path contains `.claude/worktrees/` — if so, the session is inside an EnterWorktree-managed worktree.
   - Run `git branch --show-current` to capture the current branch name.

2. **Inside a worktree → ExitWorktree:**
   - Call `ExitWorktree` with `action: "remove"`.
   - If it refuses because of uncommitted files or unmerged commits, inspect them. If the branch is already pushed to remote (commits exist on `origin/<branch>`), it's safe to re-invoke with `discard_changes: true`. Otherwise stop and ask the user.
   - ExitWorktree returns the session to the original directory and deletes the worktree branch — skip to step 4.

3. **Outside a worktree, on a non-main branch:**
   - `git checkout main`
   - Delete the previous branch:
     - Try `git branch -d <branch>` first (safe — only deletes if fully merged into its upstream).
     - If that fails, check `git ls-remote --heads origin <branch>` — if it exists on remote, the commits are preserved, so re-run with `git branch -D <branch>`.
     - If it does not exist on remote and is not merged, stop and ask the user before force-deleting.

4. **Pull latest main:**
   ```bash
   git fetch origin
   git pull --ff-only origin main
   ```
   Use `--ff-only` so the pull fails loudly if local `main` has diverged instead of creating a merge commit.

5. **Verify:**
   - `git branch --show-current` should print `main`.
   - `git status` should be clean.
   - `git worktree list` should not include the removed worktree.

## Important

- Never delete a branch whose commits are not on remote AND not merged into main without explicit user confirmation — that's lost work.
- If the current branch is already `main` and there is no worktree to remove, just fetch and fast-forward; do not delete anything.
- If the repository's default branch is not `main` (e.g. `master`), confirm the actual default branch with `git remote show origin` and substitute it throughout.
