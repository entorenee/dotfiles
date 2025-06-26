-- Entry point - loads all configuration modules

-- Load basic vim configuration
require("config.options")
require("config.keymaps")
require("config.autocmds")

-- Load plugin configuration
require("plugins")