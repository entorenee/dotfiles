-- Autocommands (if you have any)
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Auto-reload buffer when file changes outside Neovim
local reload_group = augroup("AutoReload", { clear = true })
autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
	group = reload_group,
	pattern = "*",
	desc = "Check if buffer needs reloading",
	command = "checktime",
})
