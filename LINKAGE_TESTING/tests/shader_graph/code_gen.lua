--- Various functionality associated with shader code generation.

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
local pairs = pairs
local type = type

-- Unique keys --
local _code_form = {}
local _exported_name = {}
local _inputs = {}
local _scheme = {}
local _value_name = {}

-- Exports --
local M = {}

--
--
--

--- DOCME
function M.Generate (box, box_type, decl)
	local code_form = box[_code_form]

	if code_form then
        local inputs, scheme = box[_inputs], box[_scheme]

        for k, v in pairs(scheme) do
            if inputs[k] == nil then
                inputs[k] = type(v) == "string" and v or v(box_type)
            end
        end

		local code = code_form:gsub("[_%a][_%w]*", inputs)

		if decl then
			code = "P_DEFAULT " .. box_type .. " " .. decl .. " = " .. code
		end

		return code
	end
end

--- DOCME
function M.GetExportedName (box)
    return box[_exported_name]
end

--- DOCME
function M.GetValueName (node)
	return node[_value_name]
end

--- DOCME
function M.ResetValues (box)
	local inputs = box[_inputs]

	if inputs then
		for k in pairs(inputs) do
			inputs[k] = nil
		end
	end
end

--- DOCME
function M.SetCodeForm (box, code_form, scheme)
	assert(not code_form == not scheme, "Missing code form or scheme")

	box[_code_form], box[_scheme] = code_form, scheme
	box[_inputs] = code_form and {} or nil
end

--- DOCME
function M.SetExportedName (box, name)
    box[_exported_name] = name
end

--- DOCME
function M.SetValueName (node, vname)
	node[_value_name] = vname
end

--- DOCME
function M.SetValue (box, value_name, value)
	assert(box[_inputs], "Box is not configured for code")[value_name] = value
end

return M