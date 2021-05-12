-- luacheck: globals unpack vim
local utils = require("impromptu.utils")
local internals = require("impromptu.internals")
local sessions = require("impromptu.sessions")
local proxy = require("impromptu.proxy").proxy

local config = {
  ui = {
    div = "─",
    sub_div = "•"
  },
  lru = 10,
  filter = {
    do_hl = true
  }

}

config.set = function(obj)
  config = config.merged(obj)

  return config.get()
end

config.get = function()
  return utils.clone(config)
end

config.merged = function(obj)
  return utils.deep_merge(config, obj)
end

local xf_args = {
  ask = function(args)
    if args.question ~= nil then
      args.title = args.question
      vim.api.nvim_out_write("Use `title` instead of question.\n")
    end
    local ref = {
      quitable = utils.default(args.quitable, true),
      header = args.title,
      breadcrumbs = {},
      location = utils.default(args.location, "bottom"),
      lines = args.options,
      handler = args.handler,
      hls = {},
      sort = utils.default(args.sort, internals.shared.sort),
      is_compact = utils.default(args.compact_columns, false),
      lines_to_grid = utils.default(args.lines_to_grid, nil),
      type = "ask",
      config = utils.default(args.config, config),
    }
    return utils.deep_merge(ref, config.get().ask or {})
  end,
  showcase = function(args)
    local ref = {
      header = args.title,
      location = utils.default(args.location, "center"),
      lines = args.options,
      height = 10,
      actions = args.actions,
      handler = args.handler,
      type = "showcase",
      config = utils.default(args.config, config),
    }
    return utils.deep_merge(ref, config.get().showcase or {})
  end,
  form = function(args)
    local ref = {
      header = args.title,
      location = utils.default(args.location, "center"),
      lines = utils.key_to_attr(args.options, "index"),
      handler = args.handler,
      type = "form",
      config = utils.default(args.config, config),
    }
    return utils.deep_merge(ref, config.get().form or {})
  end,
  filter = function(args)
    local ret = {
      header = args.title,
      lines = args.options,
      location = utils.default(args.location, "bottom"),
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
    return utils.deep_merge(ret, config.get().filter or {})
  end,
}


local session = function()
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

local impromptu = setmetatable({session = session}, {
  __index = function(tbl, key)
    local v = rawget(xf_args, key)
    if v ~= nil then
      return function(args)
        return session():stack(v(args)):render()
      end
    end
    return rawget(tbl, key)
  end
})

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

impromptu.callback = function(session_id, option)
  local obj = proxy(session_id)

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

impromptu.recent = setmetatable({}, {
    __index = function(_, session_id)
      local ref = proxy(session_id)

      ref:set("winid", nil)
      ref:set("buffer", nil)
      ref:set("destroyed", nil)

      return ref
    end
  })

local function cfgproxy(map)
  return setmetatable(map, {
    __index = function(tbl, k)
      local path = {}

      local prevpath = rawget(tbl, "path")

      if prevpath ~= nil then
        path = prevpath
      end
      table.insert(path, k)

      return cfgproxy({path = path})
    end,
    __newindex = function(tbl, k, v)
      local cfg = {}
      cfg[k] = v
      local pathsz = #tbl.path

      for i = 1, pathsz do
        local oldcfg = cfg
        cfg = {}
        cfg[tbl.path[pathsz + 1 - i]] = oldcfg
      end

      return config.set(cfg)
    end,
    __call = function(tbl, _default)
      local prevpath = rawget(tbl, "path")
      local cfg = config.get()
      for _, k in ipairs(prevpath) do
        cfg = cfg[k]
        if cfg == nil then
          break
        end
      end
      return cfg or _default or {}
    end
  })
end

impromptu.config = cfgproxy{}

impromptu.config.set = config.set
impromptu.config.get = config.get
impromptu.config.merged = config.merged

return impromptu
