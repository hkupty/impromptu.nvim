# impromptu.nvim

Create prompts fast and easy

## What?

Impromptu is a lua utility for neovim that allows you to easily create prompts as means of causing commands/functions to be called on neovim.

It is designed in a way that it should be simple to create and reuse prompts for whatever need you have.

The root problem it was meant to solve was changing configurations on the flight for other plugins, such as [iron.nvim](https://github.com/Vigemus/iron.nvim).

## Talk is cheap, show me the code

Using impromptu is as simple as doing the following:

```lua
local impromptu = require("impromptu")

_G.my_quit_menu = function()
  impromptu.core.ask{
    quitable = false,
    question = "Do you want to quit?",
    options = {
      {
        key = "y",
        item = "yes",
        description = "Quit neovim"
      },
      {
        key = "n",
        item = "no",
        description = "Keep neovim open"
      }
    },
    handler = function(_, opt)
      if opt == "yes" then
        vim.api.nvim_command("qa!")
      else
        vim.api.nvim_command("echo 'Phew!'")
      end
    end
  }
end

nvim.nvim_command("command! -nargs=0 QuitMenu lua my_quit_menu()")
```

The public function `ask` takes a question, some options and a handler function.
Additionally, it takes a `quitable` option, which conveniently creates a `quit` option of you.

The options consit of:
- `item`: the value that your handler function will receive;
- `description`: the text value that will be shown on the prompt;
- `[key]`: The key that will be bound to that option.
  - If not supplied, it will try to get the best possible option from the description.

That's it! Quick and simple!

## TODO

- [ ] Fuzzy finder
- [ ] Highlighting
- [ ] Drawing enhancements
- [ ] Restoring previous session
- [ ] Async capabilities
