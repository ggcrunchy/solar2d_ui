--- TODO

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Standard library imports --
local pairs = pairs

-- Modules --
local table_funcs = require("tektite_core.table.funcs")
local utils = require("corona_utils.linkage.utils")

-- Exports --
local M = {}

--
--
--

--- DOCME
function M.BuildEntry (level, mod, entry, acc, links)
	acc = acc or {}

	local built, instances = table_funcs.Copy(entry), entry.instances

	if instances then
		built.instances = nil

		mod.EditorEvent(entry.type, "build_instances", built, {
			instances = instances, labels = level.labels, links = links
		})
	--[[
		entry:SendMessage("build_generated_names", built, {
			generated_names = entry.generated_names, labels = level.labels, links = env.links
		})
	]]
	end

	built.positions = nil

	if entry.uid then
		level.links[entry.uid], built.uid = built

		local prep_link, cleanup = mod.EditorEvent(entry.type, "prep_link", level, built)
--[[
	entry:SendMessage("prep_link", level, built)
]]
		level.links[built] = prep_link

		if cleanup then
			level.cleanup = level.cleanup or {}
			level.cleanup[built] = cleanup
		end
	end

	built.name = nil

	mod.EditorEvent(entry.type, "build", level, entry, built)
--[[
	entry:SendMessage("fix_built_data", level, entry, built)
]]
	acc[#acc + 1] = built

	return acc
end

local function LinkEntries (event, entry1, aname1, entry2, aname2, cleanup)
	event.entry, event.entry_attachment_point_name, event.other, event.other_attachment_point_name = entry1, aname1, entry2, aname2

	entry1:dispatchEvent(event)

	if event.needs_cleanup then -- has state needed while linking, but irrelevant once built
		cleanup = cleanup or {}
		cleanup[entry1], event.needs_cleanup = true
	end

	event.entry, event.entry_attachment_point_name, event.other, event.other_attachment_point_name = nil

	return cleanup
end

--- DOCME
function M.ResolveLinks_Build (list, labels)
	if list then
		local link_event, cleanup = { name = "link_entries", labels = labels }

		utils.VisitLinks(list, {
			resolve_pair = function(entry1, aname1, entry2, aname2)
				cleanup = LinkEntries(link_event, entry1, aname1, entry2, aname2, cleanup)
				cleanup = LinkEntries(link_event, entry2, aname2, entry1, aname1, cleanup)
			end,

			visit_entry = function(entry, index)
				entry.uid = index
			end
		})

		if cleanup then
			local cleanup_event = { name = "link_entry_cleanup" }

			for entry in pairs(cleanup) do
				cleanup_event.entry = entry

				entry:dispatchEvent(cleanup_event)
			end
		end

		-- TODO: level.labels, level.links = nil (in caller)
	end
end

return M