--- Proxy over a curve (a multi-point line) between two nodes or points.

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

-- Standard library imports --
local assert = assert
local setmetatable = setmetatable
local unpack = unpack

-- Modules --
local position = require("corona_ui.utils.position")

-- Corona globals --
local display = display

--
--
--

local CurveBetweenNodes = {}

CurveBetweenNodes.__index = CurveBetweenNodes

--- DOCME
function CurveBetweenNodes:Dirty ()
	self.m_dirty = true
end

function CurveBetweenNodes:EvictDisplayObject ()
	local curve = self.m_curve

	self.m_dirty, self.m_curve = true

	return curve
end

--- DOCME
function CurveBetweenNodes:GetKnotFunc ()
	return self.m_func
end

--- DOCME
function CurveBetweenNodes:GetKnots ()
	return self.m_knots
end

--- DOCME
function CurveBetweenNodes:GetShift ()
	return self.m_shift
end

--- DOCME
function CurveBetweenNodes:HasDisplayObject ()
	return self.m_curve ~= nil
end

--- DOCME
function CurveBetweenNodes:IsDirty ()
	return self.m_dirty
end

--- DOCME
function CurveBetweenNodes:ReplaceDisplayObject (new)
	local curve, index = self.m_curve

	if curve then
		index = new and curve.parent == new.parent and position.IndexInGroup(curve) -- if parents same, try to put in same slot

		curve:removeSelf()
	end

	if new then
		local r, stroke_width = self[1], self.m_stroke_width

		if r then
			new:setStrokeColor(r, unpack(self, 2))
		end

		if stroke_width then
			new.strokeWidth = stroke_width
		end

		if index then
			new.parent:insert(index, new)
		end
	end

	self.m_dirty, self.m_curve = true, new
end

function CurveBetweenNodes:RemoveDisplayObject ()
	display.remove(self.m_curve)

	self.m_dirty, self.m_curve = true
end

--- DOCME
function CurveBetweenNodes:SetKnotFunc (func)
	self.m_func, self.m_dirty = func, true
end

--- DOCME
function CurveBetweenNodes:SetKnots (knots)
	self.m_knots, self.m_dirty = knots, true
end

--- DOCME
function CurveBetweenNodes:SetShift (shift)
	self.m_shift, self.m_dirty = shift, true
end

--- DOCME
function CurveBetweenNodes:SetStrokeColor (...)
	local r, g, b, a = ...

	assert(g == nil or r, "Missing red component")
	assert(b == nil or g, "Missing green component")
	assert(a == nil or b, "Missing blue component")

	self[1], self[2], self[3], self[4], self.m_dirty = r, g, b, a, true
end

--- DOCME
function CurveBetweenNodes:SetStrokeWidth (stroke_width)
	self.m_stroke_width, self.m_dirty = stroke_width, true
end

--- DOCME
function CurveBetweenNodes:Undirty ()
	self.m_dirty = false
end

--- DOCME
function M.New ()
    return setmetatable({ m_dirty = false }, CurveBetweenNodes)
end

return M