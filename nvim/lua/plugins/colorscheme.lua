-- Using lazy.nvim
return {
  "metalelf0/black-metal-theme-neovim",
  lazy = false,
  priority = 1000,
  config = function()
    require("black-metal").setup({
      theme = "venom",
      variant = "light",
    })
    require("black-metal").load()
  end,
}
