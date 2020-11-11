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
local data = require("solar2d_ui.dialog_impl.data")
local layout = require("solar2d_ui.dialog_impl.layout")
local meta = require("tektite_core.table.meta")
local methods = require("solar2d_ui.dialog_impl.methods")
local net = require("solar2d_ui.patterns.net")
local sections = require("solar2d_ui.dialog_impl.sections")
local utils = require("solar2d_ui.dialog_impl.utils")

-- Solar2D globals --
local display = display

-- Exports --
local M = {}

--
--
--

local Methods = {} 

for _, mod in ipairs{ data, layout, methods, sections } do
	for k, v in pairs(mod) do
		Methods[k] = v
	end
end

local AugmentedMethods = meta.WeakKeyed()

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
			net.AddNet(group, Dialog)
		end
	end

	--
	local augment, methods = options and options.augment

	if augment then
		methods = AugmentedMethods[augment]

		if not methods then
			methods = {}

			for k, v in pairs(augment) do
				methods[k] = v
			end

			for k, v in pairs(Methods) do
				methods[k] = v
			end

			AugmentedMethods[augment] = methods
		end
	else
		methods = Methods
	end

	-- Install methods from implementation modules.
	meta.Augment(Dialog, methods)

	return Dialog
end

--
--
--

return M