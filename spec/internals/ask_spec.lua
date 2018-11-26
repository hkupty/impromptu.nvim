-- luacheck: globals insulate setup describe it assert mock
-- luacheck: globals before_each after_each
local inspect = require("inspect")

_G.tap = function(obj)
  print(inspect(obj))
  return obj
end

local check = {
  command = function() return assert.spy(_G.vim.api.nvim_command) end,
  call_function = function() return assert.spy(_G.vim.api.nvim_call_function) end,
}


insulate("About #ask form", function()
    before_each(function()
        _G.vim = mock({ api = {
                    nvim_call_function = function(_, _) return 1 end,
                    nvim_command = function(_) return "" end,
                    nvim_get_option = function(_) return "" end,
                    nvim_get_var = function(_) return "" end,
            }})

        _G.os = mock({
                execute = function(_) return 0 end,
            })
        end)

  after_each(function()
     package.loaded['impromptu.internals.ask'] = nil
     package.loaded['impromptu.internals.shared'] = nil
   end)

  describe("when writing #options to the buffer", function()
    it("returns the options serialized as string", function()
      local ask = require('impromptu.internals.ask')
      local opts = {
        {key = "a", description = "Option a"}
      }
      local lines = ask.line(opts, 1, 30)

      assert.are_same({
        "  [a] Option a"
      }, lines)

      check.call_function().was_called(#opts)
    end)

    it("columnizes the items 2x2", function()
      local ask = require('impromptu.internals.ask')
      local opts = {
        {key = "a", description = "Option a"},
        {key = "b", description = "Option b"}
      }
      local lines = ask.line(opts, 2, 30)

      assert.are_same({
        "  [a] Option a                [b] Option b"
      }, lines)

      check.call_function().was_called(#opts)
    end)

    it("columnizes the items 3x2", function()
      local ask = require('impromptu.internals.ask')
      local opts = {
        {key = "a", description = "Option a"},
        {key = "b", description = "Option b"},
        {key = "c", description = "Option c"}
      }
      local lines = ask.line(opts, 2, 30)

      assert.are_same({
        "  [a] Option a                [b] Option b",
        "  [c] Option c"
      }, lines)

      check.call_function().was_called(#opts)
    end)

    it("columnizes the items 3x1", function()
      local ask = require('impromptu.internals.ask')
      local opts = {
        {key = "a", description = "Option a"},
        {key = "b", description = "Option b"},
        {key = "c", description = "Option c"}
      }
      local lines = ask.line(opts, 1, 30)

      assert.are_same({
        "  [a] Option a",
        "  [b] Option b",
        "  [c] Option c"
      }, lines)

      check.call_function().was_called(#opts)
    end)
  end)
end)
