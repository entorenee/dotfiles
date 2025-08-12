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
						package_uninstalled = "✗",
					},
				},
				ensure_installed = {
					"eslint_d", -- ESLint daemon for fast linting
					"prettier", -- Code formatter
					"alejandra", -- Nix formatter
					"cspell-lsp", -- Spell checker
					"yamlfmt", -- YAML formatter
					"stylua", -- Lua formatter
					"shfmt", -- Shell script formatter
					"checkmake", -- Makefile linter
					"actionlint", -- GitHub Actions linter
					"htmlhint", -- HTML linter
					"jsonlint", -- JSON linter
					"taplo", -- TOML formatter
					"sqlfluff", -- SQL formatter and linter
				},
			})
		end,
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
					"ts_ls", -- TypeScript/JavaScript
					"tailwindcss", -- Tailwind CSS
					"html", -- HTML
					"cssls", -- CSS
					"jsonls", -- JSON
					"lua_ls", -- Lua
					"nil_ls", -- Nix
				},
				automatic_installation = true,
			})
		end,
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
			local lspconfig = require("lspconfig")

			vim.lsp.config("cspell_ls", {
				cmd = {
					"cspell-lsp",
					"--config",
					vim.fn.expand("~/.config/cspell/cspell.json"),
					"--stdio",
				},
				root_dir = vim.fs.root(0, { ".git" }),
			})

			local capabilities = require("cmp_nvim_lsp").default_capabilities()

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
					prefix = "●",
				},
				signs = true,
				underline = true,
				update_in_insert = false,
				severity_sort = true,
			})

			-- Manual server configurations
			local servers = {
				ts_ls = {
					filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
					init_options = {
						preferences = {
							includeCompletionsForModuleExports = true,
							includeCompletionsForImportStatements = true,
						},
					},
				},

				tailwindcss = {
					filetypes = {
						"html",
						"css",
						"scss",
						"javascript",
						"javascriptreact",
						"typescript",
						"typescriptreact",
						"vue",
						"svelte",
					},
					settings = {
						tailwindCSS = {
							experimental = {
								classRegex = {
									"tw`([^`]*)",
									'tw="([^"]*)',
									'tw={"([^"}]*)',
									"tw\\.\\w+`([^`]*)",
									"tw\\(.*?\\)`([^`]*)",
								},
							},
						},
					},
				},

				nil_ls = {
					filetypes = { "nix" },
				},

				lua_ls = {
					settings = {
						Lua = {
							runtime = { version = "LuaJIT" },
							diagnostics = {
								globals = {},
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
					vim.notify(string.format("Failed to setup %s: %s", server_name, err), vim.log.levels.ERROR)
				end
			end

			-- Use mason-lspconfig handlers for any servers not manually configured
			local mason_lspconfig = require("mason-lspconfig")
			if mason_lspconfig.setup_handlers then
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
		end,
	},
}
