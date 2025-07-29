-- TypeScript/JavaScript specific configuration
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "javascript", "typescript", "typescriptreact", "javascriptreact" },
	callback = function()
		-- Language-specific keymaps
		local opts = { buffer = true, silent = true }
		vim.keymap.set("n", "<leader>ji", "ggO/* eslint-disable */<Esc>", opts)
		vim.keymap.set("n", "<leader>je", "ggO/* eslint-enable */<Esc>", opts)
	end,
})

return {}
