
-- Nenyoo scripting-API foundation bootstrap. Loaded FIRST. Establishes version + layer registry.
nenyoo = nenyoo or {}
nenyoo.api_version = 1
nenyoo.foundation  = true
-- nenyoo.layers(): the compat-layer descriptors registered by the loader ({ <name> = globals }).
function nenyoo.layers() return __api_layers or {} end
