# Avalonia core capability matrix

This is a current capability map, not a WPF comparison and not a historical completion log.

The WPF client (`LumaChart.App`) has been removed from the repository. Avalonia is the only client line.
Avalonia (Windows, Android, iOS) is the only client line. Obfuscation is retired — no client enables OLLVM or
carries a native `ClientSecurity` gate.

Windows and Android are not separate feature implementations. Android must reuse the same Avalonia editor
source plus the same Core, Application and Online layers. In this matrix, Adapt means connecting a small
platform service or adjusting presentation for touch/SingleView; it never means rewriting the feature.

Status:

- Shared: the same source is used by Windows and Android.
- Adapter: only a platform boundary such as audio, storage, secure token or Activity lifecycle is required.
- Layout: the same Avalonia feature surface needs tablet sizing or touch interaction adjustments.
- Later: outside the tablet milestone.

| Area | Reuse model | Windows Avalonia | Android tablet | Android-specific work |
|---|---|---|---|---|
| Chart model and exact beats | Shared Core | Ready | Shared | None |
| Malody .mc and osu .osu | Shared Core/Application | Ready | Shared | SAF file source only |
| MCZ/OSZ archives | Shared Core/Application | Ready | Shared | SAF streams only |
| Library and workspace | Shared Application + Avalonia UI | Ready | Shared + Adapter | Private Android roots and Activity lifecycle |
| Tabs and recovery | Shared Application + Avalonia UI | Ready | Shared + Adapter | Activity/process restoration |
| Tap/LN editing | Same Avalonia editor | Ready | Shared + Layout | Touch/stylus hit targets |
| Selection, move, delete, undo | Same Avalonia editor/Application | Ready | Shared + Layout | Touch gesture mapping |
| Timing/Effect/Metadata | Same Avalonia controls and model | Ready | Shared + Layout | Tablet dialog/panel sizing |
| Note groups, nesting, annotations and drawers | Shared Core model + same Avalonia editor | Ready | Shared (same source) | Tablet row layout and annotation-card sizing |
| Validation and difficulty | Shared Core + Avalonia UI | Ready | Shared + verified | Finish tablet presentation |
| Audio transport | Shared timeline/controller | Ready | Shared + AudioTrack verified | Continue latency/device coverage |
| Key sounds | Shared scheduling/mixing policy | Ready | Shared + AudioTrack verified | Continue latency/device coverage |
| Waveform and spectrum | Same analysis/rendering logic | Ready | Shared + Adapter | Android audio/cache source |
| Playtest | Shared scoring/scroll/Avalonia surface | Ready | Shared + Adapter | Android audio and input |
| Settings and cache | Same Avalonia UI and settings model | Ready | Shared + Adapter | Android storage implementation |
| File picker | Platform interface | Windows adapter | Shared + verified | Path-less documents staged in app-private roots |
| Save As | Same Avalonia editor + platform root | Windows save picker | Shared + verified | In-app naming inside the app-private Library |
| Export destination | Shared export pipeline | Windows adapter | Adapter + verified | SAF create-document verified on the tablet |
| Login/profile/osu OAuth | Same Avalonia UI + Online | Ready | Shared + verified | osu OAuth browser return still unverified |
| Feedback/issues | Same Avalonia UI + Online | Ready | Shared + Layout | Tablet sizing only |
| Friends/notifications | Same Avalonia UI + Online | Ready | Shared + Layout | Compact tablet presentation |
| Room creation/join/chat | Same Avalonia UI + Online | Ready | Shared + verified | Join, chat and roles verified against Windows |
| Room chart sync | Shared Online/Application | Ready | Shared + verified | Bidirectional revisions verified with Windows |
| Resource upload/download | Shared Online streaming | Ready | Shared + verified | Byte-exact download verified on the tablet |
| Stable/Beta update config | Shared Online policy | Ready | Shared + Adapter | Android version/install flow |
| Secure session token | Shared interface | DPAPI adapter | Adapter | Android Keystore implementation |
| ClientSecurity native gate | Retired (obfuscation dropped) | Not built (only deprecated WPF ever P/Invoked it) | Removed from Android build | No OLLVM/obfuscation anywhere; do not reintroduce |
| Tablet landscape layout | Same Avalonia visual tree | Ready | Layout | Size and touch adjustments, no UI fork |
| Phone navigation | N/A | N/A | Later | Start only after tablet is stable |
| iOS host | Same Avalonia editor source | N/A | Separate target | Host started; see the iOS column below |

