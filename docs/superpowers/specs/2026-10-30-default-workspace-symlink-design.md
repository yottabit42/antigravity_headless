# Design: Default Workspace Symlink to `/root/Documents`

## Intent & Why
In Google Antigravity, the `GetDefaultProjectDir` RPC inspects `$HOME/Documents` to decide where the "New Workspace" and folder picker dialogs open by default. If this directory does not exist, it falls back to `$HOME` (`/root`). In headless container environments where `/workspace` is the primary mount for projects, users expect new workspaces to default to `/workspace` rather than `/root`.

## Goals
- Make Antigravity's default workspace directory resolve to `/workspace` when creating a new workspace.
- Ensure the symlink `/root/Documents -> /workspace` is established in the Docker image and ensured dynamically at container startup in `entrypoint.sh`.

## Non-Goals
- Modifying closed-source `agy` binaries.
- Changing host volume mounts or Dockge compose layout.

## Approaches Considered
1. **Symlink `/root/Documents` to `/workspace` (Selected)**:
   - *Pros*: Directly satisfies Antigravity's internal resolution order in `GetDefaultProjectDir`. Clean and robust.
   - *Cons*: Relies on Antigravity's current `Documents` path convention.
2. **Symlink `/root/workspace` to `/workspace`**:
   - *Pros*: Visible inside `/root`.
   - *Cons*: Does not solve the root issue; the picker still opens at `/root` rather than inside `/workspace`.
3. **Launch CLI with `--add-dir /workspace`**:
   - *Pros*: Explicit CLI argument.
   - *Cons*: Only affects the initial session, not the "New Workspace" UI picker dialog.

## Proposed Changes
1. **`Dockerfile`**:
   - Add `RUN ln -s /workspace /root/Documents` alongside workspace configuration.
   - Add an idempotent symlink check in `entrypoint.sh` before starting `agy`:
     ```bash
     [ -e /root/Documents ] || ln -s /workspace /root/Documents
     ```
2. **`README.md`**:
   - Document that `/root/Documents` is symlinked to `/workspace` so the UI file picker opens to `/workspace` by default.
