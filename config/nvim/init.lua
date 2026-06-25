-- ~/.config/nvim/init.lua — minimal, dependency-free Neovim config.
-- Symlinked from the dotfiles repo. Extend with a plugin manager when you like.

local opt = vim.opt

-- General
opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.undofile = true
opt.swapfile = false
opt.termguicolors = true
opt.signcolumn = "yes"
opt.scrolloff = 5

-- Indentation
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.incsearch = true
opt.hlsearch = true

-- Leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Handy keymaps
local map = vim.keymap.set
map("n", "<leader>w", "<cmd>write<cr>", { desc = "Save" })
map("n", "<leader>q", "<cmd>quit<cr>", { desc = "Quit" })
map("n", "<esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
