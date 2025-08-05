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

  -- Formatting with Mason tools
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    config = function()
      require("conform").setup({
        formatters_by_ft = {
          typescript = { "prettier" },
          typescriptreact = { "prettier" },
          javascript = { "prettier" },
          javascriptreact = { "prettier" },
          json = { "prettier" },
          css = { "prettier" },
          html = { "prettier" },
          markdown = { "prettier" },
          nix = { "alejandra" },
          yaml = { "yamlfmt" },
          yml = { "yamlfmt" },
          lua = { "stylua" },
          sh = { "shfmt" },
          bash = { "shfmt" },
          zsh = { "shfmt" },
          toml = { "taplo" },
          sql = { "sqlfluff" },
        },
        format_on_save = {
          timeout_ms = 500,
          lsp_fallback = true,
        },
      })
    end,
  },

  -- Linting with Mason tools
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local lint = require("lint")

      lint.linters_by_ft = {
        typescript = { "eslint_d" },
        typescriptreact = { "eslint_d" },
        javascript = { "eslint_d" },
        javascriptreact = { "eslint_d" },
        make = { "checkmake" },
        yaml = { "actionlint" },
        html = { "htmlhint" },
        json = { "jsonlint" },
        sql = { "sqlfluff" },
      }

      local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })
      vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
        group = lint_augroup,
        callback = function()
          lint.try_lint()
        end,
      })
    end,
  },

  -- Git blame functionality
  {
    "f-person/git-blame.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("gitblame").setup({
        enabled = false, -- Start with blame disabled
        message_template = " <summary> • <sha> • <date> • <author>",
        date_format = "%m/%d/%y",
        display_virtual_text = false, -- Disable virtual text to avoid overflow. Use Lualine instead
      })
    end,
  },

  -- Use Lualine for better statusline output
  {
    'nvim-lualine/lualine.nvim',
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local git_blame = require('gitblame')
      require("lualine").setup({
        options = {
          theme = 'palenight',
        },
        sections = {
          lualine_c = {
            { git_blame.get_current_blame_text, cond = git_blame.is_blame_text_available }
          },
          lualine_x = {
            {
              function()
                local words = vim.fn.wordcount()
                return string.format('Words: %d Chars: %d', words.words, words.chars)
              end,
              cond = function()
                return vim.bo.filetype == 'markdown'
              end
            }
          }
        }
      })
    end
  }
}
