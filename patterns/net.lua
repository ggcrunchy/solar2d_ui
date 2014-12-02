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

-- Exports --
local M = {}

-- common.AddNet() stuff
--[[
-- Full-screen dummy widgets used to implement modal behavior --
-- CONSIDER: Can the use cases be subsumed into an overlay?
local Nets

-- Nets intercept all input
local function NetTouch (event)
	event.target.m_caught = true

	return true
end

-- Removes nets whose object is invisible or has been removed
local function WatchNets ()
	for net, object in pairs(Nets) do
		if net.m_caught and net.m_hide_object then
			object.isVisible = false
		end

		if not object.isVisible then
			net:removeSelf()

			Nets[net] = nil
		end
	end
end

--- DOCMAYBE
-- @pgroup group
-- @pobject object
-- @bool hide
function M.AddNet (group, object, hide)
	if not Nets then
		Nets = {}

		Runtime:addEventListener("enterFrame", WatchNets)
	end

	local net = M.NewRect(group, 0, 0, display.contentWidth, display.contentHeight)

	net.m_hide_object = not not hide

	net:addEventListener("touch", NetTouch)
	net:setFillColor(1, .125)
	net:toFront()
	object:toFront()
	net:translate(display.contentCenterX, display.contentCenterY)

	Nets[net] = object
end
]]

-- stub hoisting stuff from editable

--[[
--
local function FindInGroup (group, item)
	for i = 1, group.numChildren do
		if group[i] == item then
			return i
		end
	end
end
]]

--[[
		--
		local pos, stub = FindInGroup(editable.parent, editable), display.newRect(0, 0, 1, 1)

		stub.x, stub.y = editable.x, editable.y

		editable.m_stub, stub.isVisible = stub, false

		editable.parent:insert(pos, stub)

		--
		local stage, bounds = display.getCurrentStage(), editable.contentBounds
		local net = display.newRect(stage, display.contentCenterX, display.contentCenterY, display.contentWidth, display.contentHeight)

		editable.m_net, net.m_blocking = net, editable.m_blocking

		--
		stage:insert(editable)

		layout.PutAtTopLeft(editable, bounds.xMin, bounds.yMin)

		--
		net:addEventListener("touch", TouchNet)
		net:toFront()
		editable:toFront()
]]

--[[
	--
	local stub = Editable.m_stub
	local pos = FindInGroup(stub.parent, stub)

	if pos then
		stub.parent:insert(pos, Editable)

		Editable.x, Editable.y = stub.x, stub.y
	end

	--
	stub:removeSelf()

	Editable, OldListenFunc, Editable.m_net, Editable.m_stub = nil
]]

-- Export the module.
return M