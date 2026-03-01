-- Minimal NeoVim config for running tests
-- Adds plugin to runtimepath and loads plenary from lazy data dir
local plenary_path = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
vim.opt.rtp:prepend(plenary_path)
vim.opt.rtp:prepend(vim.fn.getcwd())
