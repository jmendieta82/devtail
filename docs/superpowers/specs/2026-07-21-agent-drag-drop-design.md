# Agent Tab Drag & Drop — Design

**Date:** 2026-07-21
**Status:** Approved by Javier (conversational design review)

## Problem

Images can already be pasted into the agent tab (`AgentTerminalView.paste` converts
pasteboard bitmaps to temp PNGs and bracketed-pastes the path, which the agent TUI
renders as `[Image #N]`). Dragging is dead: the SwiftTerm view registers no drag
types, so dropping the macOS screenshot floating thumbnail — Javier's primary
workflow, previously covered by Ghostty — does nothing.

The floating thumbnail is a **file promise** (`NSFilePromiseReceiver`), not a file
URL: the receiving app must claim it and macOS materializes the PNG at a
destination the receiver chooses. Dropping it into a receiver also prevents the
screenshot from landing on the desktop, which is exactly the desired behavior.

## Approach (chosen: AppKit drop on AgentTerminalView)

All drop handling lives where paste already lives: `AgentTerminalView`.

- `init` registers for `NSFilePromiseReceiver.readableDraggedTypes` + `.fileURL`.
- `draggingEntered(_:)` returns `.copy` when the pasteboard carries file promises
  or file URLs, `[]` otherwise.
- `performDragOperation(_:)`:
  - **File promises** (screenshot thumbnail): `receivePromisedFiles(atDestination:)`
    materializes into the same temp dir the paste path already manages
    (`imageDir` / `AgentImagePaste.makeTempDir`). Completion arrives off-main;
    hop to MainActor before feeding the terminal.
  - **File URLs** (Finder drags): path sent directly, no copy.
  - Multiple items: one bracketed paste per file, sequential.
  - Any file type is accepted, not just images — filtering costs more code than it
    saves, and dragging a `.swift` or a log into the agent is useful.
- The hand-rolled bracketed-paste wrap currently inlined in `paste(_:)` is
  extracted to a shared `sendBracketedPath(_:)` method used by both paste and
  drop — single source of the wire format (mode-2004 aware).

Rejected alternative: SwiftUI `.onDrop` on the hosting wrapper. `NSItemProvider`
file-promise handling is less reliable (provider temp files die with the
callback, forcing a copy anyway) and the SwiftTerm NSView can swallow the drag
before it reaches the SwiftUI layer.

## Error handling

A promise that fails to materialize logs an os_log warning and sends nothing —
same silent criterion as the existing paste path.

## Testing

- Pure extraction (pasteboard → URLs to send) goes into a testable helper in the
  `AgentImagePaste` family, unit-tested with constructed `NSPasteboard` instances:
  file URLs extracted, multiple items preserved in order, non-file drags yield
  nothing.
- The real promise path (floating thumbnail) is validated in Javier's manual
  checkpoint with the running app.

## Out of scope

- Drop support in the plain Terminal tab (Agent only, per scope decision).
- Visual drop-target highlight (Ghostty has none either).
- Path shell-escaping — bracketed paste delivers the path as literal text,
  consistent with the existing paste behavior.
