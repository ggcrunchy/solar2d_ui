--- UI touch utilites.

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
local max = math.max
local min = math.min

-- Modules --
local range = require("tektite_core.number.range")

-- Imports --
local ClampIn = range.ClampIn

-- Corona globals --
local display = display

-- Cached module references --
local _TouchHelperFunc_

-- Exports --
local M = {}

--
local function GetParent (object, find)
	if find then
		return find(object)
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
	view_max = function(pos, p0)
		return min(pos, p0)
	end
}

--- Builds a function (on top of @{TouchHelperFunc}) to be assigned as a **"touch"**
-- listener, which will drag the target's parent around when moved, subject to clamping at
-- the screen edges.
--
-- The **m\_dragx** and **m\_dragy** fields are intrusively assigned to in the event target.
-- @ptable[opt] opts
-- FIX number[opt=1] hscale Height scale, &ge; 1. The parent may be taller than the touched
-- object, e.g. in the case of a title bar, which affects vertical clamping. The final
-- metric is: parent height = _hscale_ * object height.
-- @treturn function Listener function.
--
-- **CONSIDER**: More automagic than hscale? Varieties of clamping?
--
-- @todo May start in "broken" state, i.e. in violation of the clamping
-- DOCMEMORE!
function M.DragParentTouch (opts)
	local clamp, find, hscale, xoff, yoff

	if opts then
		clamp = opts.no_clamp and ClampMethods.id or ClampMethods[opts.clamp]
		find, hscale = opts.find, opts.hscale
		xoff, yoff = opts.x_offset, opts.y_offset
	end

	clamp, hscale, xoff, yoff = clamp or ClampMethods.clamp_in, hscale or 1, xoff or 0, yoff or 0

	return _TouchHelperFunc_(function(event, object)
		local parent = GetParent(object, find)

		object.m_dragx = parent.x - event.x
		object.m_dragy = parent.y - event.y
	end, function(event, object)
		local parent = GetParent(object, find)
		local newx, newy = object.m_dragx + event.x, object.m_dragy + event.y

		parent.x = clamp(newx, xoff, display.contentWidth - object.contentWidth)
		parent.y = clamp(newy, yoff, display.contentHeight - object.contentHeight * hscale)
	end)
end

--- DOCME
function M.DragParentTouch_Child (key, opts)
	local clamp, find, on_began, on_ended, on_post_move, on_pre_move, ref

	if opts then
		clamp, find, ref = opts.clamp, opts.find, opts.ref
		on_began, on_ended, on_post_move, on_pre_move = opts.on_began, opts.on_ended, opts.on_post_move, opts.on_pre_move
	end

	clamp = ClampMethods[clamp] or ClampIn

	return _TouchHelperFunc_(function(event, object)
		local parent = GetParent(object, find)

		if ref == "object" then
			local sibling = parent[key]

			object.m_x0 = sibling.contentWidth / 2 - sibling.x
			object.m_y0 = sibling.contentHeight / 2 - sibling.y
		else
			object.m_x0, object.m_y0 = 0, 0
		end

		object.m_dragx = parent.x - event.x
		object.m_dragy = parent.y - event.y

		if on_began then
			on_began(parent, parent[key])
		end
	end, function(event, object)
		local parent = GetParent(object, find)
		local sibling, x0, y0 = parent[key], object.m_x0, object.m_y0

		if on_pre_move then
			on_pre_move(parent, sibling)
		end

		parent.x = clamp(object.m_dragx + event.x, x0, x0 + display.contentWidth - sibling.contentWidth)
		parent.y = clamp(object.m_dragy + event.y, y0, y0 + display.contentHeight - sibling.contentHeight)

		if on_post_move then
			on_post_move(parent, sibling)
		end
	end, on_ended and function(event, object)
		local parent = GetParent(object, find)

		on_ended(parent, parent[key])
	end)
end

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
function M.DragTouch ()
	return _TouchHelperFunc_(function(event, object)
		object.m_dragx = object.x - event.x
		object.m_dragy = object.y - event.y
	end, function(event, object)
		local w = object.contentWidth / 2
		local h = object.contentHeight / 2

		object.x = ClampIn(object.m_dragx + event.x, w, display.contentWidth - w)
		object.y = ClampIn(object.m_dragy + event.y, h, display.contentHeight - h)
	end)
end

--
local function ResolveCoordinate (v, cur)
	return v == "cur" and cur
end

--- DOCME
function M.DragViewTouch (view, opts)
	local on_post_move, on_pre_move, xclamp, yclamp, x0, y0

	if opts then
		x0, y0 = ResolveCoordinate(opts.x0, view.x), ResolveCoordinate(opts.y0, view.y)
		xclamp = ClampMethods[opts.xclamp]
		yclamp = ClampMethods[opts.yclamp]
		on_post_move, on_pre_move = opts.on_post_move, opts.on_pre_move
	end

	x0, y0 = x0 or 0, y0 or 0
	xclamp = xclamp or ClampMethods.id
	yclamp = yclamp or ClampMethods.id

	return _TouchHelperFunc_(function(event, object)
		object.m_dragx = event.x
		object.m_dragy = event.y
	end, function(event, object)
		local ex, ey = event.x, event.y

		if on_pre_move then
			on_pre_move(view)
		end

		view.x, object.m_dragx = xclamp(view.x - (ex - object.m_dragx), x0), ex
		view.y, object.m_dragy = yclamp(view.y - (ey - object.m_dragy), y0), ey

		if on_post_move then
			on_post_move(view)
		end
	end)
end

-- Is the target touched, or at least considered so?
local function IsTouched (target, event)
	return target.m_is_touched or event.id == "ignore_me"
end

-- Helper to set (multitouch) stage focus
local function SetFocusForTouch (target, touch)
	display.getCurrentStage():setFocus(target, touch)

	target.m_is_touched = not not touch
end

--- Builds a function to be assigned as a **"touch"** listener, which handles various common
-- details of touch management.
--
-- Each of the arguments are assumed to be functions called as `func(event, target)`, where
-- _event_ is the normal touch listener parameter, and _target_ is provided as a convenience
-- for _event_.**target**.
-- @callable began Called when the target has begun to be touched.
-- @callable[opt] moved If provided, called if the target's touch moved.
-- @callable[opt] ended If provided, called if the target's touch has ended or been cancelled.
-- @treturn function Listener function, which always returns **true**.
--
-- You may simulate a touch by feeding an **id** of **"ignore_me"** through _event_, all
-- other fields being normal. Otherwise, the focus of the id's touch is updated.
-- DOCMEMORE
function M.TouchHelperFunc (began, moved, ended)
	if moved == "began" then
		moved = began
	end

	if ended == "began" then
		ended = began
	elseif ended == "moved" then
		ended = moved
	end

	return function(event)
		local target = event.target

		if event.phase == "began" then
			if event.id ~= "ignore_me" then
				SetFocusForTouch(target, event.id)
			end

			began(event, target)
		
		elseif IsTouched(target, event) then
			if event.phase == "moved" and moved then
				moved(event, target)

			elseif event.phase == "ended" or event.phase == "cancelled" then
				if event.id ~= "ignore_me" then
					SetFocusForTouch(target, nil)
				end

				if ended then
					ended(event, target)
				end
			end
		end

		return true
	end
end

-- Cache module members.
_TouchHelperFunc_ = M.TouchHelperFunc

-- Export the module.
return M