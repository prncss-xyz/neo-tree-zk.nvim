--This file should have all functions that are in the public api and either set
--or read the state of this source.

local vim = vim
local utils = require("neo-tree.utils")
local renderer = require("neo-tree.ui.renderer")
local items = require("neo-tree.sources.zk.lib.items")
local events = require("neo-tree.events")
local manager = require("neo-tree.sources.manager")

local M = { name = "zk" }

local wrap = function(func)
	return utils.wrap(func, M.name)
end

local get_state = function()
	return manager.get_state(M.name)
end

local follow_internal = function()
	if vim.bo.filetype == "neo-tree" or vim.bo.filetype == "neo-tree-popup" then
		return
	end
	local path_to_reveal = manager.get_path_to_reveal(true)
	if not utils.truthy(path_to_reveal) then
		return false
	end

	local state = get_state()
	if state.current_position == "float" then
		return false
	end
	if not state.path then
		return false
	end
	local window_exists = renderer.window_exists(state)
	if window_exists then
		local node = state.tree and state.tree:get_node()
		if node then
			if node:get_id() == path_to_reveal then
				-- already focused
				return false
			end
		end
		renderer.focus_node(state, path_to_reveal, true)
	end
end

M.default_config = {
	follow_current_file = true,
	window = {
		mappings = {
			["n"] = "change_query",
		},
	},
}

M.follow = function()
	if vim.fn.bufname(0) == "COMMIT_EDITMSG" then
		return false
	end
	utils.debounce("neo-tree-zk-follow", function()
		return follow_internal()
	end, 100, utils.debounce_strategy.CALL_LAST_ONLY)
end

---Navigate to the given path.
---@param path string Path to navigate to. If empty, will navigate to the cwd.
M.navigate = function(state, path, path_to_reveal)
	state.dirty = false
	if path_to_reveal then
		-- FIX:
		renderer.position.set(state, path_to_reveal)
	end
	items.get_zk(state)
end

---Configures the plugin, should be called before the plugin is used.
---@param config table Configuration table containing any keys that the user
--wants to change from the defaults. May be empty to accept default values.
M.setup = function(config, global_config)
	if config.before_render then
		--convert to new event system
		manager.subscribe(M.name, {
			event = events.BEFORE_RENDER,
			handler = function(state)
				local this_state = get_state()
				if state == this_state then
					config.before_render(this_state)
				end
			end,
		})
	end

	if global_config.enable_refresh_on_write then
		manager.subscribe(M.name, {
			event = events.VIM_BUFFER_CHANGED,
			handler = function(args)
				if utils.is_real_file(args.afile) then
					manager.refresh(M.name)
				end
			end,
		})
	end

	if config.bind_to_cwd then
		manager.subscribe(M.name, {
			event = events.VIM_DIR_CHANGED,
			handler = wrap(manager.refresh),
		})
	end

	if global_config.enable_diagnostics then
		manager.subscribe(M.name, {
			event = events.VIM_DIAGNOSTIC_CHANGED,
			handler = wrap(manager.diagnostics_changed),
		})
	end

	--Configure event handlers for modified files
	if global_config.enable_modified_markers then
		manager.subscribe(M.name, {
			event = events.VIM_BUFFER_MODIFIED_SET,
			handler = wrap(manager.modified_buffers_changed),
		})
	end

	-- Configure event handler for follow_current_file option
	if config.follow_current_file then
		manager.subscribe(M.name, {
			event = events.VIM_BUFFER_ENTER,
			handler = M.follow,
		})
		manager.subscribe(M.name, {
			event = events.VIM_TERMINAL_ENTER,
			handler = M.follow,
		})
	end
end

return M
