--- Some useful UI patterns based around editable strings.

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
local concat = table.concat
local gmatch = string.gmatch
local lower = string.lower
local max = math.max
local sub = string.sub
local tonumber = tonumber
local upper = string.upper

-- Modules --
local cursor = require("corona_ui.utils.cursor")
local keyboard = require("corona_ui.widgets.keyboard")
local layout = require("corona_ui.utils.layout")
local net = require("corona_ui.patterns.net")
local layout_dsl = require("corona_ui.utils.layout_dsl")
local layout_strategies = require("corona_ui.utils.layout_strategies")
local scenes = require("corona_utils.scenes")

-- Corona globals --
local display = display
local easing = easing
local native = native
local system = system
local timer = timer
local transition = transition

-- Exports --
local M = {}

--
local function Char (name, is_shift_down)
	--
	if name == "space" then
		return " "
	elseif name == "-" and is_shift_down then
		return "_"

	--
	elseif #name == 1 then -- what about UTF8?
		local ln, un = lower(name), upper(name)

		if ln ~= name then
			return is_shift_down and ln or name
		elseif un ~= name then
			return is_shift_down and un or name
		end
	end
end

--
local function Num (name)
	if name == "." or tonumber(name) then
		return name
	end
end

-- ^^^ Allows multiple decimal points in string (also issue with keyboard, not sure about native)

--
local function Any (name, is_shift_down)
	return Char(name, is_shift_down) or Num(name)
end

--
local function AdjustAndClamp (info, n, how)
	local remove_at, new_pos = info.m_pos

	if how == "dec" then
		new_pos = remove_at > 0 and remove_at - 1
	elseif remove_at < n then
		if how == "inc" then
			new_pos = remove_at + 1
		else
			new_pos, remove_at = remove_at, remove_at + 1
		end
	end

	if new_pos then
		return new_pos, remove_at
	end
end

-- Event packet --
local Event = {}

--
local function SetText (str, text, align, w)
	local old = str.text or ""

	str.text = text

	if align == "left" then
		layout.LeftAlignWith(str, ".25%")
	elseif align == "right" then
		layout.RightAlignWith(str, w, "-.25%")
	end

	-- Alert listeners.
	if old ~= text then
		Event.old_text, Event.new_text, Event.name, Event.target = old, text, "text_change", str.parent

		str.parent:dispatchEvent(Event)

		Event.target = nil
	end
end

--
local function UpdateCaret (info, str, pos)
	if pos then
		info.m_pos = pos

		layout.LeftAlignWith(info.parent:GetCaret(), str, cursor.GetOffset(str, pos))
	end
end

--- ^^ COULD be stretched to current character width, by taking difference between it and next character,
-- or rather the consecutive substrings they define (some default width at string end)

-- --
local KeyType = {}

for gname, group in pairs{
	delete = { "deleteBack", "deleteForward" },
	horz_move = { "end", "home", "left", "right" },
	vert_move = { "down", "pageDown", "pageUp", "up" }
} do
	for i = 1, #group do
		KeyType[group[i]] = gname
	end
end

