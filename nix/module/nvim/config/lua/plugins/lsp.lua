-- LSP configuration with Mason
return {
  -- Mason for installing LSP servers
  {
    "williamboman/mason.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("mason").setup({
        ui = {
          icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗"
          }
        }
      })
    end
  },

  -- Mason LSP config bridge
  {
    "williamboman/mason-lspconfig.nvim",
    lazy = false,
    priority = 900,
    dependencies = { "williamboman/mason.nvim" },
    config = function()
      local mason_lspconfig = require("mason-lspconfig")
      mason_lspconfig.setup({
        -- Automatically install these LSP servers
        ensure_installed = {
          "ts_ls",     -- TypeScript/JavaScript
          "tailwindcss",  -- Tailwind CSS
          "html",         -- HTML
          "cssls",        -- CSS
          "jsonls",       -- JSON
          "lua_ls",       -- Lua
          "nil_ls",       -- Nix
        },
        automatic_installation = true,
      })

      -- Store mason_lspconfig in a global for later use
      _G.mason_lspconfig = mason_lspconfig
    end
  },

  -- LSP Configuration
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    priority = 800,
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "williamboman/mason-lspconfig.nvim",
    },
    config = function()
      local lspconfig = require('lspconfig')

      -- Wait for mason-lspconfig to be available
      local mason_lspconfig = _G.mason_lspconfig
      if not mason_lspconfig then
        vim.notify("Mason LSP Config not ready, retrying...", vim.log.levels.WARN)
        -- Retry after a short delay
        vim.defer_fn(function()
          mason_lspconfig = require("mason-lspconfig")
          if mason_lspconfig and mason_lspconfig.setup_handlers then
            -- Setup handlers here if needed
          end
        end, 100)
        return
      end

      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      local function on_attach(_, bufnr)
        local opts = { noremap = true, silent = true, buffer = bufnr }
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
        vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
        vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
        vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
        vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
      end

      -- Configure diagnostic display
      vim.diagnostic.config({
        virtual_text = {
          prefix = '●',
        },
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
      })

      -- Manual server configurations (bypassing mason-lspconfig handlers for now)
      local servers = {
        ts_ls = {
          filetypes = { "typescript", "typescriptreact", "typescript.tsx", "javascript", "javascriptreact" },
        },

        tailwindcss = {
          filetypes = { "html", "css", "scss", "javascript", "javascriptreact", "typescript", "typescriptreact", "vue", "svelte" },
          settings = {
            tailwindCSS = {
              experimental = {
                classRegex = {
                  "tw`([^`]*)",
                  "tw=\"([^\"]*)",
                  "tw={\"([^\"}]*)",
                  "tw\\.\\w+`([^`]*)",
                  "tw\\(.*?\\)`([^`]*)",
                },
              },
            },
          },
        },

        nil_ls = {
          filetypes = { "nix" }
        },

        lua_ls = {
          settings = {
            Lua = {
              runtime = { version = 'LuaJIT' },
              diagnostics = {
                globals = {}
              },
              workspace = {
                library = vim.api.nvim_get_runtime_file("", true),
                checkThirdParty = false,
              },
              telemetry = { enable = false },
            },
          },
        },

        html = {},
        cssls = {},
        jsonls = {},
      }

      -- Setup servers manually
      for server_name, config in pairs(servers) do
        config.on_attach = on_attach
        config.capabilities = capabilities

        local ok, err = pcall(lspconfig[server_name].setup, config)
        if not ok then
          vim.notify(
            string.format("Failed to setup %s: %s", server_name, err),
            vim.log.levels.ERROR
          )
        end
      end

      -- Try to use mason-lspconfig handlers if available (fallback)
      if mason_lspconfig and mason_lspconfig.setup_handlers then
        mason_lspconfig.setup_handlers({
          function(server_name)
            -- Only setup if we haven't already configured it manually
            if not servers[server_name] then
              lspconfig[server_name].setup({
                on_attach = on_attach,
                capabilities = capabilities,
              })
            end
          end,
        })
      end
    end
  },
}
