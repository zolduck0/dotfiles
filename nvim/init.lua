-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })

vim.keymap.set("n", "o", "<nop>", { noremap = true, silent = true })

vim.api.nvim_set_hl(0, "BufferLineBufferSelected", { fg = "#ffffff", bg = "#1e1e1e", bold = true })
-- vim.api.nvim_set_hl(0, "BufferLineBackground", { fg = "#888888", bg = "#1e1e1e" })

vim.keymap.set({ "n", "v" }, "d", '"_d')
vim.keymap.set({ "n", "v" }, "c", '"_c')
vim.keymap.set("i", "<CR>", function()
  if vim.fn["coc#pum#visible"]() == 1 then
    return vim.fn["coc#pum#confirm"]()
  else
    return "<CR>"
  end
end, { expr = true, silent = true })
vim.keymap.set("n", "i", "a")
vim.keymap.set("n", "a", "i")

vim.api.nvim_create_autocmd("FileType", {
  pattern = "gml",
  callback = function()
    vim.bo.commentstring = "// %s"
  end,
})

vim.keymap.set("n", "<Tab>", ":CommandExecute<CR>", {
  noremap = true,
  silent = true,
  desc = "Executar CommandExecute",
})

require("comfy-line-numbers").setup({
  labels = {
    "1",
    "2",
    "3",
    "4",
    "5",
    "11",
    "12",
    "13",
    "14",
    "15",
    "21",
    "22",
    "23",
    "24",
    "25",
    "31",
    "32",
    "33",
    "34",
    "35",
    "41",
    "42",
    "43",
    "44",
    "45",
    "51",
    "52",
    "53",
    "54",
    "55",
    "111",
    "112",
    "113",
    "114",
    "115",
    "121",
    "122",
    "123",
    "124",
    "125",
    "131",
    "132",
    "133",
    "134",
    "135",
    "141",
    "142",
    "143",
    "144",
    "145",
    "151",
    "152",
    "153",
    "154",
    "155",
    "211",
    "212",
    "213",
    "214",
    "215",
    "221",
    "222",
    "223",
    "224",
    "225",
    "231",
    "232",
    "233",
    "234",
    "235",
    "241",
    "242",
    "243",
    "244",
    "245",
    "251",
    "252",
    "253",
    "254",
    "255",
  },
  up_key = "k",
  down_key = "j",

  -- Line numbers will be completely hidden for the following file/buffer types
  hidden_file_types = { "undotree" },
  hidden_buffer_types = { "terminal", "nofile" },
})
