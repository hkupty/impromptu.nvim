-- luacheck: globals unpack vim utf8
local nvim = vim.api
local utils = require("impromptu.utils")
local heuristics = require("impromptu.heuristics")
local sessions = require("impromptu.sessions")

local internals = {}

internals.show = function(obj)
  if obj.buffer == nil then
    nvim.nvim_command("belowright 15 new")
    nvim.nvim_command("setl nonu nornu nobuflisted buftype=nofile bufhidden=wipe nolist")
    local cb = nvim.nvim_get_current_buf()
    obj.buffer = cb
  end

  return obj
end

internals.line = function(opts, columns, width)
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

internals.div = function(sz)
  return string.rep("─", sz)
end

internals.sub_div = function(sz)
  return string.rep("•", sz)
end

internals.window_for_obj = function(obj)
  obj = internals.show(obj)

  local winnr = nvim.nvim_call_function("bufwinnr", {obj.buffer})
  local window = nvim.nvim_call_function("win_getid", {winnr})
  local sz = nvim.nvim_win_get_width(window)
  local h = nvim.nvim_win_get_height(window)

  return {
    window = window,
    width = sz,
    height = h
  }
end

internals.get_options = function(obj)
  local opts = {}
  local selected = {}

  local set_key = function(line)
    line.key = line.key or heuristics.get_unique_key(selected, line.description)
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
    utils.partial_last(utils.sorted_by, function(i) return i.description end)
  )

  utils.map(lines, function(line)
    if line.key then
      selected[line.key] = 1
    end
    return nil
  end)

  lines = utils.extend({opts, utils.map(lines, set_key)})

  if #lines > 12 then
    -- TODO fallback to fuzzy finder when available
    nvim.nvim_err_writeln("More than 12 items on the list. Visualization won't be optimal")
  end

  if obj.quitable then
    table.insert(lines, {
      key = "q",
      item = "__quit",
      description = "Close this prompt",
    })
  end

  return lines
end

internals.get_header = function(obj)
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

internals.get_footer = function(obj)
  local footer = ""

  if obj.footer ~= nil then
    footer = obj.footer
  end

   return footer
 end

 internals.do_mappings = function(obj, opts)
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

internals.draw = function(obj, opts, window_ops)
  local header = internals.get_header(obj)
  local footer = internals.get_footer(obj)
  local footer_sz = footer ~= "" and 2 or 1

  local content = {}

  if header ~= "" then
    table.insert(content, header)
    table.insert(content, internals.div(window_ops.width))
  end

  table.insert(content, "")

  for _, line in ipairs(internals.line(opts, obj.columns, window_ops.width)) do
    table.insert(content, line)
  end

  if #content + footer_sz < window_ops.height then
    local fill = window_ops.height - #content  - footer_sz
    for _ = 1, fill do
      table.insert(content, "")
    end
  end

  if footer ~= "" then
    table.insert(content, internals.div(window_ops.width))
    table.insert(content, footer)
  end

  return content
 end

internals.render = function(obj)

  local opts = internals.get_options(obj)
  local window_ops = internals.window_for_obj(obj)

  internals.do_mappings(obj, opts)
  local content = internals.draw(obj, opts, window_ops)

  nvim.nvim_buf_set_option(obj.buffer, "modifiable", true)
  nvim.nvim_buf_set_option(obj.buffer, "readonly", false)
  nvim.nvim_buf_set_lines(obj.buffer, 0, -1, false, content)
  nvim.nvim_buf_set_option(obj.buffer, "modifiable", false)
  nvim.nvim_buf_set_option(obj.buffer, "readonly", true)
end

internals.destroy = function(obj_or_session)
  local obj

  if type(obj_or_session) == "table" then
    obj = obj_or_session
  else
    obj = sessions[obj_or_session]
  end

  local window = math.floor(nvim.nvim_call_function("bufwinnr", {obj.buffer}))
  nvim.nvim_command(window .. ' wincmd w | q')
end

internals.tree = function(session, option)
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

return internals
