-- Custom filetype detection
vim.filetype.add({
  extension = {
    mdx = "mdx",
    astro = "astro",
  },
  filename = {
    [".mdx"] = "mdx",
  },
  pattern = {
    [".*%.mdx$"] = "mdx",
    [".*%.astro$"] = "astro",
  },
})