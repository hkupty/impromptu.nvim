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

utils.get = function(d, k)
  if type(d) == "table" then
    return d and d[k]
  else
    return nil
  end
end

utils.get_in = function(d, k)
  local p = d
  for _, i in ipairs(k) do
    p = utils.get(p, i)
  end

  return p
end

utils.clone = function(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[utils.clone(orig_key)] = utils.clone(orig_value)
        end
        setmetatable(copy, utils.clone(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

utils.interleave = function(tbl, itn)
  local new = {}
  for _, v in ipairs(tbl) do
    table.insert(new, v)
    table.insert(new, itn)
  end

  return new
end

return utils
