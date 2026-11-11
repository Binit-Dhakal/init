return {
    "williamboman/mason.nvim",
    dependencies = {
        'neovim/nvim-lspconfig',
        "williamboman/mason-lspconfig.nvim",
        'hrsh7th/cmp-nvim-lsp', --
        'folke/neodev.nvim',
        "SmiteshP/nvim-navic",
        "SmiteshP/nvim-navbuddy"
    },
    config = function()
        require('neodev').setup()
        local mason = require("mason")
        local mason_lspconfig = require("mason-lspconfig")
        local navbuddy = require("nvim-navbuddy")

        navbuddy.setup()

        local navic = require("nvim-navic")



        local servers = {
            lua_ls = {
                Lua = {
                    workspace = { checkThirdParty = false },
                    telemetry = { enable = false },
                }
            },
            ruff_lsp = {
            },
            pyright = {},
            html = { filetype = { "html", "css", "tmpl" } },
            tailwindcss = {},
            gopls = {},
            clangd = {},
            ts_ls = { preferences = { disableSuggestions = true } },
            volar = { filetype = { "vue" } },
        }

        local capabilities = vim.lsp.protocol.make_client_capabilities()
        capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)
        local on_attach = function(client, bufnr)
            local nmap = function(keys, func, desc)
                if desc then
                    desc = 'LSP: ' .. desc
                end
                vim.keymap.set('n', keys, func, { buffer = bufnr, desc = desc })
            end

            nmap('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
            nmap('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')

            nmap('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
            nmap('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
            nmap('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
            nmap('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')
            nmap('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
            nmap('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')

            -- See `:help K` for why this keymap
            nmap('K', vim.lsp.buf.hover, 'Hover Documentation')
            nmap('<C-k>', vim.lsp.buf.signature_help, 'Signature Documentation')

            -- Lesser used LSP functionality
            nmap('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
            nmap('<leader>wa', vim.lsp.buf.add_workspace_folder, '[W]orkspace [A]dd Folder')
            nmap('<leader>wr', vim.lsp.buf.remove_workspace_folder, '[W]orkspace [R]emove Folder')
            nmap('<leader>wl', function()
                print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
            end, '[W]orkspace [L]ist Folders')

            -- Create a command `:Format` local to the LSP buffer
            vim.api.nvim_buf_create_user_command(bufnr, 'Format', function(_)
                vim.lsp.buf.format()
            end, { desc = 'Format current buffer with LSP' })

            if client.server_capabilities.documentSymbolProvider then
                navic.attach(client, bufnr)
                navbuddy.attach(client, bufnr)
            end
        end


        mason.setup({
            ui = {
                icons = {
                    package_pending = " ",
                    package_installed = "󰄳 ",
                    package_uninstalled = " 󰚌",
                },

                keymaps = {
                    toggle_server_expand = "<CR>",
                    install_server = "i",
                    update_server = "u",
                    check_server_version = "c",
                    update_all_servers = "U",
                    check_outdated_servers = "C",
                    uninstall_server = "X",
                    cancel_installation = "<C-c>",
                },
            },
        })

        mason_lspconfig.setup({
            ensure_installed = vim.tbl_keys(servers),
            automatic_installation = true,
        })

        -- Neovim 0.11+ native LSP API.
        -- `mason-lspconfig` removed `setup_handlers`, and the old
        -- `require('lspconfig')[server].setup{}` framework is deprecated.
        -- We register each server with `vim.lsp.config` and turn it on with
        -- `vim.lsp.enable`. The global '*' config applies shared defaults.
        vim.lsp.config("*", {
            on_attach = on_attach,
            capabilities = capabilities,
        })

        for server_name, server_settings in pairs(servers) do
            vim.lsp.config(server_name, {
                on_attach = on_attach,
                capabilities = capabilities,
                settings = server_settings,
                filetypes = (server_settings or {}).filetypes,
            })
            vim.lsp.enable(server_name)
        end
    end
}
