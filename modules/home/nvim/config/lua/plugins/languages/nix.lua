-- Nix language specific configuration
vim.api.nvim_create_autocmd("FileType", {
	pattern = "nix",
	callback = function()
		-- Helper function to run nix flake commands from the correct directory
		local function run_nix_flake_command(command)
			local flake_dir = vim.fn.findfile("flake.nix", ".;")
			if flake_dir ~= "" then
				local dir = vim.fn.fnamemodify(flake_dir, ":h")
				vim.cmd("!cd " .. vim.fn.shellescape(dir) .. " && nix flake " .. command)
			else
				vim.cmd("!nix flake " .. command)
			end
		end

		-- Language-specific keymaps
		local opts = { buffer = true, silent = true }
		vim.keymap.set("n", "<leader>nf", function() run_nix_flake_command("check") end, opts)
		vim.keymap.set("n", "<leader>nu", function() run_nix_flake_command("update") end, opts)
	end,
})

return {}

