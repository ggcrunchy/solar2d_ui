--- Utilities for layout handling.
--
-- These are designed to allow layout decisions and queries, without worrying about the
-- anchor points of the objects in question. In many cases, positions may be substituted
-- for objects, as well.
--
-- With respect to this module, a **Number** may be any of the following:
--
-- * A number, or a string that @{tonumber} is able to convert. These values are used as is.
-- * A string of the form _amount_**"%"**, where _amount_ resolves to the indicated percent
-- of the content width or height.
-- * **nil**, which resolves to 0.
--
-- TODO: Where two objects are concerned, layout should be able to handle mixed parents
-- TODO: Positions should respect parent's positions, and not assume screen coordiantes

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
local floor = math.floor
local ipairs = ipairs
local sub = string.sub
local tonumber = tonumber
local type = type

-- Corona globals --
local display = display

-- Cached module references --
local _Above_
local _Below_
local _CenterAlignWith_
local _CenterAt_
local _CenterOf_
local _LeftOf_
local _PutAbove_
local _PutBelow_
local _PutLeftOf_
local _PutRightOf_
local _RightOf_

-- Exports --
local M = {}

-- Resolves a Number (most often being a delta) to a value
local function Delta (n, dim)
	if type(n) ~= "string" then
		return n or 0
	elseif sub(n, -1) == "%" then
		return tonumber(sub(n, 1, -2)) * display[dim] / 100
	else
		return tonumber(n)
	end
end

-- Helper for horizontal deltas...
local function DX (n)
	return Delta(n, "contentWidth")
end

-- ...and vertical ones
local function DY (n)
	return Delta(n, "contentHeight")
end

-- Is the object not a group?
local function NonGroup (object)
	return object._type ~= "GroupObject"
end

-- Is the object a number, or can it be coerced / defaulted to one?
local function Number (object)
	local otype = type(object)

	return object == nil or otype == "string" or otype == "number"
end

-- Helper to get an x-coordinate relative to a position, in terms of width...
local function RelativeX (object, t)
	return object.x + t * object.contentWidth
end

-- ...and y-coordinate, in terms of height
local function RelativeY (object, t)
	return object.y + t * object.contentHeight
end

-- Finds the y-coordinate at the bottom of an object; Numbers resolve like deltas, directly to themselves
local function BottomY (object)
	if Number(object) then
		return DY(object)
	elseif NonGroup(object) then
		return RelativeY(object, 1 - object.anchorY)
	else
		return object.contentBounds.yMax
	end
end

-- Finds the x-coordinate at the left side of an object; Numbers behave as per BottomY
local function LeftX (object)
	if Number(object) then
		return DX(object)
	elseif NonGroup(object) then
		return RelativeX(object, -object.anchorX)
	else
		return object.contentBounds.xMin
	end
end

-- Finds the x-coordinate at the right side of an object; Numbers behave as per BottomY
local function RightX (object)
	if Number(object) then
		return DX(object)
	elseif NonGroup(object) then
		return RelativeX(object, 1 - object.anchorX)
	else
		return object.contentBounds.xMax
	end
end

-- Finds the y-coordinate at the top of an object; Numbers behave as per BottomY
local function TopY (object)
	if Number(object) then
		return DY(object)
	elseif NonGroup(object) then
		return RelativeY(object, -object.anchorY)
	else
		return object.contentBounds.yMin
	end
end

--- Finds the y-coordinate above an object or position.
-- @tparam ?|DisplayObject|Number ref Reference object or y-coordinate.
-- @tparam Number[opt] dy Displacement from the "above" position.
-- @treturn number Final result, i.e. y-coordinate plus any displacement.
function M.Above (ref, dy)
	return floor(TopY(ref) + DY(dy))
end

--- Finds the y-coordinate below an object or position.
-- @tparam ?|DisplayObject|Number ref Reference object or y-coordinate.
-- @tparam Number[opt] dy Displacement from the "below" position.
-- @treturn number Final result, i.e. y-coordinate plus any displacement.
function M.Below (ref, dy)
	return floor(BottomY(ref) + DY(dy))
end

--- Assigns an object's y-coordinate so that its bottom aligns with either the bottom of a
-- reference object or a y-coordinate.
-- @pobject object Object to align.
-- @tparam ?|DisplayObject|Number ref Reference object or y-coordinate.
-- @tparam Number[opt] dy Displacement from the aligned position.
function M.BottomAlignWith (object, ref, dy)
	_PutAbove_(object, _Below_(ref), dy)
end

-- Finds the x-coordinate at the center of an object...
local function CenterX (object)
	if NonGroup(object) then
		return RelativeX(object, .5 - object.anchorX)
	else
		local bounds = object.contentBounds

		return .5 * (bounds.xMin + bounds.xMax)
	end
end