## Current Windows editor additions

- Key sounds use one shared built-in/custom gain path. The current Windows build applies a 4.0x pre-limiter
  boost and keeps the approved Hand Drum sample byte-for-byte unchanged.
- The shared mixer keeps music at a continuous gain while adding Key-sound samples, then applies the existing
  soft limiter only when the combined output needs it; delayed silent scheduling samples leave music untouched.
- Audio transport requests a 40 ms Windows output buffer, cancels pending coalesced seeks on Pause and avoids a
  decoder/device rebuild when resuming within 50 ms of the editor clock.
- Windows audio decoding identifies Ogg Vorbis and MP3 from container headers before filename extensions. This
  keeps playback, waveform/spectrum analysis, BPM analysis and export conversion working for Malody MP3 assets
  incorrectly named `.ogg`, without renaming or modifying the user's chart resources.
- Pitch-preserving slowdown uses the SoundTouch 100/28/20 ms profile with quick seek disabled above 0.30x. At
  0.20x-0.30x it instead expands time at the requested rate and restores pitch through three allocation-free SMB
  phase-vocoder stages. The extreme path uses a 4096-sample FFT, 8x overlap, pre-trims its fixed startup latency
  and applies a 10 ms startup fade, avoiding the repeated splice cycle visible in the old cascaded SoundTouch
  output while remaining inside the 40 ms WASAPI period budget.
- Editor view settings include true 0%-100% track-area transparency: 0% renders the black lane fill fully opaque,
  while 100% removes only that fill. Fresh/reset settings default to 30% transparency. Grid lines, Notes and the
  judgement line retain their own visual strength.
- Overall chart-background darkness is independently adjustable and persisted, with a 70% fresh/reset default.
  It affects the background image without fading the lane mask, grid, Notes or judgement line; schema-1 custom
  values migrate without reversing their established visual meaning.
- Fresh/reset editor geometry uses 280 DIP/beat, 77x41 DIP Notes, 2.2 DIP bar lines and 1.6 DIP subdivision lines.
- The Quick Edit floating palette has a bottom-right resize grip and uniformly scales its controls, labels and
  icons with the resized window. Width and height share one clamped scale factor, so resizing always preserves the
  palette aspect ratio. Space remains a one-shot transport command even after a playback Button was clicked,
  because its handled key-up cannot synthesize a second Button Click.
- Note groups carry editor-only metadata: name, colour, optional tree parent, preset membership and free-form
  annotations. The chart still stores only the integer group on each Note, so Malody `.mc` and osu `.osu`
  round-trip byte-compatibly; the metadata lives in `chart-group-catalog.json` beside the other local settings and
  is keyed by the chart's source path. Save As moves the entry to the new key instead of orphaning it.
- Group colour is painted onto the Note itself instead of relying on a badge in its centre. The badge is now
  opt-in and off by default, and the same colour drives the Tap plate, the LN rail, the hold body and the
  selection contour, so a group is readable without reading a number.
- Group presets are what "分组的分组" means: a preset is a named drawer of groups ("分组预设1: 分组A, 分组B" next to
  "分组预设2: 分组甲, 分组乙"), not a parent group. A Note carries exactly one integer group, so two axes — say
  per-lane versus per-feel — can never both live in that field; the preset re-organises the same field without
  re-tagging anything. A group belongs to at most one preset (the first declaration wins during normalisation), and
  the open drawer is view state.
