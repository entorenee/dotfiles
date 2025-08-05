-- Autocommands (if you have any)
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Ensure LSP attaches to buffers properly
local lsp_group = augroup("LspRestart", { clear = true })
autocmd("BufEnter", {
  group = lsp_group,
  pattern = { "*.js", "*.ts", "*.jsx", "*.tsx", "*.lua", "*.html", "*.css" },
  desc = "Restart LSP if not attached",
  callback = function()
    -- Small delay to allow LSP to attach naturally first
    vim.defer_fn(function()
      local clients = vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })
      if #clients == 0 then
        -- Only restart if mason-lspconfig is ready
        local mason_ok, mason_lspconfig = pcall(require, "mason-lspconfig")
        if mason_ok then
          -- Stop any cspell_ls instances before restarting
          local all_clients = vim.lsp.get_clients()
          for _, client in ipairs(all_clients) do
            if client.name == "cspell_ls" then
              client.stop()
            end
          end
          vim.cmd("LspRestart")
        end
      end
    end, 100)
  end,
})

-- Auto-kill cspell_ls to prevent conflicts with cspell_lsp
local cspell_group = augroup("CSpellManagement", { clear = true })
autocmd("LspAttach", {
  group = cspell_group,
  desc = "Stop cspell_ls when it attaches to prevent conflicts",
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.name == "cspell_ls" then
      client.stop()
    end
  end,
})

-- Auto-reload buffer when file changes outside Neovim
local reload_group = augroup("AutoReload", { clear = true })
autocmd({"FocusGained", "BufEnter", "CursorHold", "CursorHoldI"}, {
  group = reload_group,
  pattern = "*",
  desc = "Check if buffer needs reloading",
  command = "checktime",
})
