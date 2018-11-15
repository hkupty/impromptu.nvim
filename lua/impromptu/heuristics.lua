local keys = require("impromptu.utils").keys

local heuristics = {}

local heatmap = {
  {"h", "f"},
  {"j", "d", "b", "y", "v", "r"},
  {"k", "s", "n", "i", "e", "g"},
  {"a", "l", "t", "c", "n"},
  {"w", "x", "u", "m", "q", "z", "o", "p", ";",  ".", ",", "[", "]"},
  {"1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="},
  {"A", "S", "D", "F", "G", "H", "J", "K", "L"},
  {"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "Z", "X", "C", "V", "B", "N", "M", "<", ">", "?"},
  {"!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "_", "+", "\\", "|"},
}

local to_rx = function(tbl)
  local rx = "["

  for x = 1, #tbl -1 do
    rx = rx .. tbl[x] .. ","
  end

  rx = rx .. tbl[#tbl] .. "].-"

  return rx
end

local find = function(v, tbl)
  for _,v_ in ipairs(tbl) do
    if v_ == v then
      return true
    end
  end
end

local difference = function(a, b)
   local ret = {}
   for _, v in ipairs(a) do
     if not find(v, b) then
     table.insert(ret, v)
     end
   end
   return ret
 end

heuristics.get_unique_key = function(selected, word)
  for _, patterns in ipairs(heatmap) do
    local possible = difference(patterns, keys(selected))
    if #possible > 0 then
      local match = string.match(word, to_rx(possible))
      if match ~= nil then
        return match
      end
    end
  end

  -- Fallback. return unique key that is optimal but not in the word.
  for _, patterns in ipairs(heatmap) do
    local optimal = difference(patterns, keys(selected))
    if #optimal > 0 then
      return optimal[1]
    end
  end
end

return heuristics
