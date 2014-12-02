--- Dialog UI elements.

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

-- Method modules --
local data = require("corona_ui.dialog_impl.data")
local items = require("corona_ui.dialog_impl.items")
local layout = require("corona_ui.dialog_impl.layout")
local methods = require("corona_ui.dialog_impl.methods")
local net = require("corona_ui.patterns.net")
local utils = require("corona_ui.dialog_impl.utils")

-- Corona globals --
local display = display

-- Exports --
local M = {}

-- Import dialog methods.
local Methods = {} 

for _, mod in ipairs{ data, items, layout, methods } do
	for k, v in pairs(mod) do
		Methods[k] = v
	end
end

--- DOCME
-- @pgroup group Group to which the dialog will be inserted.
-- @ptable options
--
-- **CONSIDER**: In EVERY case so far I've used _name_ = **true**...
function M.Dialog (group, options)
	--
	local Dialog = display.newGroup()

	group:insert(Dialog)

	--
	utils.AddBack(Dialog, 1, 1)

	--
	local igroup = display.newGroup()

	Dialog.m_items = igroup

	Dialog:insert(igroup)

	--
	if options then
		Dialog.m_namespace = options.namespace

		if options.is_modal then
			--	common.AddNet(group, Dialog)
		end
	end

	-- Install methods from implementation modules.
	for k, v in pairs(Methods) do
		Dialog[k] = v
	end

	return Dialog
end

-- Export the module.
return M