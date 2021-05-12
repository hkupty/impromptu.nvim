-- luacheck: globals unpack vim utf8
local showcase = {}
local shared = require("impromptu.internals.shared")
local utils = require("impromptu.utils")
local heuristics = require("impromptu.heuristics")

-- TODO Generalize and parametrize
showcase.lines_to_grid = function(opts, max_sz)
  local grid = {}

  for ix = 0, #opts + (#opts - 1) % max_sz, max_sz do
    local column = {}
    for j = 1, max_sz do
      local k = opts[ix + j]
      if k ~= nil then
        table.insert(column, "  " .. k)
      else
        break
      end
    end

    if #column ~= 0 then
      table.insert(grid, column)
    end
  end

  return grid
end

showcase.get_actions = function(obj)
  local selected = {}

  local set_key = function(line)
    line.key = heuristics.get_unique_key(selected, line.description)
    selected[line.key] = 1
    return line
  end

  local lines = utils.key_to_attr(obj.actions or {}, "index")

  lines = utils.map(lines, set_key)

  table.insert(lines, {
    key = "c",
    index = "__quit",
    description = "Close",
  })

  return lines
end

showcase.do_mappings = function(obj, opts)
  vim.api.nvim_command("mapclear <buffer>")

  for _, v in ipairs(opts) do
    vim.api.nvim_command(
      "map <nowait> <buffer> " ..
      v.key ..
      " <Cmd>lua require('impromptu').callback("  ..
      obj.session_id ..
      ", '" ..
      v.index ..
      "')<CR>"
      )
  end
end

showcase.transpose = function(obj)
  local grid = {{}, {}}
  for k, v in pairs(obj.lines) do
    table.insert(grid[1], k)
    table.insert(grid[2], v)
  end
  return grid
end

showcase.render = function(obj)
  local actions
  local window_ops = shared.window_for_obj(obj)

  -- Overwrite value for extra space for actions
  window_ops.bottom_offset = 3

  local the_actions = showcase.get_actions(obj)
  showcase.do_mappings(obj, the_actions)
  actions = shared.render_grid(
    shared.lines_to_grid(utils.map(the_actions, shared.render_line), window_ops.bottom_offset - 1), true)
  local show = shared.render_grid(showcase.transpose(obj), false)

  local content = {}

  local add = function(coll)
    for _, line in ipairs(coll) do
      table.insert(content, line)
    end
  end

  add(shared.header(obj, window_ops))
  add(show)
  add(shared.spacer(show, window_ops))
  add(shared.footer(actions, window_ops))

  obj.height = #content

  vim.api.nvim_buf_set_option(obj.buffer, "modifiable", true)
  vim.api.nvim_buf_set_option(obj.buffer, "readonly", false)
  vim.api.nvim_buf_set_lines(obj.buffer, 0, -1, false, content)
  vim.api.nvim_buf_set_option(obj.buffer, "readonly", true)
  vim.api.nvim_buf_set_option(obj.buffer, "modifiable", false)

  return obj
end

showcase.handle = function(obj, option)
  local selected = obj.actions[option]
  selected.index = option
  return obj:handler(selected)
end

return showcase
