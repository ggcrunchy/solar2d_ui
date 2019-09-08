--- Various operations related to layout of nodes and their boxes.

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

-- Cached module references --
local _VisitGroup_

-- Exports --
local M = {}

--
--
--

local Dimensions = {}

local Separation

local function AuxGetDimensions (item, dims, group, index)
	local side = item.side

	if side then
		local extra = item.extra or 0
		local w, h, y = extra * Separation, 0

		for i = 0, extra do
			local elem = group[index + i]
	
			w, h = w + elem.contentWidth, max(h, elem.contentHeight)
		end

		if side == "lhs" then
			dims.left, y = max(dims.left, w), dims.left_y
			dims.left_y = y + h + Separation
		else
			dims.right, y = max(dims.right, w), dims.right_y
			dims.right_y = y + h + Separation
		end

		local mid = y + h / 2

		for i = 0, extra do
			group[index + i].y_offset = mid
		end

		return extra
	else
		dims.center = max(dims.center, item.contentWidth)

        local cy, ch = dims.center_y, item.contentHeight

		item.y_offset, cy = cy + ch / 2, cy + ch + Separation
		dims.center_y, dims.left_y, dims.right_y = cy, cy, cy
	end
end

local Edge, Middle

--- DOCME
function M.GetDimensions (group)
	Dimensions.center, Dimensions.left, Dimensions.right = 0, 0, 0
	Dimensions.left_y, Dimensions.right_y, Dimensions.center_y = Edge, Edge, Edge

	_VisitGroup_(group, AuxGetDimensions, Dimensions)

	local w = Dimensions.center

	if Dimensions.left > 0 and Dimensions.right > 0 then -- on each side?
		w = max(2 * max(Dimensions.left, Dimensions.right) + Middle, w)
	elseif Dimensions.left + Dimensions.right > 0 then -- one side only
		w = max(w, Dimensions.left, Dimensions.right)
	end

	w = w + 2 * Edge

	local h = max(Dimensions.center_y, Dimensions.left_y, Dimensions.right_y) - Separation -- account for last item added

    return w, h + Edge -- height already includes one Edge from starting offsets
end

--- DOCME
function M.HideItemDuringVisits (item)
    item.hidden_during_visits = true
end

local Place

--- DOCME
function M.PlaceItems (item, back, group, index)
	local side, x, y = item.side, back.x, back.y - back.height / 2

	if side then
		local extra, offset, half = item.extra, Edge, back.width / 2

		for i = 0, extra or 0 do
			item = group[index + i]

			if side == "lhs" then
				Place(item, "x", x - half + offset)
			else
				Place(item, "x", x + half - offset)
			end

			Place(item, "y", y + item.y_offset)

			offset = offset + item.contentWidth + Separation
		end

		return extra
	else
		Place(item, "x", x)
		Place(item, "y", y + item.y_offset)
	end
end

--- DOCME
function M.SetEdgeWidth (edge)
    Edge = edge
end

--- DOCME
function M.SetMiddleWidth (mid)
    Middle = mid
end

--- DOCME
function M.SetPlaceFunc (place)
    Place = place
end

--- DOCME
function M.SetSeparation (sep)
    Separation = sep
end

--- DOCME
function M.VisitGroup (group, func, arg)
	local index, n = 1, group.numChildren

	repeat
		local item, extra = group[index]

		if not item.hidden_during_visits then
			extra = func(item, arg, group, index)
		end

		index = index + 1 + (extra or 0)
	until index > n
end

_VisitGroup_ = M.VisitGroup

return M