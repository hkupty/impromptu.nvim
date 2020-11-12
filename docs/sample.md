# Sample

Below is a sample based on the function that was the actual reason why Impromptu was created:

```lua
local nvim = vim.api
local impromptu = require("impromptu")
local iron = require("iron")

_G.set_preferred_repl = function()
  local cb = nvim.nvim_get_current_buf()
  local ft = nvim.nvim_buf_get_option(cb, 'filetype')
  local defs = iron.core.list_definitions_for_ft(ft)

  local opts = {}

  for _, kv in ipairs(defs) do
        opts[kv[1]] = {
          description = table.concat(kv[2].command, " ")
        }
  end

  impromptu.ask{
    question = "Select preferred repl",
    options = opts,
    handler = function(_, opt)
      iron.core.set_config{preferred = {[ft] = opt}}
      return true
    end
  }
end

nvim.nvim_command("command! -nargs=0 PickRepl lua set_preferred_repl()")
```
