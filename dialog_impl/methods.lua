--- Various dialog methods.

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
-- Modules --
local editable_patterns = require("corona_ui.patterns.editable")
local layout = require("corona_ui.utils.layout")
local utils = require("corona_ui.dialog_impl.utils")

-- Corona globals --
local display = display
local native = native

-- Exports --
local M = {}

--
local function OnTextChange (event)
	local str = event.target

	utils.UpdateObject(str, event.new_text, str:GetChildOfParent())
end

--
local function AddStaticText (dialog, text)
	local str = display.newText(dialog:ItemGroup(), text, 0, 0, native.systemFontBold, layout.ResolveY("4.6%"))

	dialog:Update(str)

	return str
end

--- DOCMEMORE
-- Common logic to add another widget to the dialog
function M:CommonAdd (object, options, static_text)
	-- Add any text before the object in the line.
	if options and options.before then
		AddStaticText(self, options.before)
	end

	-- Reflow around the object, if it exists.
	if object then
		self:Update(object)
	end

	local continue_line, text

	if options then
		-- If text was updated, check if it's static. If so, just bake it in; otherwise,
		-- make the text into editable strings. This will add one or two more objects to
		-- the dialog, so reflow after each of these as well.
		if options.text then
			if static_text then
				text = AddStaticText(self, options.text)
			else
				text = editable_patterns.Editable(self:ItemGroup(), options)

				text:addEventListener("text_change", OnTextChange)
				self:Update(text)
			end
		end

		-- If no object was supplied, the text will be the object instead. Associate a
		-- friendly name and value name to the object and note any further options.
		local name = options.name or options.value_name
		local oprops = utils.GetProperty_Table(object or text, utils.GetNamespace(self))

		oprops.name = name
		oprops.value_name = options.value_name

		continue_line = options.continue_line
	end

	-- Most commonly, we want to advance to the next line.
	if not continue_line then
		self:NewLine()
	end
end

--
local function AuxFind (group, namespace, name)
	for i = 1, group.numChildren do
		if utils.GetProperty(group[i], "name", namespace) == name then
			return group[i]
		end
	end
end

--- Searches by name for an object in the dialog.
-- @param name Object name, as passed through **name** in the object's _options_. If
-- the name was **true**, the final name will be the value of **value\_name**.
-- @treturn DisplayObject Object, or **nil** if not found.
function M:Find (name)
	local igroup, ugroup, namespace = self:ItemGroup(), self:UpperGroup("peek"), utils.GetNamespace(self)
	local item = AuxFind(igroup, namespace, name)

	if not item and ugroup then
		item = AuxFind(ugroup, namespace, name)
	end

	return item
end

--- DOCME
function M:ItemGroup ()
	return self.m_items
end

-- --
local BeforeRemoveEvent = { name = "before_remove" }

--
local function RemoveWidgets (group, namespace)
	for i = group.numChildren, 1, -1 do
		if utils.GetProperty(group[i], "type", namespace) == "widget" then
			group[i]:removeSelf()
		end
	end
end

--- Removes the dialog. This does some additional cleanup beyond what is done by
-- `display.remove` and `object:removeSelf`.
function M:RemoveSelf ()
	self.m_defs = nil
	self.m_values = nil

	BeforeRemoveEvent.target = self

	self:dispatchEvent(BeforeRemoveEvent)

	BeforeRemoveEvent.target = nil

	local igroup, ugroup, namespace = self:ItemGroup(), self:UpperGroup("peek"), utils.GetNamespace(self)

	RemoveWidgets(igroup, namespace)

	if ugroup then
		RemoveWidgets(ugroup, namespace)
	end

	if igroup.parent ~= self then
		igroup.parent:removeSelf()
	end

	self:removeSelf()
end

--- DOCME
function M:UpperGroup (how)
	local upper, items = self.m_upper

	if not self.m_upper and how ~= "peek" then
		items, upper = self:ItemGroup(), display.newGroup()
		self.m_upper = upper

		items.parent:insert(upper) -- account for moves into scroll view
	end

	return upper
end

-- Export the module.
return M