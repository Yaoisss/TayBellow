# Workspace Browser: Create Folder

[English](2026-09-24-workspace-browser-create-folder.md) | [简体中文](2026-09-24-workspace-browser-create-folder.zh-CN.md)

Status: implemented (2026-09-24)

## Problem

In the Web Shell "New task → choose workspace" flow, the folder browser
(`AddWorkspaceDialog` in browse mode) can only select a directory that already
exists on the daemon host. Registering a path with `POST /workspaces` fails
with `invalid_path` unless the directory exists (`realpathSync` + `stat`
check), and no surface in the product can create one. A user starting a task
in a fresh project folder must first create it outside Qwen Code.

## Goals

- Let the user create a single new folder while browsing, then land in it and
  register it as a workspace.
- Keep the host filesystem write surface narrower than what `POST /workspaces`
  already exposes.
- Work for both the local daemon and a remote daemon selected in the dialog's
  location switcher.
- Degrade gracefully when the connected daemon is older than the Web Shell.

## Non-goals

- No recursive `mkdir -p`: a typo must not plant a multi-level tree.
- No rename/delete/move affordances in the browser.
- No changes to the TUI or headless surfaces (a shell user can `mkdir`
  directly).

## Proposed solution

A vertical slice through the existing layering, mirroring the
`workspace-path-suggestions` / `remote-workspace-path-suggestions` /
`addWorkspaceToDaemon` pattern:

1. **Daemon route** — `POST /workspace-directory-create`
   (`packages/cli/src/serve/routes/workspace-management.ts`), gated by
   `mutate()`. Body `{ path }`: non-empty, absolute,
   ≤ `MAX_WORKSPACE_PATH_LENGTH`. Semantics: the parent of the resolved target
   must exist and be a directory; the leaf must not exist (`409 path_exists`);
   creation is a single non-recursive `mkdir`. Success returns
   `201 { kind: 'workspace-directory-created', path }` with the resolved
   absolute path. Failures: `400 invalid_path` (validation, missing parent,
   parent not a directory), `409 path_exists`, `500 directory_create_failed`.
2. **Remote proxy** — `POST /remote-workspace-directory-create` in the same
   file, a copy of the `/remote-workspaces` proxy shape: forwards
   `{ path }` to `<daemon>/workspace-directory-create` with the target's
   `X-Daemon-Token` credential as the bearer, `redirect: 'error'`, proxy
   timeout + byte cap, and `res.on('close')` abort. A failure the target
   explained (e.g. `409 path_exists`) is surfaced verbatim, not as
   `remote_unreachable`.
3. **SDK** — `DaemonClient.workspaceDirectoryCreate(path)`
   (`packages/sdk-typescript/src/daemon/DaemonClient.ts`), a `jsonRequest`
   `rest`-mode POST next to `workspaceDirectoryPicker`.
4. **Web Shell actions** — `createWorkspaceDirectory(path)` in
   `daemon/workspace/actions.ts` (+ `DaemonWorkspaceDirectoryCreateResult` in
   `daemon/workspace/types.ts`), and `createDirectoryOnDaemon(origin, path)` in
   `config/remote-workspace-add.ts` reusing `remoteProxyHeaders` and the 401
   credential-recovery flow.
5. **Dialog UI** — `AddWorkspaceDialog` gains a `FolderPlusIcon` icon button
   next to the parent-up button, visible only in browse mode, for non-`ssh://`
   paths, when `createFolderSupported` and `onCreateFolder` are provided. It
   expands an inline row (name input + Create/Cancel). The parent is the
   directory currently listed: a trailing separator means the typed path is
   the parent, otherwise the final segment is an in-progress filter and is
   stripped (mirroring `GET /workspace-path-suggestions`). On success the
   dialog descends into the created directory (`path = created + sep`), which
   refreshes the suggestion list. Escape closes the row, not the dialog (the
   window-capture handler is extended for this). Client-side name validation
   rejects empty names, path separators, and `.`/`..`.
6. **Capability** — `workspace_directory_create` is registered as an
   unconditional (baseline) tag in `SERVE_CAPABILITY_REGISTRY`
   (`packages/cli/serve/capabilities.ts`). The route ships with every daemon
   built from this change, so no toggle plumbing is needed; older daemons
   simply do not advertise the tag and the Web Shell hides the affordance.

## Design decisions and rationale

- **Parent-must-exist, leaf-must-not, single mkdir.** Any authenticated client
  can already register any absolute directory (`POST /workspaces` stats it),
  so the trust surface here is not new — but keeping creation to one existing
  level prevents a mistyped path from silently creating a deep tree, and the
  409 makes double-clicks harmless. The browse list is what makes the parent
  visible, so requiring it to exist costs nothing in practice.
- **Proxy route instead of cross-origin fetch.** The browser cannot call a
  remote daemon directly (CSP); every remote surface in this flow goes through
  the serving daemon's proxy. The create proxy copies the registration proxy
  because both are mutations with the same credential and cancellation needs.
- **Baseline capability tag, not a toggle.** The route is version-gated, not
  configuration-gated. A conditional tag would add toggle plumbing in
  `server.ts`/`serve-features.ts` for a value that is always true; the Map
  shape in `capabilities.ts` exists for toggles that can actually be off.
- **Inline row instead of a second dialog.** The create gesture happens in
  the context of a directory the user just looked at; an inline row keeps
  focus and state in one surface. Escape is intercepted at window capture
  because Radix closes the dialog on document-capture Escape.

## Ownership classification

Both new routes are **process-global**: they address the daemon host's
filesystem before any workspace resolves, exactly like
`GET /workspace-path-suggestions` and `POST /workspace-directory-picker`.
They are not workspace-scoped and never touch a resolved runtime; the
`mutate()` gate is the same one `/workspace-directory-picker` uses.

## Constraints

- Paths honor `MAX_WORKSPACE_PATH_LENGTH` (shared with registration).
- Windows accepts `/` and `\` in the typed path; `resolve()` normalizes before
  the parent check, and the response returns the normalized path.
- Reserved Conversations roots are not special-cased here: creating a folder
  under them is harmless; registering it still runs the existing
  `conversation_workspace_reserved` check.

## Validation plan

- Route unit tests (`workspace-management.test.ts`): create happy path,
  trailing-separator normalization, missing/empty/relative path, missing
  parent, file parent, existing leaf (409), ENAMETOOLONG → 500
  `directory_create_failed`, `mutate()` gate, proxy forwarding with target
  credential, and proxy surfacing a target-explained 409.
- Web Shell tests: `AddWorkspaceDialog.test.tsx` (affordance visibility,
  create-and-descend, filter stripping, invalid name, daemon failure, Escape
  behavior), `remote-workspace-add.test.ts` (proxy headers, created-path
  return, no-path rejection, 401 recovery), App wiring covered by the
  dialog-level props.
- Manual: `npm run build && npm run bundle`, `qwen serve`, open the Web Shell,
  New task → choose workspace → New folder → create → register.

## Acceptance criteria

1. In browse mode with a supporting daemon, a new folder can be created from
   the dialog and the dialog descends into it.
2. Without daemon support (`workspace_directory_create` absent), the
   affordance is hidden and the flow is unchanged.
3. Creating requires an existing parent and fails with a visible error
   otherwise; an existing leaf yields a visible conflict error.
4. The same flow works with a remote daemon selected in the location
   switcher, authenticated through the proxy.

## Open questions

None.
