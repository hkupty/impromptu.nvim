
-- The fzy matching algorithm
--
-- by Seth Warn <https://github.com/swarn>
-- a lua port of John Hawthorn's fzy <https://github.com/jhawthorn/fzy>
--
-- > fzy tries to find the result the user intended. It does this by favouring
-- > matches on consecutive letters and starts of words. This allows matching
-- > using acronyms or different parts of the path." - J Hawthorn

local ffi = require'ffi'

local native


ffi.cdef[[
int has_match(const char *needle, const char *haystack, int is_case_sensitive);

// typedef double score_t;
// match* originally returns score_t;

double match(const char *needle, const char *haystack, int is_case_sensitive);
double match_positions(const char *needle, const char *haystack, uint32_t *positions, int is_case_sensitive);

]]

-- @param positions - the C positions object
-- @param length - length of positions
-- @returns - lua array of boundaries where the expression matched
local function positions_to_lua(positions, length)
  local result = {}
  local l
  local chunk
  for i = 0, length - 1, 1  do
    local p = positions[i] + 1

    if l == nil then
      l = p
      chunk = {l}
    elseif p > l + 1 then
      table.insert(chunk, l)
      table.insert(result, chunk)
      chunk = {p}
    end
    l = p
  end
  if chunk ~= nil then
    table.insert(chunk, l)
    table.insert(result, chunk)
  end

  return result
end


-- Constants

local SCORE_GAP_INNER = -0.01
local SCORE_MAX = math.huge
local SCORE_MIN = -math.huge
local MATCH_MAX_LENGTH = 1024

local fzy = {}

function fzy.load(path)
  native = ffi.load(path)
end

function fzy.has_match(needle, haystack)
  local is_case_sensitive = false
  return native.has_match(needle, haystack, is_case_sensitive) == 1
end

function fzy.score(needle, haystack)
  local length = #needle
  local positions = ffi.new('uint32_t[' .. length .. ']', {})
  local score = native.match_positions(needle, haystack, positions, false)
  return score
end

function fzy.positions(needle, haystack)
  local length = #needle
  local positions = ffi.new('uint32_t[' .. length .. ']', {})
  local is_case_sensitive = false

  local score = native.match_positions(needle, haystack, positions, is_case_sensitive)

  return {positions_to_lua(positions, length), score}
end


-- If strings a or b are empty or too long, `fzy.score(a, b) == fzy.get_score_min()`.
function fzy.get_score_min()
  return SCORE_MIN
end

-- For exact matches, `fzy.score(s, s) == fzy.get_score_max()`.
function fzy.get_score_max()
  return SCORE_MAX
end

-- For all strings a and b that
--  - are not covered by either `fzy.get_score_min()` or fzy.get_score_max()`, and
--  - are matched, such that `fzy.has_match(a, b) == true`,
-- then `fzy.score(a, b) > fzy.get_score_floor()` will be true.
function fzy.get_score_floor()
  return (MATCH_MAX_LENGTH + 1) * SCORE_GAP_INNER
end


-- Adapted to generator
function fzy.filter(needle, lines)
  local ix = 1
  local max = #lines

  -- Spaces are discarded
  needle = table.concat(needle, "")

  if max == 0 then
    return function() return end
  end

  local function nxt()
    local line = lines[ix]
    ix = ix + 1

    if line == nil then
      return
    elseif line.description == "" then
      return nxt()
    end

    if native.has_match(needle, line.description, false) == 1 then
      local positions = fzy.positions(needle, line.description)
      line.positions = positions[1]
      line.score = positions[2]
      return line
    end
    return nxt()
  end

  return nxt
end

return fzy
