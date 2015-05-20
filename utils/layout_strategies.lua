--- Some strategies built on top of the layout utilities.

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
local ipairs = ipairs

-- Modules --
local layout = require("corona_ui.utils.layout")

-- Corona globals --
local display = display

-- Exports --
local M = {}

-- --
local Actions = {}

function Actions.above (object, ref, _, dy)
	layout.CenterAlignWith(object, ref)
	layout.PutAbove(object, ref, -dy)
end

function Actions.below (object, ref, _, dy)
	layout.CenterAlignWith(object, ref)
	layout.PutBelow(object, ref, dy)
end

function Actions.bottom_center (object, _, dx, dy)
	layout.PutAtBottomCenter(object, dx, dy)
end

function Actions.bottom_left (object, _, dx, dy)
	layout.PutAtBottomLeft(object, dx, dy)
end

function Actions.bottom_right (object, _, dx, dy)
	layout.PutAtBottomRight(object, dx, dy)
end

function Actions.center_left (object, _, dx, dy)
	layout.PutAtCenterLeft(object, dx, dy)
end

function Actions.center_right (object, _, dx, dy)
	layout.PutAtCenterRight(object, dx, dy)
end

function Actions.left_of (object, ref, dx, _)
	layout.CenterAlignWith(object, ref)
	layout.PutLeftOf(object, ref, -dx)
end

function Actions.right_of (object, ref, dx, dy)
	layout.CenterAlignWith(object, ref)
	layout.PutRightOf(object, ref, dx)
end

function Actions.top_center (object, _, dx, dy)
	layout.PutAtTopCenter(object, dx, dy)
end

function Actions.top_left (object, _, dx, dy)
	layout.PutAtTopLeft(object, dx, dy)
end

function Actions.top_right (object, _, dx, dy)
	layout.PutAtTopRight(object, dx, dy)
end

--- DOCME
-- TODO: This doesn't seem to be adequate, needs to be split on (x, y)
function M.PutAtFirstHit (object, ref_object, choices, center_on_fail)
	local x, dx = object.x, layout.ResolveX(choices.dx)
	local y, dy = object.y, layout.ResolveY(choices.dy)

	for _, choice in ipairs(choices) do
		local action = Actions[choice]

		if action then
			action(object, ref_object, dx, dy)

			if layout.LeftOf(object) >= 0 and layout.RightOf(object) < display.contentWidth and
				layout.Above(object) >= 0 and layout.Below(object) < display.contentHeight then
				return
			end
		end
	end

	if center_on_fail then
		layout.CenterAlignWith(object, ref_object)
	else
		object.x, object.y = x, y
	end
end

-- Export the module.
return M