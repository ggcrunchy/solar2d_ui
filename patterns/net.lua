--- DOCME!

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
local layout = require("corona_ui.utils.layout")
local timers = require("corona_utils.timers")

-- Corona globals --
local display = display

-- Cached module references --
local _AddNet_

-- Exports --
local M = {}

-- skins

--
local function Rect (group, touch)
	local rect = display.newRect(group, 0, 0, display.contentWidth, display.contentHeight)

	rect:addEventListener("touch", touch)
	rect:translate(display.contentCenterX, display.contentCenterY)

	return rect
end

-- Full-screen dummy widgets used to implement modal behavior --
local Nets

-- Nets intercept all input
local function Catch (event)
	event.target.m_caught = true

	return true
end

-- Removes nets whose object is invisible or has been removed
local function WatchNets ()
	local empty = true

	--
	for net, object in pairs(Nets) do
		if net.m_caught and net.m_hide_object then
			object.isVisible = false
		end

		local intact = net.removeSelf ~= nil

		if not (intact and object.isVisible) then
			if intact then -- TODO: Try to use display.remove()...
				net:removeSelf()
			end

			Nets[net] = nil
		else
			empty = false
		end
	end

	--
	if empty then
		Nets = nil

		return "cancel"
	end
end

--
local function SetLayers (net, object)
	net:toFront()
	object:toFront()
end

--
local function SetColor (net, gray, opts)
	net:setFillColor(opts and opts.gray or gray, opts and opts.alpha or .125)
end

--- DOCMAYBE
-- @pgroup group
-- @pobject object
-- @ptable[opt] opts
-- @treturn DisplayObject net
function M.AddNet (group, object, opts)
	--
	if not Nets then
		Nets = {}

		timers.RepeatEx(WatchNets, 20)
	end

	--
	local net = Rect(group, Catch)

	SetColor(net, 1, opts)
	SetLayers(net, object)

	Nets[net] = object

	return net
end

--- DOCME
-- @pgroup group
-- @pobject object
-- @ptable[opt] opts
-- @treturn DisplayObject net
function M.AddNet_Hide (group, object, opts)
	local net = _AddNet_(group, object, opts)

	net.m_hide_object = true

	return net
end

--
local function DefTouch () return true end

--- DOCME
-- @pgroup group
-- @ptable[opt] opts
-- @treturn DisplayObject blocker
function M.Blocker (group, opts)
	local blocker = Rect(group, DefTouch)

	SetColor(blocker, 0, opts)

	return blocker
end

--
local function FindInGroup (group, item)
	for i = 1, group.numChildren do
		if group[i] == item then
			return i
		end
	end
end

--
local function TouchNet (event)
	local net = event.target

	if not net.m_blocking then
		local stage, phase = display.getCurrentStage(), event.phase

		if phase == "began" then
			stage:setFocus(net, event.id)

			net.m_wants_to_close = true
		elseif phase == "cancelled" or phase == "ended" then
			stage:setFocus(net, nil)

			if net.m_wants_to_close then
				net.m_on_close()
			end
		end
	end

	return true
end

-- ^^^ TODO: Can this and AddNet() be unified?

--- DOCME
-- @pobject object
-- @callable on_close
-- @bool blocking
-- @treturn DisplayObject stub
-- @treturn DisplayObject net
function M.HoistOntoStage (object, on_close, blocking)
	--
	local pos, stub = FindInGroup(object.parent, object), display.newRect(0, 0, 1, 1)

	stub.x, stub.y, stub.isVisible = object.x, object.y, false

	object.parent:insert(pos, stub)

	--
	local stage, bounds = display.getCurrentStage(), object.contentBounds
	local net = Rect(stage, TouchNet)

	net.m_blocking = not not blocking
	net.m_on_close = on_close

	--
	stage:insert(object)

	layout.PutAtTopLeft(object, bounds.xMin, bounds.yMin)

	SetLayers(net, object)

	return stub, net
end

--- DOCME
-- @pobject object
-- @pobject stub
-- @pobject[opt] net
function M.RestoreAfterHoist (object, stub, net)
	--
	local pos = FindInGroup(stub.parent, stub)

	if pos then
		stub.parent:insert(pos, object)

		object.x, object.y = stub.x, stub.y
	end

	stub:removeSelf()

	--
	display.remove(net)
end

-- Cache module members.
_AddNet_ = M.AddNet

-- Export the module.
return M