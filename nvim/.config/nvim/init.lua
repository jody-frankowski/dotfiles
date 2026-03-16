vim.opt.ignorecase = true -- Ignore case in search patterns
vim.opt.number = true     -- Enable line numbers

vim.opt.background = "light"
vim.opt.termguicolors = true
vim.cmd.colorscheme("base16-standardized-light")

-- Set outer terminal title
vim.opt.title = true
vim.api.nvim_create_autocmd({ "BufEnter" }, {
  pattern = { "*" },
  callback = function()
    local title = "v"
    local filename = vim.fn.expand("%:t") -- :t takes the tail
    if filename ~= "" then
      title = title .. " " .. filename
    end
    vim.opt.titlestring = title
  end,
})

-- Keybindings
-- Leader
vim.g.mapleader = " "
-- Misc
vim.keymap.set("n", "<leader>qq", ":qa<CR>")
-- Command-Line Mode Emacs Movements Keybindings
vim.keymap.set("c", "<C-a>", "<Home>")
vim.keymap.set("c", "<C-e>", "<End>")
vim.keymap.set("c", "<C-p>", "<Up>")
vim.keymap.set("c", "<C-n>", "<Down>")
vim.keymap.set("c", "<C-b>", "<Left>")
vim.keymap.set("c", "<C-f>", "<Right>")
vim.keymap.set("c", "<M-b>", "<S-Left>")
vim.keymap.set("c", "<M-f>", "<S-Right>")
vim.keymap.set("c", "<M-BS>", "<C-w>")
-- Copy, Comment, Paste
vim.keymap.set("n", "<leader>cyy", "yygccp", { remap = true, desc = "Copy line, comment, paste below" })
vim.keymap.set("x", "<leader>cy", "ygvgc'>p", { remap = true, desc = "Copy selection, comment, paste below" })
