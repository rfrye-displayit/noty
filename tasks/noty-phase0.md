# Noty Phase 0 Assessment

Baseline: upstream `7c9bb4073dbff00076c319abadcaa4e05fd80ee4`, recorded by `aa53dfc` on `feature/reference-cards`.

## Verification

- The complete `Sources/` directory, both test files, README, and build scripts were inspected.
- Unchanged sources compile for arm64 against the installed macOS 15.4 SDK.
- `EditorStyleEngineTests` and `LocalizationTests` pass.
- The ad hoc signed app bundle launches and initializes one welcome note.
- The stock `build.sh debug` is blocked by a local toolchain mismatch: the default macOS 26.5 SDK was built with Swift 6.3.2, while `swiftc` is 6.3.3.
- Hover, fan, first-click, editing, pinning, dismissal, full-screen, and multi-display behavior need a human visual pass.

## Architecture

```text
Store (SQLite, encryption, schema migration)
  -> NoteStore.shared (published in-memory source of truth, write-through mutations)
    -> DeckController per display (state, panels, geometry, timers, event monitors)
      -> DeckRootView (tabs and expanded-item routing)
        -> NoteEditorView (current expanded content)
```

The smallest safe seam is the existing `notes` row. It already owns deck identity, ordering, title, color, archive, and pin state. Phase 1 should add a persisted discriminator while leaving all rows and behavior as notes.

## Phase 1 Change Surface

- `Sources/Core.swift`: add `DeckItemKind: String, Codable` with `note` and `reference`; add `Note.kind`, defaulting to `.note`.
- `Sources/Store.swift`: add and migrate a `kind TEXT NOT NULL DEFAULT 'note'` column; read, bind, and update it with unknown values falling back to `.note`.
- `Tests/EditorStyleEngineTests.swift`: add legacy-row migration, kind round-trip, and unknown-kind fallback tests.

No `NoteStore`, controller, or view behavior should change in Phase 1. Renaming `Note` or `NoteStore` now would create broad churn across editing, floating notes, the library, quick capture, export, and deck code without enabling the first reference card.

## Risks

- A failed migration can make the widened SELECT return no rows; `NoteStore` would then mistake that for first launch and seed a welcome note. Tests must assert preserved data on disk and after reopen.
- The upsert conflict clause must update `kind`, or persisted type changes silently fail.
- Unknown discriminator values must load as `.note`, not drop the row.
- Before reference rows are seeded, export, import, library, quick capture, previews, detach, editor-only shortcuts, and reload restoration must be audited or routed by kind.
- Preserve `DeckController.State.expanded(id)`, per-display controllers, cross-display collapse, animation ordering, first-click handling, and panel geometry. Route the expanded view by kind at the existing root instead of creating another panel system.

## Exact Proposed Phase 1 Diff

1. Define `DeckItemKind` and default `Note.kind = .note`.
2. Append `kind` to CREATE TABLE and add a checked ALTER migration for legacy databases.
3. Append `kind` to SELECT and decode using `DeckItemKind(rawValue:) ?? .note`.
4. Append `kind` to INSERT, conflict UPDATE, and binding position 11.
5. Add tests that create a pre-kind database with a real encrypted note, migrate and reopen it, round-trip `.reference`, and safely load an unknown raw kind as `.note`.

Reference-card models, seeding, viewer UI, clipboard behavior, and deck routing remain out of Phase 1.

## MVP Implementation Plan

- [x] Phase 1: persist `DeckItemKind` with backward-compatible migration and round-trip tests.
- [x] Phase 2: add structured reference content and a native scrolling viewer without changing panel mechanics.
- [x] Phase 3: seed exactly one built-in Terminal card and keep references out of note-only library/export/editor flows.
- [x] Phase 4: copy commands through `NSPasteboard` with transient inline confirmation and no execution path.
- [x] Phase 5: route deck actions safely by kind, build and test, inspect the running app, then run an adversarial break pass.
