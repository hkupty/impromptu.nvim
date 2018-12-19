# Impromptu.nvim

1. [What is impromptu](#what-is-impromptu?)
2. [API](#api)
    1. [impromptu.core.ask](#impromptu.core.ask)
3. [Data Structures](#data-structures)
    1. [ask_args](#ask_args)
    2. [handler](#handler)
    3. [session](#session)
    4. [options](#options)

## What is impromptu?

Impromptu is a library for usage within neovim. It allows you to build menus or to prompt the user for information.

It is designed to be generic and with a simple architecture to allow any kind of menus/customizations.

## API

Below is the public function of the impromptu API:

### impromptu.core.ask

A function that takes [`ask_args`](#ask_args) and returns a [`session`](#session).
Opens a new window containing a header and the menu from the supplied [`ask_args`](#ask_args).
The menu is [tree-based](tree-based.md) if the [`options`](#options) table contains children.

You can look at a [complete example](sample.md) to have a better idea.

## Data Structures

All data types are supplied here:

### ask_args
```lua
args = {
  quitable = "Optional (default: true). If true, adds a quit option to the menu",
  compact_columns = "Optional (default: false). If true, each column will have different widths.",
  lines_to_grid = "Optional (default: nil). If set, should transform a list of string options to a table of tables containing the options",
  question = "Optional (default: ''). The title of the menu",
  options = "Mandatory. Set of options to be displayed", -- Check options below
  handler = "Mandatory. Function taking the session and the chosen option. For tree-based menus only called for the leaf nodes." -- Check handler and session below
}
```
See also: [lines_to_grid](#lines_to_grid), [handler](#handler), [session](#session) and [options](#options).

### lines_to_grid
```lua
lines_to_grid = {
  args = {
    options = "A list of options to be printed by `ask` prompt, as string elements",
    window_ops = "Geometry information about the window"
  },
  expected_behavior = "Should process the options in a way to return a grid. Any padding or change to option str should happen here.",
  returns = "A grid, as a table of columns (which are tables of the options)."
}
```

### handler
```lua
handler = {
  args = {
    session = "The state of the current menu prompt", -- See session below
    option = "The selected `option_key` value of chosen menu option" -- See options below
  },
  expected_behavior = "Should cause the desired side-effect with supplied args",
  returns = "A boolean representing whether the menu should be closed or not"
}
```
See also: [session](#session) and [options](#options).

If the handler function needs information from the buffer that was in use before opening the menu, construct the variables containing this information in the scope outside of `ask_args`, and use it as an upvalue in `handler`. See the [example](sample.md) and the usage of the variable `ft` therein.


### session
A proxy to the `impromptu.sessions` table.  Contains all the information regarding the state of the menu.

```lua
session = {
  session_id = "Number. The number of the session on the impromptu.sessions table",
  quitable = "Boolean. Whether an extra option for quiting should be provided",
  header = "String. The header value of the session",
  breadcrumbs = "Array of Strings. When traversing tree-based options, for each selection that results in another menu, the `option_key` of the selected entry is appended to this, describing a path through the tree.",
  lines = "Table. The options list (or tree)", -- See options below
  handler = "Function. The handler function for this session" -- See handler above
}
```
See also: [options](#options) and [handler](#handler).

### options
The set of options provided for the menu.

```lua
options = {
  option_key = {
    description = "Mandatory. A string describing the option in the menu.",
    key = "Optional. A key (=character) to be pressed to select this menu entry. Value will be inferred trying to find the best key based on the description",
    children = "Optional. Table of the same structure as `options`, describing submenus."
  }

}
```
