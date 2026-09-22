local entities = opposingforce.entities()
print("Opposing Force: " .. opposingforce.session())
print("Received entities: " .. #entities)
for index, entity in ipairs(entities) do
 if index > 12 then break end
 print(entity.name .. " | " .. math.floor(entity.distance) .. " m")
end
