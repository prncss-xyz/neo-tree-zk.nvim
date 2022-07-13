local vim = vim
local renderer = require("neo-tree.ui.renderer")
local file_items = require("neo-tree.sources.common.file-items")
local log = require("neo-tree.log")

local M = {}

local default = {
  desc = "All",
  query = {},
}

---Get a table of all open buffers, along with all parent paths of those buffers.
---The paths are the keys of the table, and all the values are 'true'.
function M.get_zk(state)
  if state.loading then
    return
  end
  state.loading = true
  state.zk = state.zk or default

  local id
  local tree = state.tree
  if tree then
    _, id = pcall(function()
      local _, node = tree:get_node()
      return node:get_id()
    end)
  end

  require("zk.api").list(
    id,
    vim.tbl_extend("error", { select = { "absPath", "title" } }, state.zk.query),
    function(err, notes)
      if err then
        log.error("Error querying notes " .. vim.inspect(err))
        return
      end
      state.path = state.path or vim.fn.getcwd()
      local context = file_items.create_context(state)
      -- Create root folder
      local root = file_items.create_item(context, state.path, "directory")
      root.name = vim.fn.fnamemodify(root.path, ":~")
      root.loaded = true
      root.search_pattern = state.search_pattern
      context.folders[root.path] = root

      for _, note in pairs(notes) do
        local success, item = pcall(file_items.create_item, context, note.absPath, "file")
        if success then
          item.extra = {
            title = note.title,
          }
        else
          log.error("Error creating item for " .. note.absPath .. ": " .. item)
        end
      end

      state.default_expanded_nodes = {}
      for id, _ in pairs(context.folders) do
        table.insert(state.default_expanded_nodes, id)
      end
      file_items.deep_sort(root.children)
      renderer.show_nodes({ root }, state)

      state.loading = false
    end
  )
end

return M
