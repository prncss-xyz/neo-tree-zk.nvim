--This file should contain all commands meant to be used by mappings.
local renderer = require("neo-tree.ui.renderer")
local vim = vim
local cc = require("neo-tree.sources.common.commands")
local utils = require("neo-tree.utils")
local manager = require("neo-tree.sources.manager")
local log = require("neo-tree.log")
local fs_actions = require("neo-tree.sources.filesystem.lib.fs_actions")
local scan = require("neo-tree.sources.zk.lib.items").scan

local M = {}

M.name = "zk"

local refresh = utils.wrap(manager.refresh, "zk")

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
		item.input(state.zk.notebookPath, id, function(res)
			state.zk.query = res
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

local function show_only_explicitly_opened(state, eod, path_to_reveal)
	local expanded_nodes = renderer.get_expanded_nodes(state.tree)
	local state_changed = false
	for _, id in ipairs(expanded_nodes) do
		local is_explicit = eod[id]
		if not is_explicit then
			local is_in_path = path_to_reveal and path_to_reveal:sub(1, #id) == id
			if is_in_path then
				is_explicit = true
			end
		end
		if not is_explicit then
			local node = state.tree:get_node(id)
			if node then
				node:collapse()
				state_changed = true
			end
		end
	end
	if state_changed then
		renderer.redraw(state)
	end
end

-- TODO: directories on the fly
M.add = function(state)
	local tree = state.tree
	local node = get_folder_node(tree)
	local in_directory = node:get_id()
	local dir = in_directory:sub(state.path:len() + 1)
	if dir:len() > 0 then
		dir = dir:sub(2)
	end
	local eod = state.explicitly_opened_directories or {} -- FIX: note working: always empty
	vim.ui.input({ prompt = "new note title" }, function(input)
		if input then
			require("zk.api").new(state.path, {
				title = input,
				dir = dir,
			}, function(err, res)
				if err then
					log.error("Error querying notes " .. vim.inspect(err))
					return
				end
				vim.cmd("e " .. res.path)
				scan(state, function()
					show_only_explicitly_opened(state, eod, res.path)
					renderer.focus_node(state, res.path, true)
				end)
			end)
		end
	end)
end

M.delete = function(state)
	local tree = state.tree
	local node = tree:get_node()
	local id = node:get_id()
	fs_actions.delete_node(id, function()
		require("zk.api").index(state.path, {}, function(err)
			if err then
				log.error("Error indexing notes " .. vim.inspect(err))
			end
			local eod = state.explicitly_opened_directories or {} -- FIX: note working: always empty
			scan(state, function()
				-- show_only_explicitly_opened(state, eod)
			end)
		end)
	end)
end

-- TODO: delete_note_visual

M.refresh = refresh

cc._add_common_commands(M)

return M
