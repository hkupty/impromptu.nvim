local utils = {}

utils.keys = function(tbl)
  local new = {}
  for k, _ in pairs(tbl) do
    table.insert(new, k)
  end
  return new
end

utils.LRU = function(sz)
  return {
    __newindex = function(tbl, key, value)
      local lru = rawget(tbl, "__lru_tbl")
      if lru == nil then
        lru = {}
        rawset(tbl, "__lru_tbl", lru)
      end

      table.insert(lru, key)

      if (#utils.keys(lru) - 1 >= sz) then
        local old = table.remove(lru, 1)
        rawset(tbl, old, nil)
      end

      rawset(tbl, "__lru_tbl", lru)

      rawset(tbl, key, value)
    end
  }
end

utils.default = function(val, def)
  if val ~= nil then
    return val
  else
    return def
  end
end

return utils
