local vim = vim
local renderer = require("neo-tree.ui.renderer")
local file_items = require("neo-tree.sources.common.file-items")
local log = require("neo-tree.log")

local M = {}

local default_query = {
	desc = "All",
	query = {},
}

---@param bufnr number?
---@return string? path inside a notebook
local function resolve_notebook_path_from_dir(path, cwd)
	-- if the buffer has no name (i.e. it is empty), set the current working directory as it's path
	if not path or path == "" then
		path = cwd
	end
	if not require("zk.util").notebook_root(path) then
		if not require("zk.util").notebook_root(cwd) then
			-- if neither the buffer nor the cwd belong to a notebook, use $ZK_NOTEBOOK_DIR as fallback if available
			if vim.env.ZK_NOTEBOOK_DIR then
				path = vim.env.ZK_NOTEBOOK_DIR
			end
		else
			-- the buffer doesn't belong to a notebook, but the cwd does!
			path = cwd
		end
	end
	-- at this point, the buffer either belongs to a notebook, or everything else failed
	return path
end

function M.scan(state, callback)
	require("zk.api").list(
		state.path,
		vim.tbl_extend("error", { select = { "absPath", "title" } }, state.zk.query.query),
		function(err, notes)
			if err then
				log.error("Error querying notes " .. vim.inspect(err))
				return
			end
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
			for id_, _ in pairs(context.folders) do
				table.insert(state.default_expanded_nodes, id_)
			end
			file_items.deep_sort(root.children)
			renderer.show_nodes({ root }, state)

			state.loading = false
			if type(callback) == "function" then
				callback()
			end
		end
	)
end

---Get a table of all open buffers, along with all parent paths of those buffers.
---The paths are the keys of the table, and all the values are 'true'.
function M.get_zk(state, path)
	if state.loading then
		return
	end
	state.loading = true
	if not state.zk then
		state.path = resolve_notebook_path_from_dir(path, vim.fn.getcwd())
		state.zk = {
			query = default_query,
		}
	end

	M.scan(state)
end

return M
