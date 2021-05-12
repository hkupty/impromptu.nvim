-- luacheck: globals unpack vim
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
  vim.api.nvim_command("mapclear <buffer>")

   for _, v in ipairs(opts) do
     vim.api.nvim_command(
       "map <nowait> <buffer> " ..
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
  local content = {}
  local lines_to_grid = obj.lines_to_grid or shared.lines_to_grid
  local grid = lines_to_grid(utils.map(opts, shared.render_line), window_ops.height - window_ops.top_offset)
  local lines = shared.render_grid(grid, obj.is_compact)

  local add = function(coll)
    for _, line in ipairs(coll) do
      table.insert(content, line)
    end
  end

  add(shared.header(obj, window_ops))
  add(lines)
  add(shared.spacer(lines, window_ops))

  return content
 end

ask.do_hl = function(obj, opts)
  for ix = #obj.hls, 1, -1 do
    vim.fn.matchdelete(obj.hls[ix])
    table.remove(obj.hls, ix)
  end

  table.insert(obj.hls, vim.fn.matchaddpos("Operator", {1, 20}))

  for _, opt in ipairs(opts) do
    local hl

    if opt.hl then
      hl = opt.hl
      table.insert(obj.hls,
        vim.fn.matchadd(hl, utils.str_escape(shared.render_line(opt))
        )
      )
    end
  end

end

ask.render = function(obj)

  local opts = ask.get_options(obj)
  local window_ops = shared.window_for_obj(obj)
  local content

  ask.do_mappings(obj, opts)
  ask.do_hl(obj, opts)
  content = ask.draw(obj, opts, window_ops)

  vim.api.nvim_buf_set_option(obj.buffer, "modifiable", true)
  vim.api.nvim_buf_set_option(obj.buffer, "readonly", false)
  vim.api.nvim_buf_set_lines(obj.buffer, 0, -1, false, content)
  vim.api.nvim_buf_set_option(obj.buffer, "modifiable", false)
  vim.api.nvim_buf_set_option(obj.buffer, "readonly", true)

  return obj
end

ask.handle = function(obj, option)
  if ask.tree(obj, option) then
    return false
  else
    local lines = utils.chain(obj.breadcrumbs,
      utils.partial_last(utils.interleave, "children"),
      utils.partial(utils.get_in, obj.lines))
    local selected = lines[option]
    selected.index = option
    return obj:handler(selected)
  end
end

return ask
