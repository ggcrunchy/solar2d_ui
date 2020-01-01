--- Various drag-style touch utilities.

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
local huge = math.huge
local max = math.max
local min = math.min

-- Modules --
local range = require("tektite_core.number.range")
local touch = require("corona_ui.utils.touch")

-- Imports --
local ClampIn = range.ClampIn

-- Corona globals --
local display = display

-- Exports --
local M = {}

--
--
--

--- Builds a function (on top of @{TouchHelperFunc}) to be assigned as a **"touch"**
-- listener, which will drag the target around when moved, subject to clamping at the screen
-- edges.
--
-- The **m\_dragx** and **m\_dragy** fields are intrusively assigned to in the event target.
-- @treturn function Listener function.
--
-- **CONSIDER**: Varieties of clamping?
--
-- @todo As per @{DragParentTouch}
function M.MakeTouch ()
	return touch.Wrap(function(event, object)
		object.m_dragx = object.x - event.x
		object.m_dragy = object.y - event.y
	end, function(event, object)
		local w = object.contentWidth / 2
		local h = object.contentHeight / 2

		object.x = ClampIn(object.m_dragx + event.x, w, display.contentWidth - w)
		object.y = ClampIn(object.m_dragy + event.y, h, display.contentHeight - h)
	end)
end

local function GetParent (object, find, how)
	if find then
		return find(object, how)
	else
		return object.parent
	end
end

--
local ClampMethods = {
	--
	clamp_in = ClampIn,

	--
	id = function(x)
		return x
	end,

	--
	max = function(pos, p0)
		return max(pos, p0)
	end,

	--
	view_max = function(pos, p1, p2)
		return max(min(pos, p1), p2)
	end
}

local function RefObject (object, find)
	if find then
		return find(object)
	else
		return object
	end
end

--- Builds a function (on top of @{TouchHelperFunc}) to be assigned as a **"touch"**
-- listener, which will drag the target's parent around when moved, subject to clamping at
-- the screen edges.
--
-- The **m\_dragx** and **m\_dragy** fields are intrusively assigned to in the event target.
-- @ptable[opt] opts
-- @treturn function Listener function.
--
-- **CONSIDER**: Varieties of clamping?
--
-- @todo May start in "broken" state, i.e. in violation of the clamping
-- DOCMEMORE!
function M.MakeTouch_Parent (opts)
	local clamp, find, find_ref, get_dims, hoist, offset_by_object, to_front, xoff, yoff 
	local on_began, on_ended, on_init, on_post_move, on_pre_move

	if opts then
		clamp, to_front = opts.no_clamp and ClampMethods.id or ClampMethods[opts.clamp], not not opts.to_front
		find, find_ref, offset_by_object, hoist = opts.find, opts.find_ref, not not opts.offset_by_object, not not opts.hoist
		get_dims, xoff, yoff = opts.get_dims, opts.x_offset, opts.y_offset
		on_began, on_ended, on_init = opts.on_began, opts.on_ended, opts.on_init
		on_post_move, on_pre_move = opts.on_post_move, opts.on_pre_move
	end

	assert(not hoist or find, "Hoist must be paired with a find operation")

	clamp, xoff, yoff = clamp or ClampMethods.clamp_in, xoff or 0, yoff or 0

	return touch.Wrap(function(event, object)
		if on_init then
			on_init(object)
		end

		local parent, ref_object = GetParent(object, find), RefObject(object, find_ref)

		if hoist then
			local into, x, y = GetParent(object, find, "into"), parent:localToContent(0, 0)

			parent.m_parent, parent.m_unhoisted_x, parent.m_unhoisted_x = parent.parent, parent.x, parent.y

			into:insert(parent)

			parent.x, parent.y = into:contentToLocal(x, y)
		end

		object.m_dragx = parent.x - event.x
		object.m_dragy = parent.y - event.y

		if offset_by_object then
			object.m_x0 = ref_object.contentWidth / 2 - ref_object.x
			object.m_y0 = ref_object.contentHeight / 2 - ref_object.y
		else
			object.m_x0, object.m_y0 = xoff, yoff
		end

		if on_began then
			on_began(parent, ref_object)
		end

		if to_front then
			parent:toFront()
		end
	end, function(event, object)
		local parent, ref_object = GetParent(object, find), RefObject(object, find_ref)
		local newx, newy, x0, y0 = object.m_dragx + event.x, object.m_dragy + event.y, object.m_x0, object.m_y0

		if on_pre_move then
			on_pre_move(parent, ref_object)
		end

		local w, h

		if get_dims then
			w, h = get_dims()
		end

		parent.x = clamp(newx, x0, x0 + (w or display.contentWidth) - ref_object.contentWidth)
		parent.y = clamp(newy, y0, y0 + (h or display.contentHeight) - ref_object.contentHeight)

		if on_post_move then
			on_post_move(parent, ref_object)
		end
	end, on_ended and function(_, object)
		local parent = GetParent(object, find)

		on_ended(parent, RefObject(object, find_ref))

		if hoist then
			parent.m_parent:insert(parent)

			parent.x, parent.y = parent.m_unhoisted_x, parent.m_unhoisted_x
			parent.m_parent, parent.m_unhoisted_x, parent.m_unhoisted_x = nil
		end
	end)
end

--
local function ResolveCoordinate (v, cur)
	return v == "cur" and cur
end

--- DOCME
function M.MakeTouch_View (view, opts)
	local dx, dy, on_post_move, on_pre_move, xclamp, yclamp, x0, y0, x1, y1

	if opts then
		x0, y0 = ResolveCoordinate(opts.x0, view.x), ResolveCoordinate(opts.y0, view.y)
		dx, dy = opts.dx, opts.dy
		xclamp = ClampMethods[opts.xclamp]
		yclamp = ClampMethods[opts.yclamp]
		on_post_move, on_pre_move = opts.on_post_move, opts.on_pre_move
	end

	x0, y0 = x0 or 0, y0 or 0
	x1 = dx and (x0 - dx) or -huge
	y1 = dy and (y0 - dy) or -huge
	xclamp = xclamp or ClampMethods.id
	yclamp = yclamp or ClampMethods.id

	return touch.Wrap(function(event, object)
		object.m_dragx = event.x
		object.m_dragy = event.y
	end, function(event, object)
		local ex, ey = event.x, event.y

		if on_pre_move then
			on_pre_move(view)
		end

		view.x, object.m_dragx = xclamp(view.x - (ex - object.m_dragx), x0, x1), ex
		view.y, object.m_dragy = yclamp(view.y - (ey - object.m_dragy), y0, y1), ey

		if on_post_move then
			on_post_move(view)
		end
	end)
end

return M