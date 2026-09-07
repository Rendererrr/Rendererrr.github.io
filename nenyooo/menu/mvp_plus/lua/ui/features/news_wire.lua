-- News Wire: override the loading-screen story (BIGFEED) shown while GTA transitions
-- between story and online sessions. The C++ hook picks ONE story at random from the
-- pool below every time GTA fires PostNews. Missing fields fall through to whatever
-- the game was about to send.
--
-- To use your own image: drop a PNG named e.g. my_logo.png into the folder that
-- "Open Images Folder" opens (%LOCALAPPDATA%\Nenyoo\Plus\Textures), then call
--   news_wire.load_image("my_logo")
-- and set  txd = "my_logo"  on any story. To register a PNG from an absolute path
-- instead, pass it as a second arg: news_wire.load_image("my_logo", "C:\\path.png").
--
-- Caveat on images: this route swaps the pixels behind a (txd, tex) pair the game
-- already has resident. If the pair we invent has no stock texture behind it the
-- image slot may render blank (text always still shows). The safe fallback is to
-- set  txd = "some_existing_streamed_txd"  on your story and load_image that pair.
--
-- Edit this file, save, then Reload from the Scripts page for changes to take effect.

news_wire.clear_stories()

-- Ship the bundled Nenyoo logo. Delivered by cdn_assets::sync into the Textures folder.
news_wire.load_image("nenyoo_logo")

-- Mixed tone: professional welcome, playful boot, feature spotlights, brand line.

news_wire.add_story{
    headline = "WELCOME TO NENYOO",
    content  = "Session ready. Have a good run.",
    subtitle = "System",
    url      = "nenyoo.tools",
    txd      = "nenyoo_logo",
}

news_wire.add_story{
    headline = "NENYOO ONLINE",
    content  = "Everything armed. Try not to break anything.",
    subtitle = "Boot",
    url      = "nenyoo.tools",
    txd      = "nenyoo_logo",
}

news_wire.add_story{
    headline = "TIP: SILENT AIM",
    content  = "Aim + Reload activates Silent Aim. Configure it in Weapon > Aim.",
    subtitle = "Tip",
    url      = "nenyoo.tools",
    txd      = "nenyoo_logo",
}

news_wire.add_story{
    headline = "TIP: SPOONER",
    content  = "The Spooner records everything you place. Saves live in Documents\\Nenyoo\\spooner.",
    subtitle = "Tip",
    url      = "nenyoo.tools",
    txd      = "nenyoo_logo",
}

news_wire.add_story{
    headline = "LOADING SCREEN",
    content  = "Brought to you by Nenyoo.",
    subtitle = "Brand",
    url      = "nenyoo.tools",
    txd      = "nenyoo_logo",
}
