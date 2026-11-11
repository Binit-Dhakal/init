return {
	"catppuccin/nvim",
	name = "catppuccin",
	config = function()
		require("catppuccin").setup {
			flavour = "mocha", -- latte, frappe, macchiato, mocha
			term_colors = true,
			transparent_background = false,
			no_italic = false,
			no_bold = false,
			styles = {
				comments = {},
				conditionals = {},
				loops = {},
				functions = {},
				keywords = {},
				strings = {},
				variables = {},
				numbers = {},
				booleans = {},
				properties = {},
				types = {},
			},
			color_overrides = {
				mocha = {
					base = "#000000",
					mantle = "#000000",
					crust = "#000000",
				},
			},
			integrations = {
				-- Richer, theme-aware colors for the diff viewer and gutter signs.
				diffview = true,
				gitsigns = true,
			},
			highlight_overrides = {
				mocha = function(C)
					return {
						TabLineSel = { bg = C.pink },
						CmpBorder = { fg = C.surface2 },
						Pmenu = { bg = C.none },
						TelescopeBorder = { link = "FloatBorder" },

						-- ---- Prettier git diff colors (GUI-like) ----
						-- Whole changed/added/removed lines: soft tinted backgrounds.
						DiffAdd = { bg = "#20303b" },               -- added line
						DiffChange = { bg = "#20303b" },            -- changed line
						DiffDelete = { bg = "#3a2730", fg = C.red },-- removed line
						DiffText = { bg = "#3d5a4c" },              -- the CHANGED WORDS inside a changed line (vivid)

						-- Diffview's own groups (side-by-side view)
						DiffviewDiffAddAsDelete = { bg = "#3a2730" },
						DiffviewDiffDelete = { fg = C.surface1 },   -- dim the ╱ fill area

						-- gitsigns gutter + inline word-diff: make changed chars pop
						GitSignsAdd = { fg = C.green },
						GitSignsChange = { fg = C.blue },
						GitSignsDelete = { fg = C.red },
						GitSignsAddInline = { bg = "#3d5a4c" },
						GitSignsChangeInline = { bg = "#3d5a4c" },
						GitSignsDeleteInline = { bg = "#5a3a44" },
					}
				end,
			},
		}

		vim.cmd.colorscheme "catppuccin"
	end,
}
