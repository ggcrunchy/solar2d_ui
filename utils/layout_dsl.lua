--- Implements a small domain-specific language on top of the layout system, in order to
-- make positions and dimensions more expressive.
--
-- With respect to this module, a **DSL_Number** may be either of the following:
--
-- * A number, or a string that @{tonumber} is able to convert. These values are used as is.
-- * A string of the form **"AMOUNT%"**, e.g. `"20%"` or `"-4.2%"`, which resolves to the
-- indicated percent of the content width or height.

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
local ceil = math.ceil
local getmetatable = getmetatable
local gsub = string.gsub
local sub = string.sub
local setmetatable = setmetatable
local tonumber = tonumber
local type = type

-- Modules --
local layout = require("corona_ui.utils.layout")

-- Corona globals --
local display = display

-- Cached module references --
local _AddProperties_Metatable_
local _EvalDims_
local _EvalPos_

-- Exports --
local M = {}

--
--
--

--- Augments a display object's metatable, so that its objects can also query **left**,
-- **center_x**, **right**, **bottom**, **center_y**, and **top** properties, with semantics
-- as in @{corona_ui.utils.layout}. Additionally, any of these (and also **x** and **y**)
-- may be assigned, accepting the same inputs as @{PutObjectAt}.
-- @pobject object Object which will have its metatable modified.
function M.AddProperties (object)
	local mt = getmetatable(object)

	_AddProperties_Metatable_(mt)

	setmetatable(object, mt)
end

-- Lookup for __index properties --
local Index = {
	left = layout.LeftOf, center_x = layout.CenterX, right = layout.RightOf,
	bottom = layout.Below, center_y = layout.CenterY, top = layout.Above
}

-- Lookup for __newindex properties --
local NewIndex = {
	left = layout.LeftAlignWith, center_x = layout.CenterAtX, right = layout.RightAlignWith,
	bottom = layout.BottomAlignWith, center_y = layout.CenterAtY, top = layout.TopAlignWith
}

-- Forward declarations --
local EvalNewIndex

--- Variant of @{AddProperties} that populates the metatable, e.g. for multiple uses.
-- @ptable mt Metatable (assumed to originate from a display object).
function M.AddProperties_Metatable (mt)
	local index = assert(mt.__index, "Missing __index metamethod")
	local newindex = assert(mt.__newindex, "Missing __newindex method")

	-- Augment __index...
	function mt.__index (object, k)
		local prop = Index[k]

		if prop then
			return prop(object)
		else
			return index(object, k)
		end
	end

	-- ...and __newindex.
	function mt.__newindex (object, k, v)
		local prop = NewIndex[k]

		if type(v) == "string" then
			v = EvalNewIndex(object, k, v)

			if v == nil then
				return
			end
		end

		if prop then
			prop(object, v)
		else
			newindex(object, k, v)
		end
	end
end

-- Helper to extract a number from a DSL_Number
local function ParseNumber (arg, dim, can_fail)
	local num = tonumber(arg)

	if num then
		return num
	else
		local ok = sub(arg, -1) == "%"

		assert(ok or can_fail, "Invalid argument")

		num = ok and tonumber(sub(arg, 1, -2))

		return num and num * display[dim] / 100
	end
end

--- Normalizes width and height values.
-- @tparam[opt] DSL_Number w If present, the width (e.g. 20, "10%") to normalize...
-- @tparam[opt] DSL_Number h ...and likewise, the height.
-- @treturn ?|number|nil If _w_ is absent, **nil**. Otherwise, the evaluated width.
-- @treturn ?|number|nil As per _w_, for the height.
function M.EvalDims (w, h)
	w = w and ceil(ParseNumber(w, "contentWidth")) or nil
	h = h and ceil(ParseNumber(h, "contentHeight")) or nil

	return w, h
end

-- IDEA: EvalDims_Object... could look for, say, text fields and calculate widths relative to those

-- Command parsed out a choice string; first and second number arguments to command --
local Command, Num1, Num2

-- Dimension corresponding to command --
local Dim

-- Number of tokens parsed during replacement --
local N

-- Tokenizes a command string, of the form "command[, num1[, num2]]"
local function RepToken (token)
	if not Command then
		Command = token
	else
		local num = ParseNumber(token, Dim)

		if Num1 then
			Num2 = num
		else
			Num1 = num
		end

		N = N + 1
	end
end

