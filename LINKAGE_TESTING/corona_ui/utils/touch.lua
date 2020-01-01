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

-- Corona globals --
local display = display

-- Exports --
local M = {}

--
--
--

local FakeTouch

local function AuxSpoof (target, phase)
	FakeTouch = FakeTouch or { id = "ignore_me", name = "touch" }

	FakeTouch.target, FakeTouch.phase = target, phase

	if phase == "began" then
		FakeTouch.x, FakeTouch.y = target:localToContent(0, 0)
	end

	target:dispatchEvent(FakeTouch)

	FakeTouch.target = nil
end

--- DOCME
function M.Spoof (target)
	AuxSpoof(target, "began")
	AuxSpoof(target, "moved")
	AuxSpoof(target, "ended")
end

local HasFocus = {}

local function RemoveID (event)
	HasFocus[event.target] = nil
end

local function SetFocus (target, id)
	display.getCurrentStage():setFocus(target, id)

	if HasFocus[target] == nil then -- is first assignment?
		target:addEventListener("finalize", RemoveID)
	end

	HasFocus[target] = id or false -- make nil ids false, since absence indicates first assignment
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
function M.Wrap (began, moved, ended)
	if moved == "began" then
		moved = began
	end

	if ended == "began" then
		ended = began
	elseif ended == "moved" then
		ended = moved
	end

	return function(event)
		local result, id, target = true, event.id, event.target

		if event.phase == "began" then
			local began_result = began(event, target)

			if began_result == "ignore_touch" then
				id = nil
			elseif began_result == "pass_through" then
				result = false
			end

			if id ~= "ignore_me" then
				SetFocus(target, id)
			end

		elseif HasFocus[target] == id or id == "ignore_me" then
			if event.phase == "moved" and moved then
				moved(event, target)

			elseif event.phase == "ended" or event.phase == "cancelled" then
				if id ~= "ignore_me" then
					SetFocus(target, nil)
				end

				if ended then
					ended(event, target)
				end
			end
		end

		return result
	end
end

return M