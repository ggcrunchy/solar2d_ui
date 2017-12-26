--- Menu UI elements.
--
-- @todo Document skin...

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
local ipairs = ipairs
local type = type

-- Modules --
local array_index = require("tektite_core.array.index")
local layout = require("corona_ui.utils.layout")
local layout_dsl = require("corona_ui.utils.layout_dsl")

-- Corona globals --
local display = display
local native = native
local system = system
local transition = transition

-- Exports --
local M = {}

--
--
--

local function CheckColumns (columns)
	assert(columns, "Missing columns")

	local n, prev_type = 0

	for _, column in ipairs(columns) do
		local ctype = type(column)

		assert(ctype == "table" or ctype == "string", "Bad column type")

		if ctype == "table" then
			assert(prev_type == "string", "Column tables must follow string heading")

			for _, v in ipairs(column) do
				assert(type(v) == "string", "Non-string column entry")
			end
		else
			n = n + 1
		end

		prev_type = ctype
	end

	return columns, n
end

local FadeParams = {
	time = 150,

	onComplete = function(object)
		object.m_can_touch = true
	end
}

local function Fade (object, alpha)
	object.m_can_touch, FadeParams.alpha = false, alpha

	return transition.to(object, FadeParams)
end

local function MenuFromHeading (heading)
	return heading.parent.parent
end

local function InHeading (heading, x, y)
	local menu = MenuFromHeading(heading)

	for i = 1, menu.numChildren do
		local item = menu[i][1] -- N.B. headings always first
		local ibounds = item.contentBounds

		if x >= ibounds.xMin and x <= ibounds.xMax and y >= ibounds.yMin and y <= ibounds.yMax then
			if item == heading then
				return "this"
			else
				return item
			end
		end
	end
end

local MenuEvent = {}

local function SendEvent (menu, text)
	MenuEvent.name, MenuEvent.target, MenuEvent.text = "menu_item", menu, text

	menu:dispatchEvent(MenuEvent)

	MenuEvent.target = nil
end

local function ReleaseHeading (heading)
	heading:setFillColor(.6)
end

local function Close (dropdown, new)
	transition.cancel(dropdown.m_fading)

	dropdown.m_can_touch, dropdown.m_fading = false

	Fade(dropdown.parent, 0)
	ReleaseHeading(dropdown.m_heading)

	display.getCurrentStage():setFocus(new)
end

local function TouchHeading (heading)
	heading:setFillColor(.2)

	local dropdown = heading.m_dropdown

	if dropdown then
		dropdown.m_fading = Fade(dropdown.parent, 1)

		display:getCurrentStage():setFocus(dropdown)
	else
		display:getCurrentStage():setFocus(heading)
	end
end

local function DropdownTouch (event)
	local dropdown, phase = event.target, event.phase
	local end_phase = phase == "ended" or phase == "cancelled" 

	if not (dropdown.parent.m_can_touch or end_phase) then
		return
	end

	local bar = dropdown.m_bar

	if phase == "moved" then
		local bounds, x, y = dropdown.contentBounds, event.x, event.y
		local xinside = x >= bounds.xMin and x <= bounds.xMax
		local yinside = y >= bounds.yMin and y <= bounds.yMax
		local heading, _, topy = dropdown.m_heading, dropdown:contentToLocal(0, y)
		local index = array_index.FitToSlot(topy, -dropdown.height / 2, bar.height)

		if yinside then
			layout.PutBelow(bar, heading, (index - 1) * bar.height)
		end

		local how = yinside and "show"

		if xinside and yinside then
			bar.m_index = index
		else
			how, bar.m_index = how or InHeading(heading, x, y)
		end

		bar.isVisible = how == "show"

		if how and how ~= "show" and how ~= "this" then
			Close(dropdown, how)
			TouchHeading(how)
		end
	elseif end_phase then
		if bar.m_index then
			SendEvent(MenuFromHeading(dropdown.m_heading), bar.parent[bar.m_index + bar.m_offset].m_text)

			bar.m_index = nil
		end

		bar.isVisible = false

		Close(dropdown)
	end

	return true
end

local function HeadingTouch (event)
	local heading, phase = event.target, event.phase

	if phase == "began" then
		TouchHeading(heading)
	elseif phase == "moved" then
		local how = InHeading(heading, event.x, event.y)

		if how and how ~= "this" then
			ReleaseHeading(heading)
			TouchHeading(how)
		end
	elseif phase == "ended" or phase == "cancelled" then
		ReleaseHeading(heading)

		display.getCurrentStage():setFocus(nil)

		if InHeading(heading, event.x, event.y) == "this" then
			SendEvent(MenuFromHeading(heading), heading.m_text)
		end
	end

	return true
end

local function DefGetText (text) return text end

--- DOCME
function M.Menu (params)
	local menu = display.newGroup()

	if params.group then
		params.group:insert(menu)
	end

	local columns, n = CheckColumns(params.columns)
	local column_width, heading_height = layout_dsl.EvalDims(params.column_width or 100, params.heading_height or 50)
	local _, bar_height = layout_dsl.EvalDims(nil, params.bar_height or heading_height)
	local font, size = params.font or native.systemFont, params.size or 16
	local left = params.left or (layout.ResolveX(params.x) or 0) - .5 * n * column_width
	local top = params.top or (layout.ResolveY(params.y) or 0) - .5 * heading_height
	local x, y, cgroup, heading = left + .5 * column_width, top + .5 * heading_height
	local get_text = params.get_text or DefGetText

	for _, column in ipairs(columns) do
		if type(column) == "string" then
			cgroup = display.newGroup()
			heading = display.newRect(cgroup, x, y, column_width, heading_height)

			ReleaseHeading(heading) -- set fill color

			display.newText(cgroup, get_text(column), heading.x, heading.y, font, size)

			heading:addEventListener("touch", HeadingTouch)
			menu:insert(cgroup)

			heading.m_text, x = column, x + column_width
		elseif #column > 0 then
			local bgroup = display.newGroup()

			cgroup:insert(bgroup)

			local back = display.newRect(bgroup, heading.x, 0, column_width, #column * bar_height)
			local bar = display.newRect(bgroup, heading.x, 0, column_width, bar_height)
			local prev = heading

			layout.PutBelow(back, heading)

			bar.m_offset = bgroup.numChildren

			for _, entry in ipairs(column) do
				layout.PutBelow(bar, prev)

				local text = display.newText(bgroup, get_text(entry), bar.x, bar.y, font, size)

				prev, text.m_text = layout.Below(bar), entry
			end

			back:addEventListener("touch", DropdownTouch)
			back:setFillColor(0, 0, .3)
			bar:setFillColor(0, .7, 0)

			bgroup.alpha, bar.isVisible = 0, false
			heading.m_dropdown, back.m_bar, back.m_heading, heading.m_text = back, bar, heading
		end
	end

	function menu:addEventListener (name, listener)
		self.m_dispatcher = self.m_dispatcher or system.newEventDispatcher()

		self.m_dispatcher:addEventListener(name, listener)
	end

	function menu:dispatchEvent (event)
		if self.m_dispatcher then
			self.m_dispatcher:dispatchEvent(event)
		end
	end

	function menu:removeEventListener (name, listener)
		if self.m_dispatcher then
			self.m_dispatcher:removeEventListener(name, listener)
		end
	end

	function menu:Select (name)
		SendEvent(self, name)
	end

	return menu
end

-- Export the module.
return M