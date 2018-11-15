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

Impromptu is a library for using within neovim. It allows you to build menus or to prompt the user for information.

It is designed to be generic and with a simple architecture to allow any kind of menus/customizations.

## API

Below are described the public functions of the impromptu API:

### impromptu.core.ask

Is a function that takes [`ask_args`](#ask_args) and returns a [`session`](#session).
Produces a menu on the bottom of the currend window with a header and the supplied options.
It can produce a [tree-based menu](tree-based.md) if options contain children.

## Data Structures

All data types are supplied here:

### ask_args
```lua
args = {
  quitable = "Optional argument (default: true). If true, adds a quit option to the menu",
  question = "The title of the menu",
  options = "Set of options to be displayed", -- Check options below
  handler = "A handler function that takes the session and the chosen option" -- Check handler and session below
}
```
See also: [handler](#handler), [session](#session) and [options](#options)

### handler
```lua
handler = {
  args = {
    session = "The state of the current menu prompt", -- See session below
    option = "The selected `item` value of the provieded options" -- See options below
  },
  expected_behavion = "Should cause the desired side-effect with supplied args",
  returns = "A boolean representing whether the menu should be closed or not"
}
```
See also: [session](#session) and [options](#options)

### session
```lua
session = {
  [[A proxy to the `impromptu.sessions` table.
  Contains all the information regarding the state of the menu.]],
  session_id = "The number of the session on the impromptu.sessions table",
  quitable = "Whether an extra option for quiting should be provided",
  header = "The header value of the session",
  breadcrumbs = "When traversing tree-based options, this value is populated with the selected path",
  lines = "The options list (or tree)", -- See options below
  handler = "The handler function for this session" -- See handler above
}
```
See also: [options](#options) and [handler](#handler)

### options
```lua
options = {
  [[The set of options provided for the menu.
  Can be either a list or a tree.]],

  -- Its values can be represented as a key-val map:
  option_key = {
    description = "The description of the option",
    key = "Optional argument. Value will be inferred trying to find the best key based on the description",
    item = "Optional argument. Will use `option_key` if not provided. Will be given to the handler function if this option is selected."
    children = "Optional argument that takes the same structure as `options`."
  }

  -- Or as a list:
  {
    description = "The description of the option",
    key = "Optional argument. Value will be inferred trying to find the best key based on the description",
    item = "Will be given to the handler function if this option is selected."
    children = "Optional argument that takes the same structure as `options`."
  }

}
```
