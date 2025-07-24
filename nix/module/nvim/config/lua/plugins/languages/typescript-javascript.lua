return {
  -- Modern TypeScript/React support with nvim-treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          "javascript",
          "typescript",
          "tsx",
          "html",
          "css",
          "json",
          "lua"
        },
        highlight = {
          enable = true,
        },
        indent = {
          enable = true,
        },
      })
    end
  },
}
