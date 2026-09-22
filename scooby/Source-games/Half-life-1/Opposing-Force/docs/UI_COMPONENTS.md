# UI components

The base ports the existing Scooby GMod UI components. Keep changes in these shared components so a new project uses the same controls and spacing.

| Component | Source in this template | GMod reference |
| --- | --- | --- |
| Charcoal/cyan palette | `src/ui/theme.cpp` | `lumia_theme.cpp` |
| Toggle, slider, color picker, tabs, collapsible groups, responsive columns, settings popup | `src/ui/components/lumia.cpp` | `lumia_widgets.cpp` |
| Sidebar and aligned header actions | `src/ui/application.cpp` | `navigation.h`, `menu.cpp`, `feature_browser.cpp` |
| Watermark, FPS graph, bind panel | `src/ui/components/overlay_panels.h` | `visuals/overlay_panels.h` |
| Radar | `src/ui/components/radar_panel.h` | `visuals/radar_panel.h` |
| Welcome card | `src/ui/components/welcome.h` | `menu/welcome.h` |
| Shared config/script browser | `src/ui/file_browser.cpp` | `settings_tab.cpp` config cards |
| Borderless hotkey bars | `src/ui/settings_page.cpp` | `hotkey_editor.cpp` |

Game-specific labels and data come from the template host. The demo entity provider stays independent of these components. The default UI/ESP/overlay face is Verdana, code uses Consolas, branding uses Segoe UI Semibold, and icons use the included Lucide font. Custom fonts can be supplied through `assets/fonts` as described in the porting guide.

## Groups and columns

`Application::draw()` establishes a `ui::WidgetScope` with the active UI scale and icon font. Additional pages inside the application can directly use the public API from `simple_base/ui/widgets.h`:

```cpp
ui::LumiaBeginColumns("my_page", 2); // requested column count; reflows when space is limited
if (ui::LumiaBeginGroup("First group")) {
    ui::toggle("Enable", &enabled);
    ui::slider("Amount", &amount, 0.f, 100.f, "%.0f");
}
ui::LumiaEndGroup(); // always pair, even when the group is closed
ui::LumiaNextColumn();
if (ui::LumiaBeginGroup("Second group")) {
    // Your controls.
}
ui::LumiaEndGroup();
ui::LumiaEndColumns();
```

For a separate host UI outside `Application`, own a `ui::WidgetContext` and establish `ui::WidgetScope scope(context, scale, lucideFont)` during each frame. Call on the ImGui render thread. Scale is a physical-pixel multiplier; the host remains responsible for the ImGui context and renderer backend. Fonts are baked at their displayed pixel size rather than stretching a low-resolution atlas.

Choose columns per page, up to five, and call `LumiaNextColumn()` between logical columns. Interface uses three columns: Scale; Menu Key and Language; Appearance and Layout. Config and Scripts retain their browser pane beside stacked action cards. Columns keep a compact maximum width, so a single group does not fill a wide page. Narrow windows reflow columns onto additional rows with vertical scrolling, keeping groups inside the visible width. Logical control IDs and collapsed states survive reflow. The shell draws tabs, search, and the star above the scrollable page body, so the scrollbar starts level with the groups and the header remains fixed. Use a unique `PushID` for repeated controls. Lua tabs, the script selector, and editor toolbar have separate ID scopes so identically named actions cannot collide.

## Settings links

Set `AppOptions::openLink` to your host's URL-opening callback. It runs only when Website, Discord or GitHub is clicked on Settings > Scooby Links. The welcome card has no Website/Discord buttons. The Windows preview supplies `ShellExecuteA`; an embedded host that omits it gets copy-to-clipboard behavior.

## Verification

The UI tests hover the Lua tabs and toolbar with ImGui duplicate-ID diagnostics enabled, click the group headers and feature gear/color controls, and draw all pages from 360x280 through 8K. The DX11 smoke run exercises resizing, fullscreen/windowed transitions, minimization, independent UI/overlay scales, and complete renderer recreation.
