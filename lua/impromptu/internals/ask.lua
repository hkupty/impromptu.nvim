-- luacheck: globals unpack vim utf8
local nvim = vim.api
local utils = require("impromptu.utils")
local heuristics = require("impromptu.heuristics")
local shared = require("impromptu.internals.shared")

local ask = {}


ask.tree = function(session, option)
  local breadcrumbs = utils.clone(session.breadcrumbs)

  if option == "__up" then
    breadcrumbs[#breadcrumbs] = nil
  else
    table.insert(breadcrumbs, option)
  end

  local lens = utils.interleave(breadcrumbs, 'children')

  local at = utils.get_in(session.lines, lens)

  if at ~= nil then
    session.breadcrumbs = breadcrumbs
    return true
  else
    return false
  end
end

ask.line = function(opts, columns, width)
  local opt_to_line = function(line)
    return  "  [" .. line.key .. "] " .. line.description
  end
  local lines = {}
  local column_width = math.floor(width / columns)

  for ix = 1, #opts + (#opts - 1) % columns, columns do
    local ln = {}
    for j = 1, columns do
      local k = opts[ix * j]
      if k ~= nil then
        local line = opt_to_line(k)
        local padding = column_width - utf8.len(line)
        table.insert(ln, line .. string.rep(" ", padding))
      end
    end
    table.insert(lines, table.concat(ln, ""))
  end

    return lines
end

ask.get_options = function(obj)
  local opts = {}
  local selected = {}

  local set_key = function(line)
    line.key = line.key or heuristics.get_unique_key(selected, line.description)
    selected[line.key] = 1
    return line
  end

  if #obj.breadcrumbs >= 1 then
    table.insert(opts, {
        key = "h",
        description = "Move up one level",
        item = "__up"
      })
    selected.h = 1
  end

  if obj.quitable then
    selected.q = 1
  end

  local lines = utils.chain(obj.breadcrumbs,
    utils.partial_last(utils.interleave, "children"),
    utils.partial(utils.get_in, obj.lines),
    utils.partial_last(utils.key_to_attr, "item"),
    utils.partial_last(utils.sorted_by, obj.sort)
  )

  utils.map(lines, function(line)
    if line.key then
      selected[line.key] = 1
    end
    return nil
  end)

  lines = utils.extend({opts, utils.map(lines, set_key)})

  if obj.quitable then
    table.insert(lines, {
      key = "q",
      item = "__quit",
      description = "Close this prompt",
    })
  end

  return lines
end

ask.get_header = function(obj)
  local header = ""

  if obj.header ~= nil then
    header = obj.header

    if #obj.breadcrumbs >= 1 then
      local pointer = {}
      local descrs = {}
      for _, v in ipairs(obj.breadcrumbs) do
        table.insert(pointer, v)
        local at = utils.get_in(obj.lines, pointer)
        if at ~= nil then
          table.insert(descrs, at.description)
        end
        table.insert(pointer, "children")
      end
      header = header .. " [" .. table.concat(descrs, "/") .. "]"
    end
  end

   return header
 end

 ask.do_mappings = function(obj, opts)
  nvim.nvim_command("mapclear <buffer>")

   for _, v in ipairs(opts) do
     nvim.nvim_command(
       "map <buffer> " ..
       v.key ..
       " <Cmd>lua require('impromptu').callback("  ..
       obj.session_id ..
       ", '" ..
       v.item ..
       "')<CR>"
     )
   end
 end

ask.draw = function(obj, opts, window_ops)
  local header = ask.get_header(obj)

  local content = {}

  if header ~= "" then
    table.insert(content, header)
    table.insert(content, shared.div(window_ops.width))
  end

  table.insert(content, "")

  local columns

  if type(obj.columns) == "number" then
    columns = obj.columns
  elseif type(obj.columns) == "function" then
    columns = obj:columns(opts, window_ops.width)
  else
    columns = 1
  end

  for _, line in ipairs(ask.line(opts, columns, window_ops.width)) do
    table.insert(content, line)
  end

  if #content < window_ops.height then
    local fill = window_ops.height - #content
    for _ = 1, fill do
      table.insert(content, "")
    end
  end

  return content
 end

ask.render = function(obj)

  local opts = ask.get_options(obj)
  local window_ops = shared.window_for_obj(obj)
  local content

  ask.do_mappings(obj, opts)
  content = ask.draw(obj, opts, window_ops)

  nvim.nvim_buf_set_option(obj.buffer, "modifiable", true)
  nvim.nvim_buf_set_option(obj.buffer, "readonly", false)
  nvim.nvim_buf_set_lines(obj.buffer, 0, -1, false, content)
  nvim.nvim_buf_set_option(obj.buffer, "modifiable", false)
  nvim.nvim_buf_set_option(obj.buffer, "readonly", true)
end

ask.handle = function(obj, option)
  if ask.tree(obj, option) then
    return false
  else
    return obj:handler(option)
  end
end

return ask
