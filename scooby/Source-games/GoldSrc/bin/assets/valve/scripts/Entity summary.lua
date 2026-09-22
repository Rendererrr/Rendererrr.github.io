-- Read-only entity snapshot example. Stop the script to remove its panel.
ui.window('hl_entities','Nearby Half-Life entities', {width=340,height=300,menu_only=true}, function()
 imgui.text(halflife.session())
 for _,entity in ipairs(halflife.entities()) do
  imgui.text(entity.name .. ' · ' .. string.format('%.1f m',entity.distance))
 end
end)

