-- Basic vim settings
local opt = vim.opt
local g = vim.g

-- Leader keys
g.mapleader = ";"
g.maplocalleader = ";"
g.python3_host_prog = '/opt/homebrew/bin/python3'

-- Editor settings
vim.cmd('colorscheme slate')
opt.tabstop = 2
opt.softtabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.autoindent = true
opt.number = true
opt.relativenumber = true
opt.ruler = true
opt.hlsearch = true
opt.ignorecase = true
opt.smartcase = true
opt.backspace = {'indent', 'eol', 'start'}
opt.visualbell = true
opt.wildignore:append({'*.DS_Store', '*.d', '*.mlast', '*.cmi', '*.cmj', '*.cmt', '*reast', '*.ast'})