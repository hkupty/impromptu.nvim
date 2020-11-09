-- luacheck: globals vim
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

utils.key_to_attr = function(tbl, attr_name)
  local new = {}
  for k, v in  pairs(tbl) do
    local itm = utils.clone(v)
    itm[attr_name] = k
    table.insert(new, itm)
  end

  return new
end

utils.sorted_by = function(tbl, compare)
  local new = utils.clone(tbl)
  table.sort(new, compare)
  return new
end

utils.partial = function(fn, ...)
  local args = {...}
  return function(...)
    return fn(unpack(args), ...)
  end
end

utils.partial_last = function(fn, ...)
  local args = {...}
  return function(...)
    return fn(..., unpack(args))
  end
end

utils.chain = function(v, ...)
  local fns = {...}
  local nv = utils.clone(v)
  for _, fn in ipairs(fns) do
    nv = fn(nv)
  end
  return nv
end

utils.map = function(tbl, fn)
  local new = {}

  for _, v in ipairs(tbl) do
    table.insert(new, fn(v))
  end

  return new
end

utils.tap = function(tbl)
  print(require("inspect")(tbl))
  return tbl
end

utils.merge = function(...)
  local new = {}

  for _, tbl in ipairs(...) do
    for k, v in pairs(tbl) do
      new[k] = v
    end
  end

  return new
end

-- Taken from luarocks
utils.deep_merge = function(tgt, src)
  local dst = utils.clone(tgt)
   for k, v in pairs(src) do
      if type(v) == "table" then
         if not dst[k] then
            dst[k] = {}
         end
         if type(dst[k]) == "table" then
            dst[k] = utils.deep_merge(dst[k], v)
         else
            dst[k] = v
         end
      else
         dst[k] = v
      end
   end
   return dst
end

utils.extend = function(tbls)
  local new = {}

  for _, tbl in ipairs(tbls) do
    for _, v in ipairs(tbl) do
      table.insert(new, v)
    end
  end

  return new
end

utils.split = function(str, sep)
   local fields = {}
   local pattern = string.format("([^%s]+)", sep)
   str:gsub(pattern, function(c) fields[#fields+1] = c end)
   return fields
end

utils.trim = function(s)
  -- http://lua-users.org/wiki/StringTrim
  return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end

utils.displaywidth = function(expr, col)
  return vim.api.nvim_call_function('strdisplaywidth', { expr, col })
end

utils.strwidth = function(expr, col)
  return vim.api.nvim_call_function('strwidth', { expr, col })
end

utils.str_escape = function(expr)
  return vim.api.nvim_call_function('escape', { expr , '[]'})
end

utils.take = function(sz, iter, cinv, z)
  local count = 1

  return function(inv, c)
    if count > sz then
      return
    end

    count = count + 1
    return iter(inv, c)
  end, cinv, z
end

utils.drop = function(dropped, sz, iter, cinv, z)
  local count = math.max(sz, 0)

  local function drop_iter(inv, c)
    local result = iter(inv, c)
    if dropped ~= nil then
      table.insert(dropped, result)
    end

    if count > 0 then
      count = count - 1

      if c ~= nil then
        c = c + 1
      end
      return drop_iter(inv, c)
    end

    return result
  end

  return drop_iter, cinv, z
end

utils.replace_at = function(str, nv, at)
  return string.gsub(str, "().", {[at] = nv})
end

utils.table_from_iter = function(...)
  local arr = {}
  for k, v in ... do
    arr[k] = v
  end
  return arr
end

utils.starts_with = function(str, begining)
  return begining == "" or string.sub(str, 1, #begining) == begining
end

return utils