--
local function DoKey (info, name, is_shift_down)
	local str = info.parent:GetString()
	local text, gname = str.text, KeyType[name]

	--
	if gname == "delete" then
		local new_pos, remove_at = AdjustAndClamp(info, #text, name == "deleteBack" and "dec")

		if remove_at then
			text = sub(text, 1, remove_at - 1) .. sub(text, remove_at + 1)

			SetText(str, text, info.m_align, info.m_width)
			UpdateCaret(info, str, new_pos)
		end

	--
	elseif gname == "horz_move" then
		local pos

		if name == "left" or name == "right" then
			pos = AdjustAndClamp(info, #text, name == "left" and "dec" or "inc")
		else
			pos = name == "home" and 0 or #text
		end

		UpdateCaret(info, str, pos)

	--
	elseif gname == "vert_move" then
		-- TODO! (multiline)

	--
	else
-- Tab?
		local result, pos = (info.m_filter or Any)(name, is_shift_down), info.m_pos

		if result then
			text = sub(text, 1, pos) .. result .. sub(text, pos + 1)

			SetText(str, text, info.m_align, info.m_width)
			UpdateCaret(info, str, pos + 1)
		else
			return false
		end
	end

	return true
end

-- --
local OldListenFunc

-- --
local Editable

-- --
local FadeAwayParams = { alpha = 0, onComplete = display.remove }

-- --
local KeyFadeOutParams = {
	alpha = .2,

	onComplete = function(object)
		object.isVisible = false
	end
}

--
local function CloseKeysAndText (by_key)
	local caret, keys = Editable:GetCaret(), Editable:GetKeyboard()

	--
	Event.name, Event.target, Event.closed_by_key = "closing", Editable, by_key ~= nil

	Editable:dispatchEvent(Event)

	Event.target = nil

	--
	scenes.SetListenFunc(OldListenFunc)
	transition.cancel(caret)
	transition.to(Editable.m_net, FadeAwayParams)

	caret.isVisible = false

	--
	net.RestoreAfterHoist(Editable, Editable.m_stub)

	Editable, OldListenFunc, Editable.m_net, Editable.m_stub = nil

	--
	if keys then
		transition.to(keys, KeyFadeOutParams)
	end
end

--
local function HandleKey (event)
	local name = event.keyName

	--
	if event.isCtrlDown then
		return

	--
	elseif name ~= "enter" then
		for i = 1, Editable.numChildren do
			local item = Editable[i]

			if item.m_pos then
				--
				if event.phase == "down" then
					local is_shift_down = event.isShiftDown

					if not item.m_timer and DoKey(item, name, is_shift_down) then
						item.m_timer, item.m_key = timer.performWithDelay(350, function()
							DoKey(item, name, is_shift_down)
						end, 0), name
					end

				--
				elseif item.m_key == name then
					timer.cancel(item.m_timer)

					item.m_key, item.m_timer = nil
				end

				break
			end
		end

	--
	elseif event.phase == "down" then
		CloseKeysAndText(true)
	end

	return true
end

--
local function Listen (what, event)
	if what == "message:handles_key" then
		HandleKey(event)
	end
end

-- --
local Filter = { chars = Char, nums = Num }

-- --
local CaretParams = { time = 650, iterations = -1, alpha = .125, transition = easing.continuousLoop }

-- --
local FadeInParams = { alpha = .4 }

-- --
local KeyFadeInParams = { alpha = 1 }

-- --
local XSep, YSep = layout_dsl.EvalDims(".625%", "1.04%")

-- --
local PlaceKeys = { "below", "above", "bottom_center", "top_center", dx = XSep, dy = YSep }

--
local function EnterInputMode (editable)
	Editable, OldListenFunc = editable, scenes.SetListenFunc(Listen)

	--
	editable.m_stub, editable.m_net = net.HoistOntoStage(editable, CloseKeysAndText, editable.m_blocking)

	--
	local caret, keys = editable:GetCaret(), editable:GetKeyboard()

	if keys then
		keys:toFront()
	end

	--
	caret.alpha, caret.isVisible, Editable.m_net.alpha = .6, true, .01

	transition.to(caret, CaretParams)
	transition.to(Editable.m_net, FadeInParams)

	if keys then
		layout_strategies.PutAtFirstHit(keys, editable, PlaceKeys, true)

		keys.alpha, keys.isVisible = .2, true

		transition.to(keys, KeyFadeInParams)
	end
end

--
local function Touch (event)
	if event.phase == "began" then
		if Editable then
			local str = event.target.parent:GetString()
			local pos = cursor.GetPosition_GlobalXY(str, event.x, event.y)

			UpdateCaret(cursor.GetProxy(str), str, pos)

			-- TODO: detect drags
		else
			EnterInputMode(event.target.parent)
		end
	end

	return true
end

-- TODO: Handle taps in text case? (then need to pinpoint position...)
-- Needs to handle all three alignments, too

--
local function AuxEditable (group, x, y, opts)
	local Editable = display.newGroup()

	Editable.anchorChildren = true

	--
	local text, font, size = opts and opts.text or "", opts and opts.font or native.systemFontBold, layout.ResolveY(opts and opts.size or "4.2%")
	local str, info = cursor.NewText(Editable, text, 0, 0, font, size)
	local ow, oh = layout_dsl.EvalDims(opts and opts.width or 0, opts and opts.height or 0)
	local w, h, align = max(str.width, ow, layout.ResolveX("10%")), max(str.height, oh, layout.ResolveY("5.2%")), opts and opts.align

	SetText(str, str.text, align, w)

	--
	Editable.m_blocking = not not (opts and opts.blocking)

	--
	local caret = display.newRect(Editable, 0, 0, XSep, str.height)

	layout.PutRightOf(caret, str)

	caret.isVisible = false

	--
	info.m_align, info.m_pos, info.m_width = align, #text, w

	--
	local style, keys, mode = opts and opts.style, opts and opts.mode

	if style == "text_only" then
		info.m_filter = Filter[mode]
	elseif style == "keys_and_text" or system.getInfo("platformName") == "Win" then
		keys = keyboard.Keyboard(display.getCurrentStage(), mode and { type = mode })

		info.m_filter, keys.isVisible = Filter[mode], false
	else
		-- native textbox... not sure about filtering
		--[[
		-- Create text field
			defaultField = native.newTextField( 150, 150, 180, 30 )

			defaultField:addEventListener("userInput", function(event)
				if event.phase == "ended" then
					-- ???
				elseif event.phase == "submitted" then
					if pred() == true then
						--
					else
						--
					end
				end
			end)
			...
			native.setKeyboardFocus()
		]]
	end

	--
	local body = display.newRoundedRect(Editable, 0, 0, w + XSep, h + YSep, layout.ResolveX("1.5%"))

	body:addEventListener("touch", Touch)
	body:setFillColor(0, 0, .9, .6)
	body:setStrokeColor(.125)
	body:toBack()

	body.strokeWidth = 2

	--
	layout_dsl.PutObjectAt(Editable, x, y)

	group:insert(Editable)

	--- DOCME
	function Editable:GetCaret ()
		return caret
	end

	--- DOCME
	function Editable:GetChildOfParent ()
		return self.m_stub or self
	end

	--- DOCME
	function Editable:GetKeyboard ()
		return keys
	end

	--- DOCME
	function Editable:GetString ()
		return str
	end

	--- DOCME
	function Editable:EnterInputMode ()
		if false then -- textinput...
			--
		elseif not Editable then
			EnterInputMode(self)
		end
	end

	--- DOCME
	function Editable:SetText (text)
		local filter, chars = info.m_filter or Any

		for char in gmatch(text, ".") do
			chars = chars or {}

			chars[#chars + 1] = filter(char)
		end

		SetText(str, chars and concat(chars, "") or "", align, w)
	end

	--
	if keys --[[ or textinput ]] then
		Editable:addEventListener("finalize", function(event)
			display.remove(keys)
			display.remove(event.target.m_net)
			display.remove(event.target.m_stub)
		end)
	end

	return Editable
end

--- DOCME
function M.Editable (group, opts)
	return AuxEditable(group, 0, 0, opts)
end

--- DOCME
function M.Editable_XY (group, x, y, opts)
	return AuxEditable(group, x, y, opts)
end

-- Export the module.
return M