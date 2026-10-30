# Default Workspace Symlink Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure `antigravity_headless` to link `/root/Documents` to `/workspace` so Antigravity defaults new workspace dialogs to `/workspace`.

**Architecture:** Add a build-time symlink in `Dockerfile` and an idempotent runtime safeguard in `entrypoint.sh` to ensure `/root/Documents` points to `/workspace`. Update `README.md` to document this behavior.

**Tech Stack:** Docker, Bash, Debian

**Spec:** `docs/superpowers/specs/2026-10-30-default-workspace-symlink-design.md`

## Global Constraints

- Must preserve existing Dockerfile structure, cron jobs, and tmux configuration.
- Symlink operations must be idempotent and non-failing if `/root/Documents` already exists.
- The symlink target must be `/workspace` and source must be `/root/Documents`.

## Review Focus

- Broken or dangling symlink if `/workspace` is mounted as an empty volume: verify link points to `/workspace`.
- Idempotency when container restarts or `/root/Documents` already exists: verify script does not fail or clobber existing directory erroneously.
- Permissions: verify user `antigravity` or `root` can traverse `/root/Documents`.
- Dockerfile syntax validity: verify `Dockerfile` parses cleanly.
- Language Server compatibility: verify `GetDefaultProjectDir` returns `file:///root/Documents` when the symlink is present.

---

### Task 1: Add Automated Test Script for Workspace Symlink

**Files:**
- Create: `tests/test_workspace_symlink.sh`

**Interfaces:**
- Consumes: Bash test harness
- Produces: Executable verification script returning 0 on success, non-zero on failure

- [ ] **Step 1: Write the test script**

Create `tests/test_workspace_symlink.sh` checking:
1. `Dockerfile` contains `RUN ln -s /workspace /root/Documents` (or `ln -sf`).
2. `Dockerfile`'s embedded `entrypoint.sh` includes `[ -e /root/Documents ] || ln -s /workspace /root/Documents` (or equivalent idempotent check).
3. Runtime simulation: creates a mock root directory, runs the entrypoint snippet, and asserts that `readlink "$MOCK_ROOT/Documents"` resolves to `/workspace`.
4. Idempotency check: runs the snippet a second time and asserts exit code 0.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_workspace_symlink.sh`
Expected: FAIL because `Dockerfile` does not yet contain the symlink or entrypoint check.

- [ ] **Step 3: Commit the test**

```bash
git add tests/test_workspace_symlink.sh
git commit -m "test: add test suite for workspace symlink logic"
```

---

### Task 2: Update `Dockerfile` with Build-time and Runtime Symlink

**Files:**
- Modify: `Dockerfile`
- Test: `tests/test_workspace_symlink.sh`

**Interfaces:**
- Consumes: `/workspace` path
- Produces: Symlink `/root/Documents -> /workspace` in image and in `entrypoint.sh`

- [ ] **Step 1: Modify `Dockerfile`**

In `Dockerfile`:
1. In the workspace configuration section (around line 58), add:
   ```dockerfile
   RUN ln -s /workspace /root/Documents
   ```
2. In the `entrypoint.sh` heredoc (before starting tmux/cron, around line 86), add:
   ```bash
   # Ensure /root/Documents points to /workspace so Antigravity defaults new workspaces to /workspace
   [ -e /root/Documents ] || ln -s /workspace /root/Documents
   ```

- [ ] **Step 2: Run test to verify it passes**

Run: `bash tests/test_workspace_symlink.sh`
Expected: PASS with all checks succeeding.

- [ ] **Step 3: Commit**

```bash
git add Dockerfile
git commit -m "feat: link /root/Documents to /workspace for default workspace picker"
```

---

### Task 3: Update Documentation in `README.md`

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: Features documentation
- Produces: Updated documentation describing the default workspace resolution

- [ ] **Step 1: Update `README.md`**

In `README.md`:
1. Under `## Features`, add a section or bullet note:
   - **Default Workspace Scoping**: Automatically symlinks `/root/Documents` to `/workspace` so new workspace creation dialogs in the Antigravity UI default to `/workspace`.
2. Under `## Directory & File Structure`, document `/root/Documents -> /workspace`.

- [ ] **Step 2: Verify formatting and accuracy**

Check diff with `git diff README.md`.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: document /root/Documents workspace symlink feature"
```