-- Helper to evaluate a coordinate command string
local function AuxEvalCoord (arg, choices, dim)
	Dim, N, Command, Num1, Num2 = dim, 0

	gsub(arg, "[^%s]+", RepToken, 3)

	-- Validate that a command was found, that it exists among the choices, and that not
	-- too many arguments were provided. If all these are okay, pass along the handler.
	local choice = assert(choices[Command], "Unrecognized or missing command")

	assert(N <= choice[2], "Too many arguments")

	return choice[1]
end

-- Evaluate the more basic commands
local function EvalBasic (arg, choices, dim)
	return ParseNumber(arg, dim, true) or AuxEvalCoord(arg, choices, dim)(Num1, Num2)
end

-- Helper for center commands
local function Center (func, coord)
	return {
		function(delta)
			return func(display[coord], delta)
		end, 1
	}
end

-- Helper to reverse a basic evaluation command
local function ReverseBasic (func)
	return {
		function(delta)
			return func("100%", delta)
		end, 1
	}
end

-- Choices used by EvalPos to evaluate the x-coordinte... --
local ChoicesX = {
	at = { layout.LeftOf, 2 },
	center = Center(layout.RightOf, "contentCenterX"),
	from_right = ReverseBasic(layout.LeftOf)
}

-- ...and the y-coordinate --
local ChoicesY = {
	at = { layout.Above, 2 },
	center = Center(layout.Below, "contentCenterY"),
	from_bottom = ReverseBasic(layout.Above)
}

--- Normalizes position values.
-- @tparam[opt] ?|DSL_Number|string x If _x_ is a **DSL_Number**, it evaluates as described
-- in the summary. Otherwise, if it is a string, the following commands are available:
--
-- * **"at xpos dx"**: Evaluates both _xpos_ and _dx_ and returns their sum.
-- * **"center dx"**: Evaluates _dx_ and adds it to the content center.
-- * **"from_right dx"**: Evaluates _dx_ and adds it to the right side of the content.
--
-- In the above, _xpos_ and _dx_ are of type **DSL_Number**, and resolve to 0 when absent.
--
-- Example commands: `"at 20 5%"`, `"center 10%"`, `"from_right -20"`, `"from_right -3.5%"`.
-- @tparam[opt] ?|DSL_Number|string y As per _x_. The corresponding choices are **"at"**,
-- **"center"**, and **"from_bottom"**, with the obvious changes.
-- @treturn ?|number|nil If _x_ is absent, **nil**. Otherwise, the evaluated x-coordinate.
-- @treturn ?|number|nil As per _x_.
function M.EvalPos (x, y)
	x = x and EvalBasic(x, ChoicesX, "contentWidth")
	y = y and EvalBasic(y, ChoicesY, "contentHeight")

	return x or nil, y or nil
end

-- Helper to process position / dimension fields in widget constructor options
local function AuxProcessWidgetParams (params, t)
	local x, y, w, h = params.x, params.y, _EvalDims_(params.width, params.height)

	t.left, t.top, t.x, t.y = _EvalPos_(not x and params.left, not y and params.top)
	t.width, t.height = w or t.width, h or t.height

	return t, x, y
end

--- Convenience utility for doing DSL evaluation of position- or dimension-type fields in
-- Corona-style widget constructors.
-- @ptable[opt] params If absent, this is a no-op. Otherwise, its **left**, **top**, **x**,
-- **y**, **width**, and **height** fields will be processed.
-- @ptable[opt] t Receives the evaluated params. If absent, a table is supplied (if _params_
-- also exists).
--
-- Any **x** or **y** field in _t_ is removed; the same fields in _params_ are returned,
-- instead. This separation is motivated by consistency with other DSL-using code, where
-- assignment to **x** and **y** fields support commands such as **"from_right -20"**; these
-- assume that the correct dimensions are available, yet this is not so before construction.
--
-- Any **width** or **height** field in _params_ is evaluated, cf. @{EvalDims}, the result
-- being placed into _t_. If a field is absent, it is also left untouched in _t_.
--
-- If **x** (or **y**) is present, any **left** (or **top**) field is removed from _t_.
-- Otherwise, that field is evaluated, cf. @{EvalPos}, and added to _t_.
-- @todo: The width / height are not used, say, to allow from-right/bottom alignment since
-- they aren't officially known until widget creation, and likewise this motivates the
-- separate x, y handling... however the widgets are probably predictable enough in general
-- to relax this, with some relevant notes
-- @treturn ?|table|nil _t_.
-- @treturn ?|DSL_number|string|nil If _params_ is present, the original value of `params.x`...
-- @treturn ?|DSL_number|string|nil ...and `params.y`.
function M.ProcessWidgetParams (params, t)
	local x, y

	if params then
		t, x, y = AuxProcessWidgetParams(params, t or {})
	end

	return t, x, y
