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
local common = require("s3_editor.Common") -- urgh...
local linkage_utils = require("corona_utils.linkage.utils")
local table_funcs = require("tektite_core.table.funcs")

-- Exports --
local M = {}

--
--
--

--- DOCME
function M.BuildEntry (level, mod, entry, acc)
	acc = acc or {}

	local built, instances = table_funcs.Copy(entry), entry.instances

	if instances then
		built.instances = nil

		mod.EditorEvent(entry.type, "build_instances", built, {
			instances = instances, labels = level.labels, links = common.GetLinks()
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

--- DOCME
function M.ResolveLinks_Build (level)
	if level.links then
		linkage_utils.ReadLinks(level, function(entry, index)
			entry.uid = index
		end, function(list, entry1, entry2, sub1, sub2)
			local func1, func2 = list[entry1], list[entry2]

			if func1 then
				func1(entry1, entry2, sub1, sub2)
			end

			if func2 then
				func2(entry2, entry1, sub2, sub1)
			end
		end)

		-- Tidy up any information only needed during linking.
		if level.cleanup then
			for entry, cleanup in pairs(level.cleanup) do
				cleanup(entry)
			end

			level.cleanup = nil
		end

		-- All labels and link information have now been incorporated into the entries
		-- themselves, so there is no longer need to retain it in the editor state.
		level.labels, level.links = nil
	end
end

return M