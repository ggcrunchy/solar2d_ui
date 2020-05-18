--- Some useful UI patterns based on prompts.

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

-- Modules --
local editable_patterns = require("solar2d_ui.patterns.editable")
local timers = require("solar2d_utils.timers")

-- Corona globals --
local display = display
local native = native
local timer = timer

-- Exports --
local M = {}

--
--
--

--- DOCME
-- @ptable opts X
-- @treturn ?|AlertHandle|nil X
function M.DoActionThenProceed (opts)
	local action, alert = assert(opts and opts.action, "Missing action function")
	local follow_up = assert(opts and opts.follow_up, "Missing follow-up function")
	local needs_doing = assert(opts and opts.needs_doing, "Missing needs-doing predicate")

	-- Nothing to do: proceed.
	if not needs_doing() then
		follow_up()

	-- Otherwise: ask for confirmation to proceed.
	else
		local choices, title, message = opts.choices, opts.title, opts.message

		if choices == "save_and_quit" then
			title = title or "You have unsaved changes!"
			message = message or "Do you really want to quit?"
			choices = { "Save and quit", "Discard", "Cancel" }
		end

		assert(choices, "No choices provided")

		alert = native.showAlert(title or "Important action left undone", message or "Proceed anyway?", choices, function(event)
			if event.action == "clicked" and event.index ~= 3 then
				local do_action = event.index == 1

				timer.performWithDelay(0, function()
					if do_action then
						action(follow_up)
					else
						follow_up()
					end
				end)
			end
		end)
	end

	return alert
end

--- DOCME
-- @ptable opts
-- @param arg
-- @treturn AlertHandle
function M.ProceedAnyway (opts, arg)
	local proceed = assert(opts and opts.proceed, "Missing proceed function")
	local choices, title, message = opts.choices, opts.title, opts.message

	if choices == "ok_cancel" then
		choices = { "OK", "Cancel" }
	end

	assert(choices, "No choices provided")

	local alert = native.showAlert(title or "Caution!", message or "Proceed anyway?", choices, function(event)
		alert = nil

		if event.action == "clicked" and event.index == 1 then
			proceed(arg)
		end
	end)

	return alert
end


--
local function Message (message, what)
	return message:format(what)
end

--- DOCME
-- @tparam ?|string|nil name
-- @ptable opts
-- @param arg
-- @treturn ?|function|nil get_alert
function M.WriteEntry_MightExist (name, opts, arg)
	local exists = assert(opts and opts.exists, "Missing existence predicate")
	local writer = assert(opts and opts.writer, "Missing entry writer function")

	-- If requested, produce a getter to supply the current alert.
	local alert, get_alert

	if opts.get_alert then
		function get_alert ()
			return alert
		end
	end

	-- Name available: perform the write.
	if name then
		writer(name, arg)

	-- Unavailable: ask the user to provide one.
	else
		local group, what = opts.group or display.getCurrentStage(), opts.what or "name"
		local eopts = { text = opts.def_text or what:upper(), font = opts.font, size = opts.size }

		alert = native.showAlert(Message("Missing %s", what), Message("Please provide a %s", what), { "OK" }, function(event)
			alert = nil

			if event.action == "clicked" then
				timer.performWithDelay(0, function()
					local editable = editable_patterns.Editable_XY(group, "center", "center", eopts)

					editable:addEventListener("closing", function(event)
						local defer_cleanup

						if event.closed_by_key then
							name = editable:GetText()

							-- If the user-provided name was available, perform the write.
							if not exists(name, arg) then
								writer(name, arg)
							else
								defer_cleanup = true

								timers.WithObjectDefer(editable, function()
									-- If the user-provided name already exists, request permission before overwriting.
									alert = native.showAlert(Message("The %s is already in use!", what), "Overwrite?", { "OK", "Cancel" }, function(event)
										alert = nil

										if event.action == "clicked" and event.index == 1 then
											writer(name, arg)
										end
									end)

									editable:removeSelf()
								end)
							end
						end

						-- Hide the string until the deferred cleanup.
						if defer_cleanup then
							editable.isVisible = false
						else
							editable:removeSelf()
						end
					end)
					editable:EnterInputMode()
				end)
			end
		end)
	end

	return get_alert
end

-- Special case for files...

return M