--- Node pattern unit test.

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

-- Modules --
local NP = require("s3_editor.NodePattern")

--
--
--
local r = display.newRect(1,2,3,4)
print("!!!",r._properties)
local np = NP.New()

np:AddExportNode("result", "int")
np:AddImportNode("x", "float")
np:AddImportNode("origin*", "pos")

print(np:Generate("origin*"))
print(np:Generate("origin*"))
print(np:Generate("origin*"))

local another = np:Generate("origin*")

print(another, np:GetTemplate(another))
print("nn|2|", np:GetTemplate("nn*"))
print("x", np:GetTemplate("x"))

print(np:HasNode("result"))
print(np:HasNode("x", "imports"))
print(np:HasNode("origin*", "imports"))
print(np:HasNode("result", "imports"))
print(np:HasNode("duck", "other"))
print(np:HasNode("cluck", "exports"))

local function Iter (patt)
    for k, v in patt:IterNodes() do
        print("GENERAL NODE", k, v)
    end

    for k, v in patt:IterNodes("exports") do
        print("EXPORT NODE", k, v)
    end

    for k, v in patt:IterNodes("imports") do
        print("IMPORT NODE", k, v)
    end

    for k, v in patt:IterTemplateNodes() do
        print("GENERAL TEMPLATE NODE", k, v)
    end

    for k, v in patt:IterNonTemplateNodes() do
        print("GENERAL NON-TEMPLATE NODE", k, v)
    end
end

print("")
print("MIXED PATTERN")

Iter(np)

print("")

local env = np:GetEnvironment()

for k, v in np:IterNodes() do
    print("FIND RULE " .. k .. ":", env:GetRuleInfo(v))
end

print("")

do
    local npe = NP.New()

    npe:AddExportNode("only_export", "int")

    print("EXPORT-ONLY PATTERN")

    Iter(npe)

    print("")
end

do
    local npi = NP.New()

    npi:AddImportNode("only_import", "int")

    print("IMPORT-ONLY PATTERN")

    Iter(npi)

    print("")
end

do
    local np0 = NP.New()

    print("EMPTY PATTERN")

    Iter(np0)

    print("")
end