- The drawers are tabs over a single list, not headings inside it and not a box beside it: a second row of tabs
  pinned directly under the inspector's own tab row — it is the first row of the 分组 page and sits outside that
  page's scroller — 未分类 first, then every preset in id order, with ＋ / 重命名 / 删除 riding at its right end.
  The row is styled with the WPF 1.1.0 TabItem palette the page row above it uses (muted #929A9F label, #22272A
  plate and a 2-DIP #7FA4A7 underline on the open tab, #202427 hover), so the two levels read as one control with a
  drawer under a page. The open tab is the only drawer on screen, so opening a drawer is what selects which groups
  are listed, and a tab carries its own row count. A new drawer is created by ＋, lands selected, and its tab is
  scrolled into view; right-clicking a preset tab puts a name box where its label was (Enter commits, Esc cancels)
  and 重命名 does the same for the open tab, because a Button consumes a press before a plain handler sees it and
  the rename has to be caught on the tunnel route. 未分类 is not a preset, so it can be neither renamed nor deleted:
  删除 goes dead and dims while it is the open tab, and 重命名 stays live by opening a drawer instead of refusing —
  the first the chart has, or 预设 1 when it has none — so no press on it can end in nothing. Every rename reports
  what happened, including "the name did not change", because a rename that silently keeps the old name and a rename
  that never opened are the same thing on screen.
- Renaming a drawer swaps that one tab's content and rebuilds nothing. Rendering the box by rebuilding the strip
  looked identical on paper but detached the box as soon as it was built, and the commit raised by that focus loss
  re-entered the rebuild that was still running — leaving a second copy of every tab on the strip and no box to
  type in. Lost focus now commits one message later, so a box that is focused again inside the same frame stays
  open, and RebuildGroupPanel refuses to re-enter itself.
- The box is only safe from rebuilds once rebuilds stop happening behind its back. The whole-window refresh used to
  force one on every pass it made — and it makes one on every state change, and writing a status line is a state
  change — so the box was swapped in and torn down inside the same call: the press did nothing at all, and a
  half-typed group name lost the caret with it. Rebuilds are now decided by the panel signature alone, which
  already leads with the chart id, the open drawer and every group and preset, so a refresh that has nothing new to
  show updates the rows in place. A rebuild the re-entrancy guard refuses leaves the signature unrecorded, so the
  panel never believes it is showing a shape it did not render and the next refresh tries again.
- A group created while a drawer is open is filed into that drawer: 新建并使用, ＋子 and a group first named by
  分配 all follow the open tab. Filing it into 未分类 instead would put the new row off-screen the moment it was
  born, which reads as the group going missing rather than as a filing choice. Clearing the open tab (未分类) makes
  creations unassigned again, and re-filing a group from one drawer into another is still the per-row 预设 picker —
  which takes the row off screen, so the status line says that it left.
- Group nesting is a real feature but a rare want, so it is hidden by default behind 显示子分组 in the group
  manager. While it is on, a parent is listed before its children, child rows are indented, and a preset may be
  read either from the exact group or from its top-level ancestor. Hiding a parent hides its whole subtree;
  revealing a nested group also reveals the ancestors, because a visible child of a hidden parent contradicts
  itself. The parent picker and the ＋子 button cost nothing until the toggle is turned on.
- An annotation is its own mechanism, not a group that also carries text. It owns a list of Notes, referenced as
  `(Lane, BeatPosition)` because Malody does not round-trip `ChartNote.Id`; a lookup cached against the session
  change serial resolves those keys per frame, so a block follows its Notes when they move. Its colour is computed
  live as the modal group of those Notes, falling back to stock white when they are ungrouped — re-tagging a Note
  re-colours the card without touching the block. Each block lists in chart order under the 批注 inspector tab with
  its position, an editable text box, 重新指向选中 and 删除; clicking a block jumps the playhead to its anchor and
  selects the Notes it covers. On the timeline a same-coloured leader runs from each Note to a sticky note beside
  the track; cards are pushed apart when their anchors overlap, adapt their height and wrap CJK per character and
  Latin per word. Clicking a card selects its Notes; clicking the same card again floats a text box over it, so a
  comment can be written where it is read instead of a tab away. The box writes the same field the 批注 tab does,
  in place, and closes on Esc or when it loses focus. The surface cannot host the box itself — it draws its own
  cards — so it reports the card's bounds and the window floats the editor there, clamped into the viewport.
- Group and annotation metadata never touches the document, so renaming, recolouring, re-nesting, re-bucketing
  into presets and annotating open no undo entry; only assigning, dissolving or toggling membership writes
  history, exactly as before. Display preferences (colour mode, badge visibility, card visibility, dock side and
  sub-group visibility) are machine-local and persist separately from the per-chart catalog, and the whole entry
  is written through a temp-file-replace merge that upgrades schema 1 files in place.
- Annotation presets (批注预设) are the annotation side of the same idea, and are deliberately a *second,
  separate* drawer system rather than a second use of the group one. A group preset files groups; an annotation
  preset files analysis blocks. They have separate id spaces, separate open drawers and separate tab strips, and
  neither ever reads the other — so re-organising the blocks cannot move a group, and opening a 分组 drawer cannot
  change which blocks are listed. The 批注 page carries the same tab strip the 分组 page does (未分类 first, then
  every preset in id order, ＋ / 重命名 / 删除 at the right end, right-click rename, in-place label swap and the
  same re-entrancy guard), and each block row gets its own 抽屉 picker.
- A block is filed into the open drawer when it is created, the same way a group is. Normalisation keeps a block
  in at most one drawer — the first claim wins — because "which drawer is it in" has to have exactly one answer
  even after a hand-edited file or a merge. Deleting a drawer keeps its blocks: they fall back to 未分类 rather
  than disappearing, and deleting the open drawer clears the open state.
- `chart-group-catalog.json` stays at schema 2. Adding the `AnnotationPresets` array to each entry does not bump
  the version on purpose: a bump would make an older client judge the whole entry unreadable and clear every
  group name for that chart on its next save, which is far worse than an old client simply ignoring an array it
  does not know. New fields are therefore additive and optional within the same schema.
- 导入/导出存档 writes everything the editor knows *about* a chart — group names, colours, nesting and drawers,
  which notes were assigned to which group, the analysis blocks and their drawers, and the ProEditor scratch
  track — into one `.luma-archive.json`, because the per-chart catalog is keyed by the chart's absolute path and
  therefore does not survive the chart file moving. Group assignments and blocks are remembered as
  `(Lane, BeatPosition)`, never as `ChartNote.Id`, for the same reason annotations are.
- An import merges rather than replaces. The archived ids are written over the live metadata and everything the
  archive does not name is left exactly as it is, because the catalog has no undo: a replace would silently
  destroy grouping work that took longer to make than the archive did. Restoring after a chart file moved lands
  on an empty catalog, so a merge there *is* a full restore. The one destructive step — setting the ProEditor
  track to the archive's, which removes the existing scratch notes — is a document mutation, so it is a single
  Ctrl+Z away, and two archives holding the same track do not open an undo entry just because they list it in a
  different order. The file is refused unless it carries the `lumachart.editor-archive` marker and a version this
  client reads.
- The timeline's left measure rail prints the stored measure index, which is the same 0-based number the Note
  property box, the Timing panel, the annotation list, the navigation markers and the `.mc`/`.osu` files use, so
  the label a mapper reads off the rail is the label they type into a beat box. It deliberately does not
  reproduce the reference client's "source index + 1": that made the rail the only readout in the editor that
  disagreed with every other one (a note whose property read beat 4 sat beside a rail that said 5).


## Current Android foundation

- LumaChart.Android is an Avalonia.Android host.
- LumaChart.Avalonia.Shared directly compiles the existing LumaChart.Avalonia source files. The Android client
  therefore starts from the same MainWindow/editor implementation, not a separately recreated screen.
- Android private Library/editing/cache paths and a basic ACTION_OPEN_DOCUMENT picker exist.
- Every shared "choose a file" flow resolves its result through `PlatformPickedFiles`. A picker result that
  already carries a real file-system path is used unchanged, so Windows performs no extra copy; a Storage Access
  Framework content document is staged into an app-private root first. Backup restore, custom Key sound, chart
  image, chart audio, per-Note Key sound and create-chart-from-audio therefore work on the tablet instead of
  reading a null local path and silently returning.
- Transient picks stage into `cache/_resources/_picked` and are pruned after six hours. A custom Key-sound path
  is persisted in settings, so it stages into `files/_editing/picked-assets`, outside every root that cache
  management clears.
- Save As uses `IPlatformFileExportService.InAppSaveAsRoot`. Windows returns null and keeps its save picker;
  Android returns the app-private Library root, names the copy in-app, writes it into the chart's own folder so
  the audio and images stay beside it, and keeps the tab bound to the new file. The `Editor.SaveAs` command
  button appears only on platforms that use the in-app picker, because Save As is otherwise a Ctrl+Shift+S-only
  command that a touch tablet cannot reach.
- The latest built arm64 APK is `1.2.0.9-beta` (`versionCode 12009`, 49,715,120 bytes, SHA-256
  `95BDBB2883812B6F5279576AB288335D51E163134720DE883766DEFB3526D34F`; device test pending). It embeds
  Source Han Sans CN and makes it the default family + glyph fallback for the mobile hosts, fixing CJK text that
  did not render on some OEM ROMs ("文字显示不全") because the theme's Windows font families do not exist on a
  phone and the device fallback returned no Chinese glyphs. Windows is unchanged and stays on `1.2.0.8-beta`.
- On the connected Android 13 tablet, Subdivision Check, hidden LN body rendering, real chart audio,
  Pause/Resume and Rework were operated successfully. The 3,144-Note Reply chart reported Sunny 5.68 /
  `Reform 7 mid/high` / `LN 7 high`.
- Android `AudioTrack` consumes the same managed decode, rate, pitch and overlay-mixing chain as Windows. Dense
  15-second playback reported no music, sink or Key-sound underruns, and Key-sound transients no longer lower the
  underlying music level. Only combined overload is soft-limited.
- On the tablet, a real `.mp3` was imported through the document picker, staged byte-for-byte, turned into a
  library chart, bound as that chart's audio, saved back into the app-private Library, copied through the new
  in-app Save As, and exported as an `.mcz` through `ACTION_CREATE_DOCUMENT`.
- Windows and Android interoperate in one real room. Hidden room 100150 had Windows `hello272` as owner and the
  tablet `gst0` as editor. Resource upload/download, chart load, chat, a Windows timing edit at revision 1, an
  Android 3,144-Note mirror at revision 2, Android role enforcement and owner room close all behaved the same on
  both ends through the existing `RoomChartSyncCoordinator` and protocol. No mobile-specific room path was added.
- The installed APK is `AA9532ECCC801A856CD627A8AD6200C11267407605C19DB9C73A1E8A3FA44105`.
- The tablet library header flows its five actions through a `WrapPanel` at natural width with a shared 128x44
  minimum, instead of stretching each one across a quarter of the header and wrapping the fifth onto its own row.
  The Windows header keeps its existing horizontal `StackPanel` and scroller.
- Save As keeps the chart's own folder only when that folder is inside the app-owned root. A room-bound tab reads
  from app-internal room-document storage, so its copy is redirected to the library root instead of disappearing
  into private storage.
- Remaining tablet work is concentrated in lifecycle recovery, touch/layout coverage and SingleView presentation.
  Phone navigation remains a separate later milestone.
- Open Android defects: MP3 and other non-Ogg/Wav audio cannot be decoded
  because the shared decoder reaches NAudio's Windows ACM and MediaFoundation paths; the soft keyboard covers the
  lower part of the in-app Save As dialog; and the BACK key does not close a SingleView modal.

## Current iOS foundation

iOS is an active target. It reuses the same Avalonia editor source as Windows and Android; there is no second
editor UI, no second online protocol and no iOS-specific room path.

- `LumaChart.Avalonia.SharedSource.props` now owns the shared compile list and the common package set.
  `LumaChart.Avalonia.Shared` (Android) and `LumaChart.Avalonia.Mobile` (iOS) both import it, so the two mobile
  hosts cannot drift onto different file lists.
- `LumaChart.Avalonia.Mobile` is the iOS shared-compile project. It is the same `net8.0` shape as the Android
  one, minus `Avalonia.Win32`.
- `LumaChart.iOS` is the host: `net10.0-ios26.2`, `ios-arm64`, deployment target iOS 15.0, bundle id
  `cc.lumachart.studio` and overridable with `-p:LumaChartBundleId=`.
- The iOS SDK band must match the installed Xcode exactly. Band 26.2 goes with Xcode 26.3; disabling the SDK's
  Xcode check instead produces a binary that aborts during runtime startup on device, before any managed code
  runs, with a crash report that contains no managed stack at all.
- Dropping `Avalonia.Win32` on iOS cost two guarded code paths and nothing else. `WindowsRenderingConfiguration`
  is only used by the Windows `Program.cs`, and `WindowsShortcutPhysicalKeyState.TryResolvePressedKey` returns
  null off Windows anyway. Both are behind `#if !LUMACHART_IOS`; Windows and Android compile unchanged.
- The 11 platform seams are registered in `LumaChart.iOS/AppDelegate.cs`, the same way Android registers them in
  its `Application` constructor. Storage locations, Keychain session token, notices, external URIs, text input,
  the managed archive directory creator, the IpaDic root and the display refresh rate are implemented. Audio
  output and the document-picker import/export services belong to their own slices and are deliberately left
  unregistered; every seam is null-tolerant, so those features are absent rather than wrong.
- Sandbox roots: the chart library is `Documents/Library` so the Files app can reach it, settings and editing
  state are under `Library/Application Support`, reusable resources under `Library/Caches`, and process scratch
  under `tmp`.
- `LumaChart.ClientSecurity` is not part of iOS, and as of 1.2.0.8-beta it is not part of Android either.
  Obfuscation is retired project-wide: no ios-arm64 or android-arm64 native gate, no OLLVM toolchain, no
  verification target on any client. The Avalonia editor never loaded that native module, and the last
  surviving P/Invoke went with the WPF client when it was removed.
- The build is unsigned by design. The VM holds no Apple account, certificate or provisioning profile, and the
  packaging script fails if the produced `.app` turns out to be signed.
- Trimming runs in `partial` mode. Full trim produced 62 IL2026 findings across the reflection-based
  System.Text.Json paths in `LumaChart.Avalonia`, `LumaChart.Application` and `LumaChart.Online`, plus IL2104 for
  `NAudio.Core` and `NAudio.Wasapi`. Moving back to full trim requires source-generated JSON contexts and belongs
  with the online slice.
- No iOS runtime behaviour has been verified. The build VM has no Simulator runtime, is x86_64 and has no GPU
  passthrough, so it is a compile-only environment; acceptance is by the user on a real device.

## Completion rule for the tablet milestone

The milestone is complete when an installed arm64 APK can import a real chart, edit it, play audio, save/export,
restart without losing work and use the existing online account/room flow on the tablet, while Windows Avalonia
still builds and its shared behaviors remain intact.