-- ...and the y-coordinate
local function CenterY (object)
	if NonGroup(object) then
		return RelativeY(object, .5 - object.anchorY)
	else
		local bounds = object.contentBounds

		return .5 * (bounds.yMin + bounds.yMax)
	end
end

-- Aligns an object's center x-coordinate to an x-coordinate (plus optional delta)...
local function PutCenterAtX (object, x, dx)
	object.x = floor(object.x + DX(x) - CenterX(object) + DX(dx))
end

-- ...and aligns the y-coordinate, likewise
local function PutCenterAtY (object, y, dy)
	object.y = floor(object.y + DY(y) - CenterY(object) + DY(dy))
end

-- Centers an object horizontally at the content center x-coordinate...
local function PutAtContentCenterX (object, dx)
	PutCenterAtX(object, display.contentCenterX, dx)
end

-- ...and vertically at the y-coordinate
local function PutAtContentCenterY (object, dy)
	PutCenterAtY(object, display.contentCenterY, dy)
end

--- Assigns an object's x- and y-coordinates so that its center aligns with the center of a
-- reference object.
-- @pobject object Object to align.
-- @pobject ref_object Reference object.
-- @tparam Number[opt] dx Displacement from the aligned position's x-coordinate...
-- @tparam Number[opt] dy ...and from its y-coordinate.
function M.CenterAlignWith (object, ref_object, dx, dy)
	_CenterAt_(object, _CenterOf_(ref_object, dx, dy))
end

--- Assigns an object's x- and y-coordinates so that its center is at a position.
-- @pobject object Object to center.
-- @tparam Number[opt] x Position x-coordinate...
-- @tparam Number[opt] y ...and y-coordinate.
-- @tparam Number[opt] dx Displacement from the center's x-coordinate...
-- @tparam Number[opt] dy ...and from its y-coordinate.
function M.CenterAt (object, x, y, dx, dy)
	PutCenterAtX(object, x, dx)
	PutCenterAtY(object, y, dy)
end

--- Variant of @{CenterAt} that only assigns the x-coordinate.
-- @pobject object Object to center.
-- @tparam Number[opt] x Position x-coordinate.
-- @tparam Number[opt] dx Displacement from the x-coordinate.
function M.CenterAtX (object, x, dx)
	PutCenterAtY(object, x, dx)
end

--- Variant of @{CenterAt} that only assigns the y-coordinate.
-- @pobject object Object to center.
-- @tparam Number[opt] y Position y-coordinate.
-- @tparam Number[opt] dy Displacement from the y-coordinate.
function M.CenterAtY (object, y, dy)
	PutCenterAtY(object, y, dy)
end

--- Finds the x- and y-coordinates of an object's center.
-- @pobject object Object to query.
-- @tparam Number[opt] dx Displacement from the "center" position, x-coordinate...
-- @tparam Number[opt] dy ...and the y-coordinate.
-- @treturn number Final result, i.e. x-coordinate plus any displacement...
-- @treturn number ...and likewise, for the y-coordinate.
function M.CenterOf (object, dx, dy)
	return CenterX(object, dx), CenterY(object, dy)
end

--- Variant of @{CenterOf} that only supplies the x-coordinate.
-- @pobject object Object to query.
-- @tparam Number[opt] dx Displacement from the "center" position.
-- @treturn number Final result, i.e. x-coordinate plus any displacement.
function M.CenterX (object, dx)
	return CenterX(object, dx)
end

--- Variant of @{CenterOf} that only supplies the y-coordinate.
-- @pobject object Object to query.
-- @tparam Number[opt] dy Displacement from the "center" position.
-- @treturn number Final result, i.e. y-coordinate plus any displacement.
function M.CenterY (object, dy)
	return CenterY(object, dy)
end

--- Assigns an object's x-coordinate so that its left side aligns with either the left side
-- of a reference object or an x-coordinate.
-- @pobject object Object to align.
-- @tparam ?|DisplayObject|Number ref Reference object or x-coordinate.
-- @tparam Number[opt] dx Displacement from the aligned position.
function M.LeftAlignWith (object, ref, dx)
	_PutRightOf_(object, _LeftOf_(ref), dx)
end

--- Finds the x-coordinate to the left of an object or position.
-- @tparam ?|DisplayObject|Number ref Reference object or x-coordinate.
-- @tparam Number[opt] dx Displacement from the "left of" position.
-- @treturn number Final result, i.e. x-coordinate plus any displacement.
function M.LeftOf (ref, dx)
	return floor(LeftX(ref) + DX(dx))
end

--- Moves an object along the x-axis relative to its current position.
-- @pobject object Object to move.
-- @tparam Number[opt] dx Displacement.
function M.MoveX (object, dx)
	object.x = floor(object.x + DX(dx))
end

