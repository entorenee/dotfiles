-- Editor enhancement plugins
return {
  -- Commentary
  "tpope/vim-commentary",
  
  -- GitHub Copilot
  {
    "github/copilot.vim",
    event = "InsertEnter",
  },
  
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    dependencies = {
      "github/copilot.vim",
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require('CopilotChat').setup()
    end
  },

  -- Linting and fixing
  {
    "dense-analysis/ale",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      vim.g.ale_fix_on_save = 1       -- Auto-fix on save
    end
  },
}
