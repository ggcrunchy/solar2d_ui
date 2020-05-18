--- Functionality for dialog layout.

-- TODO: Skin

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
local assert = assert
local max = math.max
local min = math.min
local type = type

-- Modules --
local layout = require("solar2d_ui.utils.layout")
local layout_dsl = require("solar2d_ui.utils.layout_dsl")
local utils = require("solar2d_ui.dialog_impl.utils")

-- Corona globals --
local display = display

-- Corona modules --
local widget = require("widget")

-- Exports --
local M = {}

--
--
--

-- Helper to get index of current line, beginning a new one if necessary
local function CurrentLine (dialog)
	local lines = dialog.m_lines
	local n, num_on_line = #lines, dialog.m_num_on_line

	if num_on_line == 0 then
		lines[n + 1], n = { first_item = dialog:ItemGroup().numChildren, y = dialog.m_peny }, n + 1
	end

	return n, num_on_line
end

-- Separation distances between objects and dialog edges --
local XSep, YSep = layout_dsl.EvalDims(".625%", "1.04%")

-- Common logic to advance the pen's y-coordinate
local function SetPenY (dialog, addy)
	local y = dialog.m_ymax + addy

	dialog.m_peny, dialog.m_ymax = y, y
end

-- Performs a "carriage return" on the pen used to add new objects
local function CR (dialog, not_empty)
	if not not_empty or dialog.m_num_on_line > 0 then
		dialog:EndLine()

		dialog.m_penx, dialog.m_num_on_line = XSep, 0

		SetPenY(dialog, YSep)
	end
end

-- Current width of a separator
local function SepWidth (dialog)
	return dialog.m_xmax - XSep * 2
end

-- Separator properties --
local SepProps = { type = "separator" }

--- DOCME
function M:AddSeparator ()
	self:InitProperties()

	CR(self, true)

	local sep = display.newRect(self:ItemGroup(), 0, 0, SepWidth(self), layout.ResolveY("1.67%"))

	sep:setFillColor(.0625)

	utils.SetProperty_Table(sep, SepProps, utils.GetNamespace(self))

	self:Update(sep)

	CR(self)
end

--- End a line of items
function M:EndLine ()
	if self.m_num_on_line > 0 then
		local index = #self.m_lines
		local line = self.m_lines[index]

		line.h = self.m_ymax - line.y + YSep
		line.is_open = true
		line.last_item = line.first_item + self.m_num_on_line - 1
	end
end

--- DOCME
function M:InitProperties ()
	if not self.m_num_on_line then
		self.m_penx, self.m_xmax = XSep, -1
		self.m_peny, self.m_ymax = YSep, -1
		self.m_lines = {}
		self.m_num_on_line = 0
	end
end

--- Moves the pen down one row, at the left side.
--
-- This is a no-op if the current line is empty.
function M:NewLine ()
	self:InitProperties()

	CR(self, true)
end

-- Spacer properties --
local SpacerProps = { type = "spacer" }

--- Adds some vertical space to the dialog.
function M:Spacer ()
	self:InitProperties()

	CR(self, true)

	local spacer = display.newRect(self:ItemGroup(), 0, 0, 5, YSep * 2)

	spacer.isVisible = false

	spacer.m_collapsed = false

	utils.SetProperty_Table(spacer, SpacerProps, utils.GetNamespace(self))

	self:Update(spacer)

	CR(self)
end

-- Helper to center one or more text items on a line
local function CenterText (dialog, y, count)
	local igroup = dialog:ItemGroup()
	local n = igroup.numChildren + 1

	for i = 1, count do
		local item = igroup[n - i]

		if type(item.text) == "string" then
			item.y = y - .5 * item.height
		end
	end
end

-- Must the dialog grow in a given dimension?
local function MustGrow (dialog, what, comp)
	if comp > dialog[what] then
		dialog[what] = comp

		return true
	end
end

-- How much the dialog can stretch before we make it scrollable --
local WMax, HMax = layout_dsl.EvalDims("62.5%", "72.92%")--500, 350

-- Fixes up various dialog state when its size changes
local function ResizeBack (dialog)
	local w, h = dialog.m_xmax, dialog.m_ymax
	local fullw, fullh = w > WMax, h > HMax

	-- Confine the dimensions to the masked area.
	w, h = min(w, WMax), min(h, HMax)

	utils.AddBack(dialog, w, h)

	-- If the dialog overflowed one of its bounds, mask out the items that won't be shown.
	local wmax, hmax = dialog.m_wmax or 0, dialog.m_hmax or 0

	if (fullw and wmax <= WMax) or (fullh and hmax <= HMax) then
		dialog.m_wmax = max(w, wmax)
		dialog.m_hmax = max(h, hmax)

		local scroll_view = widget.newScrollView{
			width = w, height = h, hideBackground = true,
			horizontalScrollDisabled = not fullw,
			verticalScrollDisabled = not fullh
		}
		local igroup, ugroup = dialog:ItemGroup(), dialog:UpperGroup("peek")
		local parent = igroup.parent

		scroll_view:insert(igroup)

		if ugroup then
			scroll_view:insert(ugroup)
		end

		dialog:insert(scroll_view)

		-- Remove any previous scroll view.
		if parent ~= dialog then
			parent:removeSelf()
		end
	end
end

-- Helper to resize a separator-type item
local function Resize (item, w)
	item.width = w + XSep - item.x
end

-- Fixes up separators to fit the dialog dimensions
local function ResizeSeparators (dialog)
	local igroup, namespace, w = dialog:ItemGroup(), utils.GetNamespace(dialog), SepWidth(dialog)

	for i = 1, igroup.numChildren do
		local item = igroup[i]

		if utils.GetProperty(item, "type", namespace) == "separator" then
			Resize(item, w)
		end
	end
end

--- Updates the dialog's state (e.g. various dimensions and alignments) to take account
-- of a new object. The object is put into its expected position via the pen.
-- @pobject object Object that was added.
-- @number? addx If present, extra amount to advance the pen after placement.
function M:Update (object, addx)
	assert(not self.m_sealed, "Adding to sealed dialog") -- TODO: this is to make the section logic tractable... can that be done "right"?

	self:InitProperties()

	object.anchorX, object.x = 0, self.m_penx
	object.anchorY, object.y = 0, self.m_peny

	-- If the item should be treated like a separator, adjust its width.
	if utils.GetProperty(object, "type", utils.GetNamespace(self)) == "separator" then
		Resize(object, SepWidth(self))
	end

	-- Advance the pen a little past the object.
	addx = object.contentWidth + XSep + (addx or 0)

	self.m_penx = object.x + addx

	-- Does adding this item widen the dialog? If so, fix up any separators.
	local xgrow = MustGrow(self, "m_xmax", self.m_penx)

	if xgrow then
		ResizeSeparators(self)
	end

	-- Account for this item being added to the line.
	local line, num_on_line = CurrentLine(self)

	object.m_addx, object.m_line = addx, line

	self.m_num_on_line = num_on_line + 1

	-- Does adding this item make the dialog taller? If so, center any text on this line.
	-- The new item may itself be text: streamline this into the centering logic.
	local ygrow = MustGrow(self, "m_ymax", object.y + object.contentHeight)

	if ygrow or type(object.text) == "string" then
		CenterText(self, .5 * (self.m_peny + self.m_ymax), (ygrow and num_on_line or 0) + 1)
	end

	-- If the dialog grew taller or wider (up to scissoring), resize the back.
	if xgrow or ygrow then
		ResizeBack(self)
	end
end

return M