--- Moves an object along the y-axis relative to its current position.
-- @pobject object Object to move.
-- @tparam Number[opt] dy Displacement.
function M.MoveY (object, dy)
	object.y = floor(object.y + DY(dy))
end

--- Assigns an object's y-coordinate such that its bottom is aligned with the top of a
-- reference object or a y-coordinate.
-- @pobject object Object to position.
-- @tparam ?|DisplayObject|Number ref Reference object or y-coordinate.
-- @tparam Number[opt] dy Displacement from the "above" position.
function M.PutAbove (object, ref, dy)
	local y = TopY(ref)

	if NonGroup(object) then
		y = y - (1 - object.anchorY) * object.contentHeight
	else
		y = y - (object.contentBounds.yMax - object.y)
	end

	object.y = floor(y + DY(dy))
end

--- Centers an object horizontally and bottom-aligns it to the bottom of the content.
-- @pobject object Object to position.
-- @tparam Number[opt] dx Displacement from the center.
-- @tparam Number[opt] dy Displacement from the bottom.
function M.PutAtBottomCenter (object, dx, dy)
	PutAtContentCenterX(object, dx)
	_PutAbove_(object, display.contentHeight, dy)
end

--- Left-aligns an object to the left side of the content and bottom-aligns it to the
-- bottom of the content.
-- @pobject object Object to position.
-- @tparam Number[opt] dx Displacement from the left side.
-- @tparam Number[opt] dy Displacement from the bottom.
function M.PutAtBottomLeft (object, dx, dy)
	_PutRightOf_(object, 0, dx)
	_PutAbove_(object, display.contentHeight, dy)
end

--- Right-aligns an object to the right side of the content and bottom-aligns it to the
-- bottom of the content.
-- @pobject object Object to position.
-- @tparam Number[opt] dx Displacement from the right side.
-- @tparam Number[opt] dy Displacement from the bottom.
function M.PutAtBottomRight (object, dx, dy)
	_PutLeftOf_(object, display.contentWidth, dx)
	_PutAbove_(object, display.contentHeight, dy)
end

--- Assigns an object's x- and y-coordinates so that its center is at the content center.
-- @pobject object Object to center.
-- @tparam Number[opt] dx Displacement from the center position's x-coordinate...
-- @tparam Number[opt] dy ...and from its y-coordinate.
function M.PutAtCenter (object, dx, dy)
	PutAtContentCenterX(object, dx)
	PutAtContentCenterY(object, dy)
end

--- Left-aligns an object to the left side of the content and centers it vertically.
-- @pobject object Object to position.
-- @tparam Number[opt] dx Displacement from the left side.
-- @tparam Number[opt] dy Displacement from the center.
function M.PutAtCenterLeft (object, dx, dy)
	_PutRightOf_(object, 0, dx)
	PutAtContentCenterY(object, dy)
end

--- Right-aligns an object to the right side of the content and centers it vertically.
-- @pobject object Object to position.
-- @tparam Number[opt] dx Displacement from the right side.
-- @tparam Number[opt] dy Displacement from the center.
function M.PutAtCenterRight (object, dx, dy)
	_PutLeftOf_(object, display.contentWidth, dx)
	PutAtContentCenterY(object, dy)
end

--- Variant of @{PutAtCenter} that only assigns the x-coordinate.
-- @pobject object Object to center.
-- @tparam Number[opt] dx Displacement from the x-coordinate.
function M.PutAtCenterX (object, dx)
	PutAtContentCenterX(object, dx)
end

--- Variant of @{PutAtCenter} that only assigns the y-coordinate.
-- @pobject object Object to center.
-- @tparam Number[opt] dy Displacement from the y-coordinate.
function M.PutAtCenterY (object, dy)
	PutAtContentCenterY(object, dy)
end

--- DOCME
-- TODO: This doesn't seem to be adequate, needs to be split on (x, y)
function M.PutAtFirstHit (object, ref_object, choices, center_on_fail)
	local x, y, dx, dy = object.x, object.y, DX(choices.dx), DY(choices.dy)

	--
	for _, choice in ipairs(choices) do
		_CenterAlignWith_(object, ref_object)

		--
		if choice == "above" or choice == "below" then
			if choice == "above" then
				_PutAbove_(object, ref_object, -dy)

				if _Above_(object) >= 0 then
					return
				end
			else
				_PutBelow_(object, ref_object, dy)

				if _Below_(object) < display.contentHeight then
					return
				end
			end

		--
		elseif choice == "left_of" or choice == "right_of" then
			if choice == "left_of" then
				_PutLeftOf_(object, ref_object, -dx)

				if _LeftOf_(object) >= 0 then
					return
				end
			else
				_PutRightOf_(object, ref_object, dx)

				if _RightOf_(object) < display.contentWidth then
					return
				end
			end
		end
	end

	--
	if center_on_fail then
		_CenterAlignWith_(object, ref_object)
	else
		object.x, object.y = x, y
	end
