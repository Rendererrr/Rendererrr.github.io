
-- dx.* — overlay/2D drawing facade over the engine draw/text/font tables (render thread only).
dx = dx or {}
dx.rect         = draw.rect
dx.rect_outline = draw.rect_outline
dx.line         = draw.line
dx.circle       = draw.circle
dx.image        = draw.image
-- dx.text(font, x, y, str, r, g, b, a): draw text using a `font` table id.
function dx.text(fnt, x, y, str, r, g, b, a) return text.draw(fnt, x, y, str, r, g, b, a) end
-- dx.measure(font, str) -> width in pixels.
function dx.measure(fnt, str) return text.width(fnt, str) end
-- dx.screen() -> width, height (logical pixels).
function dx.screen() return ctx.screen_w(), ctx.screen_h() end
