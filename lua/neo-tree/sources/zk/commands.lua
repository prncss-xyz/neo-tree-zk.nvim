--This file should contain all commands meant to be used by mappings.

local vim = vim
local cc = require("neo-tree.sources.common.commands")
local utils = require("neo-tree.utils")
local inputs = require("neo-tree.ui.inputs")
local popups = require("neo-tree.ui.popups")
local manager = require("neo-tree.sources.manager")
local events = require("neo-tree.events")
local log = require("neo-tree.log")
local fs_actions = require("neo-tree.sources.filesystem.lib.fs_actions")

local M = {}

local refresh = utils.wrap(manager.refresh, "zk")
local redraw = utils.wrap(manager.redraw, "zk")

local function format_item(item)
  return item.desc
end

M.change_query = function(state)
  local tree = state.tree
  local node = tree:get_node()
  local id = node:get_id()
  local items = {}
  for _, item in pairs(require("neo-tree.sources.zk.lib.queries")) do
    table.insert(items, item)
  end
  vim.ui.select(items, { prompt = "zk query", format_item = format_item }, function(item)
    item.input(id, function(res)
      state.zk = res
      refresh()
    end)
  end)
end

-- copied from neo-tree/sources/common/commands.lua
---Gets the node parent folder recursively
---@param tree table to look for nodes
---@param node table to look for folder parent
---@return table table
local function get_folder_node(tree, node)
  if not node then
    node = tree:get_node()
  end
  if node.type == "directory" then
    return node
  end
  return get_folder_node(tree, tree:get_node(node:get_parent_id()))
end

-- TODO: directories on the fly
M.add = function(state, toggle_directory)
  local tree = state.tree
  local node = get_folder_node(tree)
  local in_directory = node:get_id()
  local dir = in_directory:sub(state.path:len() + 1)
  if dir:len() > 0 then
    dir = dir:sub(2)
  end
  vim.ui.input({ prompt = "new note title" }, function(input)
    if input then
      require("zk.api").new(in_directory, {
        title = input,
        dir = dir,
      }, function(err, res)
        if err then
          log.error("Error querying notes " .. vim.inspect(err))
          return
        end
        vim.cmd("e " .. res.path)
        refresh()
      end)
    end
  end)
end

M.delete_note = function(state)
  local tree = state.tree
  local node = tree:get_node()
  local id = node:get_id()
  fs_actions.delete_node(id, function()
    require("zk.api").index(state.path, {}, function(err)
      if err then
        log.error("Error indexing notes " .. vim.inspect(err))
      end
      refresh()
    end)
  end)
end

-- TODO: delete_note_visual

M.refresh = refresh

cc._add_common_commands(M)

return M
