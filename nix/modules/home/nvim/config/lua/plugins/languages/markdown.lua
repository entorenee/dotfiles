-- Markdown language specific configuration
vim.api.nvim_create_autocmd("FileType", {
	pattern = "markdown",
	callback = function()
		-- Enable spell checking for markdown
		vim.opt_local.spell = true
		vim.opt_local.spelllang = "en_us"

		-- Set text width for better reading
		vim.opt_local.wrap = true
		vim.opt_local.linebreak = true

		-- Language-specific keymaps
		local opts = { buffer = true, silent = true }
		vim.keymap.set("n", "<leader>mp", ":!glow %<CR>", opts) -- Preview with glow if available
		vim.keymap.set("n", "<leader>mt", "o- [ ] ", opts) -- Add todo item
		vim.keymap.set("n", "<leader>mc", function()
			local line = vim.api.nvim_get_current_line()
			local new_line
			if line:match("%- %[ %]") then
				-- Unchecked -> Checked
				new_line = line:gsub("%- %[ %]", "- [x]")
			elseif line:match("%- %[x%]") then
				-- Checked -> Unchecked
				new_line = line:gsub("%- %[x%]", "- [ ]")
			else
				-- No checkbox found, do nothing
				return
			end
			vim.api.nvim_set_current_line(new_line)
		end, opts) -- Toggle checkbox

		-- Insert mode abbreviations for common markdown patterns
		vim.cmd("iabbrev <buffer> -- —") -- Convert -- to em dash
		vim.cmd("iabbrev <buffer> ``` ```<CR><CR>```<Up>") -- Create code block with cursor in middle
	end,
})

return {}
