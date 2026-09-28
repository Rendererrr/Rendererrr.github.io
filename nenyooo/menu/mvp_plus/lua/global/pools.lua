-- pools collection helpers over Nenyoo's native pool snapshots. Script-thread only.
pools = pools or {}

function pools.ped_count() local count = pools.peds(); return count end
function pools.ped_capacity() local _, capacity = pools.peds(); return capacity end
function pools.vehicle_count() local count = pools.vehicles(); return count end
function pools.vehicle_capacity() local _, capacity = pools.vehicles(); return capacity end
function pools.object_count() local count = pools.objects(); return count end
function pools.object_capacity() local _, capacity = pools.objects(); return capacity end

function pools.handle_at(kind, index)
    local row = pools.snapshot(kind)[math.floor(tonumber(index) or 0) + 1]
    return row and row.handle or 0
end

function pools.pointer_at(kind, index)
    local row = pools.snapshot(kind)[math.floor(tonumber(index) or 0) + 1]
    return row and row.pointer or 0
end

function pools.rendered_pointers(kind)
    local out = {}
    for _, row in ipairs(pools.snapshot(kind)) do out[#out + 1] = row.pointer end
    return out
end
