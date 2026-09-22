# Floating console

The window uses the same charcoal palette, cyan accents, rounded corners and padded options popup as the main UI, with a translucent body and dense monospace timestamped logs. It is an ImGui window inside the host viewport, so DX11, DX12, OpenGL and Vulkan use exactly the same component.

## Host integration

```cpp
ui.console().write("Renderer initialized", simple_base::LogLevel::Init);
ui.console().write("Connected", simple_base::LogLevel::Info);
ui.console().write("Resource unavailable", simple_base::LogLevel::Warning);
ui.console().write("Script failed", simple_base::LogLevel::Error);
ui.setConsoleVisible(true); // UI thread
```

The normal `Application::draw()` handles rendering. The Lua runtime and initialization flow feed this buffer too. Error reports use ERROR severity. Writes and snapshots are thread-safe, but the host must join producers before destroying the application.

For a host without the rest of the menu, use `core/log_buffer.h` with `ui/console_window.h`, own a `ui::ConsoleWindow`, call `show()` and then `draw(buffer, font, scale)` between ImGui NewFrame/Render. Both components have no platform or renderer calls.

## Behavior

- Drag the console header; resize from the bottom-right corner.
- The cyan arrow hides the log area to leave a compact title bar; click it again to restore the saved size. Close only hides the console. Reopen from the Lua editor's Console button or the Console page's Windowed console button.
- The small header icon or a right-click on the header opens Copy all, Clear console and Auto-scroll.
- New output follows the bottom only while already at the bottom. Reading older lines keeps the current scroll position.
- History is capped at 512 rows, each message at 4,096 bytes per row, and each write at 65,536 bytes. Multi-line messages receive a timestamp/level on every row. Clearing removes history without changing settings.
- Console placement is session-local; it is clamped when the host viewport or UI scale changes. It can remain open when F2 hides the main menu.

Preview: `run-preview.cmd --console --no-welcome`. Add `--frames 35 --capture build/qa/console.png --data build/qa/console-data` for an isolated native capture.
