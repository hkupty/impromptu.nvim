-- luacheck: globals unpack vim
local utils = require("impromptu.utils")
local internals = require("impromptu.internals")
local sessions = require("impromptu.sessions")

local impromptu = {}

local config = {
  ui = {
    div = "─",
    sub_div = "•"
  },
  lru = 10
}

local cache = utils.LRU(config.lru)

local proxy = function(session)
  local obj = {session_id = session}
  table.insert(cache, 1, session)

  setmetatable(obj, {
    __index = function(_, key)
      local s = sessions[session]
      return s._col[#s._col][key] or s[key]
    end,
    __newindex = function(_, key, value)
      local s = sessions[session]
      s._col[#s._col][key] = value
    end})

    return obj
end

local xf_args = {
  ask = function(args)
    if args.question ~= nil then
      args.title = args.question
      vim.api.nvim_out_write("Use `title` instead of question.\n")
    end
    return {
      quitable = utils.default(args.quitable, true),
      header = args.title,
      breadcrumbs = {},
      lines = args.options,
      handler = args.handler,
      hls = {},
      sort = utils.default(args.sort, internals.shared.sort),
      is_compact = utils.default(args.compact_columns, false),
      lines_to_grid = utils.default(args.lines_to_grid, nil),
      type = "ask",
      config = utils.default(args.config, config),
    }
  end,
  form = function(args)
    if args.questions ~= nil then
      args.options = args.questions
      vim.api.nvim_out_write("Use `options` instead of questions.\n")
    end
    return {
      header = args.title,
      questions = args.options,
      handler = args.handler,
      type = "form",
      config = utils.default(args.config, config),
    }
  end,
  filter = function(args)
    return {
      header = args.title,
      lines = args.options,
      update = internals.types.filter.update,
      slide = 0,
      offset = 0,
      hls = {},
      mappings = utils.default(args.mappings, {}),
      staged_expr = {},
      filter_exprs = {""},
      handler = args.handler,
      filter_fn = utils.default(args.filter_fn, internals.types.filter.filter_fn),
      type = "filter",
      config = utils.default(args.config, config),
    }
  end,

}

impromptu.session = function()
  local session = math.random(10000, 99999)

  sessions[session] = {
    _col = {{}},
    set = function(_, key, value)
      rawset(sessions[session], key, value)
    end,
    stack = function(this, new)
      table.insert(this._col, new)
      return this
    end,
    pop = function(this)
      table.remove(this._col, #this._col)
      return this
    end,
    render = function(this)
      return internals.render(this)
    end
  }

  return proxy(session)
end

impromptu.ask = function(args)
  return impromptu.run.ask(args):render()
end

impromptu.form = function(args)
  return impromptu.run.form(args):render()
end

impromptu.filter = function(args)
  return impromptu.run.filter(args):render()
end

impromptu.run = {}

setmetatable(impromptu.run, {
  __index = function(tbl, key)
    return function(args)
      return tbl(key, args)
    end
  end,
  __call = function(_, key, args)
    return impromptu.session():stack(impromptu.new(key, args))
  end
})

impromptu.new = {}

setmetatable(impromptu.new, {
  __index = function(tbl, key)
    return function(args)
      return tbl(key, args)
    end
  end,
  __call = function(_, key, args)
    return xf_args[key](args)
  end
})

impromptu.callback = function(session, option)
  local obj = proxy(session)

  if obj == nil then
     return
  elseif option == "__quit" then
    internals.destroy(obj)
    return
  end

  if internals.handle(obj, option) then
    internals.destroy(obj)
  else
    internals.render(obj)
  end
end

impromptu.config = {}

impromptu.config.set = function(obj)
  config = impromptu.config.merged(obj)

  return impromptu.config.get()
end

impromptu.config.get = function()
  return utils.clone(config)
end

impromptu.config.merged = function(obj)
  return utils.deep_merge(config, obj)
end

return impromptu
