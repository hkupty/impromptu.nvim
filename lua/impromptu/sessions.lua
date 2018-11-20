local utils = require("impromptu.utils")
local sessions = {}

setmetatable(sessions, utils.LRU(10))

return sessions