end

--- Variant of @{ProcessWidgetParams} where _params_ does double duty as _t_.
-- @ptable[opt] params If absent, this is a no-op. Otherwise, as per @{ProcessWidgetParams}.
-- @treturn ?|table|nil _params_.
-- @treturn ?|DSL_number|string|nil If _params_ is present, the original value of `params.x`...
-- @treturn ?|DSL_number|string|nil ...and `params.y`.
function M.ProcessWidgetParams_InPlace (params)
	local t, x, y

	if params then
		t, x, y = AuxProcessWidgetParams(params, params)
	end

	return t, x, y
end

-- Helper to reverse an object-based evaluation command
local function ReversePut (func)
	return {
		function(object, delta)
			func(object, "100%", delta)
		end, 1
	}
end

-- Choices used by PutObjectAt to evaluate the x-coordinate... --
local PutChoicesX = {
	center = { layout.PutAtCenterX, 1 },
	from_right = ReversePut(layout.PutLeftOf),
	from_right_align = ReversePut(layout.RightAlignWith),
	left_of = { layout.PutLeftOf, 2 },
	right_of = { layout.PutRightOf, 2 }
}

-- ...and the y-coordinate --
local PutChoicesY = {
	above = { layout.PutAbove, 2 },
	below = { layout.PutBelow, 2 },
	center = { layout.PutAtCenterY, 1 },
	from_bottom = ReversePut(layout.PutAbove),
	from_bottom_align = ReversePut(layout.BottomAlignWith)
}

-- Evaluate commands that involve objects
local function EvalPut (object, arg, choices, coord)
	if arg then
		local in_xset = choices == PutChoicesX
		local dim = in_xset and "contentWidth" or "contentHeight"
		local num = ParseNumber(arg, dim, true)

		if not num then
			AuxEvalCoord(arg, choices, dim)(object, Num1, Num2)
		else
--[[
			if coord ~= "x" and coord ~= "y" then
				local a, b = object.parent:localToContent(num, num)

				num = in_xset and a or b
			end
]]
-- ^^^ TODO: x and y are local, so some consistency should be defined, like above
-- Also brings up the idea of adding *_local or *_content variant properties
			object[coord] = num
		end
	end
end

--- Puts an object at a given normalized position.
-- @pobject object Object to position.
-- @tparam ?|DSL_Number|string|nil x If absent, the x-coordinate is untouched. Otherwise,
-- the number is evaluated as in @{EvalPos} and assigned to the x-coordinate. Available
-- commands, and the corresponding x-coordinate, are:
--
-- * **"center dx"**: The content center's x-coordinate.
-- * **"from_right dx"**: The right side of the content.
-- * **"from\_right\_align dx"**: The value that aligns the right side of _object_ to the right
-- side of the content.
-- * **"left_of xpos dx"**: The value that puts the right side of _object_ at _xpos_.
-- * **"right_of xpos dx"**: The value that puts the left side of _object_ at _xpos_.
--
-- In each case, _dx_ is evaluated and added to the coordinate; the sum is the final result.
-- @tparam ?|DSL_Number|string|nil y As per _x_. The corresponding choices are **"center"**,
-- **"from_bottom"**, **"from\_bottom\_align"**, **"above"**, and **"below"**, with the obvious changes.
function M.PutObjectAt (object, x, y)
	EvalPut(object, x, PutChoicesX, "x")
	EvalPut(object, y, PutChoicesY, "y")
end

-- Set of valid "put choices" for the x-coordinate... --
local X = { x = true, left = true, center_x = true, right = true }

-- ...and for the y-coordinate --
local Y = { y = true, bottom = true, center_y = true, top = true }

-- Helper to evaluate a __newindex'd property
function EvalNewIndex (object, k, v)
	if k == "width" or k == "height" then
		local w, h = _EvalDims_(v, v)

		return k == "width" and w or h -- Let the original __newindex take it from here
	elseif X[k] then
		EvalPut(object, v, PutChoicesX, k) -- All done, so return nothing
	elseif Y[k] then
		EvalPut(object, v, PutChoicesY, k) -- Ditto
	else
		return v -- Unhandled; just let the original __newindex handle it
	end
end

_AddProperties_Metatable_ = M.AddProperties_Metatable
_EvalDims_ = M.EvalDims
_EvalPos_ = M.EvalPos

-- TODO: Pens, cursors?

return M