end

--- Centers an object horizontally and top-aligns it to the top of the content.
-- @pobject object Object to position.
-- @tparam Number[opt] dx Displacement from the center.
-- @tparam Number[opt] dy Displacement from the top.
function M.PutAtTopCenter (object, dx, dy)
	PutAtContentCenterX(object, dx)
	_PutAbove_(object, 0, dy)
end

--- Left-aligns an object to the left side of the content and top-aligns it to the top of
-- the content.
-- @pobject object Object to position.
-- @tparam Number[opt] dx Displacement from the left side.
-- @tparam Number[opt] dy Displacement from the top.
function M.PutAtTopLeft (object, dx, dy)
	_PutRightOf_(object, 0, dx)
	_PutBelow_(object, 0, dy)
end

--- Right-aligns an object to the right side of the content and top-aligns it to the top
-- of the content.
-- @pobject object Object to position.
-- @tparam Number[opt] dx Displacement from the right side.
-- @tparam Number[opt] dy Displacement from the top.
function M.PutAtTopRight (object, dx, dy)
	_PutLeftOf_(object, display.contentWidth, dx)
	_PutBelow_(object, 0, dy)
end

--- Assigns an object's y-coordinate such that its top is aligned with the bottom of a
-- reference object or a y-coordinate.
-- @pobject object Object to position.
-- @tparam ?|DisplayObject|Number ref Reference object or y-coordinate.
-- @tparam Number[opt] dy Displacement from the "below" position.
function M.PutBelow (object, ref, dy)
	local y = BottomY(ref)

	if NonGroup(object) then
		y = y + object.anchorY * object.contentHeight
	else
		y = y + (object.y - object.contentBounds.yMin)
	end

	object.y = floor(y + DY(dy))
end

--- Assigns an object's x-coordinate so that its right side is to the left of a reference
-- object or an x-coordinate.
-- @pobject object Object to position.
-- @tparam ?|DisplayObject|Number ref Reference object or x-coordinate.
-- @tparam Number[opt] dx Displacement from the "left of" position.
function M.PutLeftOf (object, ref, dx)
	local x = LeftX(ref)

	if NonGroup(object) then
		x = x - (1 - object.anchorX) * object.contentWidth
	else
		x = x - (object.contentBounds.xMax - object.x)
	end

	object.x = floor(x + DX(dx))
end

--- Assigns an object's x-coordinate so that its left side is to the right of a reference
-- object or an x-coordinate.
-- @pobject object Object to position.
-- @tparam ?|DisplayObject|Number ref Reference object or x-coordinate.
-- @tparam Number[opt] dx Displacement from the "right of" position.
function M.PutRightOf (object, ref, dx)
	local x = RightX(ref)

	if NonGroup(object) then
		x = x + object.anchorX * object.contentWidth
	else
		x = x + (object.x - object.contentBounds.xMin)
	end

	object.x = floor(x + DX(dx))
end

--- Assigns an object's x-coordinate so that its right side aligns with either the right side
-- of a reference object or an x-coordinate.
-- @pobject object Object to align.
-- @tparam ?|DisplayObject|Number ref Reference object or x-coordinate.
-- @tparam Number[opt] dx Displacement from the aligned position.
function M.RightAlignWith (object, ref, dx)
	_PutLeftOf_(object, _RightOf_(ref), dx)
end

--- Finds the x-coordinate to the right of an object or position.
-- @tparam ?|DisplayObject|Number ref Reference object or x-coordinate.
-- @tparam Number[opt] dx Displacement from the "right of" position.
-- @treturn number Final result, i.e. x-coordinate plus any displacement.
function M.RightOf (ref, dx)
	return floor(RightX(ref) + DX(dx))
end

--- Assigns an object's y-coordinate so that its top aligns with either the top of a
-- reference object or a y-coordinate.
-- @pobject object Object to align.
-- @tparam ?|DisplayObject|Number ref Reference object or y-coordinate.
-- @tparam Number[opt] dy Displacement from the aligned position.
function M.TopAlignWith (object, ref, dy)
	_PutBelow_(object, _Above_(ref), dy)
end

-- Cache module members.
_Above_ = M.Above
_Below_ = M.Below
_CenterAlignWith_ = M.CenterAlignWith
_CenterAt_ = M.CenterAt
_CenterOf_ = M.CenterOf
_LeftOf_ = M.LeftOf
_PutAbove_ = M.PutAbove
_PutBelow_ = M.PutBelow
_PutLeftOf_ = M.PutLeftOf
_PutRightOf_ = M.PutRightOf
_RightOf_ = M.RightOf

-- Export the module.
return M