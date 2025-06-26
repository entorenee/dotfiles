-- Autocommands (if you have any)
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Example: Auto-format on save for certain filetypes
local format_group = augroup("FormatOnSave", { clear = true })
autocmd("BufWritePre", {
  group = format_group,
  pattern = {"*.js", "*.ts", "*.jsx", "*.tsx"},
  desc = "Format files on save",
  callback = function()
    -- This would integrate with your formatter
    -- vim.lsp.buf.format()
  end,
})