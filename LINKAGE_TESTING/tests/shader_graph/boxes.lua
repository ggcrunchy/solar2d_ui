--- Shader graph box logic.

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
local error = error
local pairs = pairs
local remove = table.remove

-- Modules --
local dfs = require("tests.shader_graph.dfs")
local nc = require("corona_ui.patterns.node_cluster")
local nl = require("tests.shader_graph.node_layout")
local ns = require("tests.shader_graph.node_state")

-- Cached module references --
local _SetCodeSegmentName_

-- Exports --
local M = {}

--
--
--

--
-- Connectedness search
--

local AdjacencyStack = {}

local function AuxAdjacentBoxesIter (_, n)
	if n > 0 then
		return n - 1, remove(AdjacencyStack)
	end
end

local function MakeAdjacencyIterator (gather)
	return function(_, box) -- TODO: node works as index EXCEPT with undo / redo
		local n = #AdjacencyStack

		nl.VisitNodesConnectedToChildren(box, gather)

		return AuxAdjacentBoxesIter, nil, #AdjacencyStack - n
	end
end

local OnFoundHard

local function GatherResolvableBoxes (neighbor, parent_node)
	local what = ns.Classify(neighbor, parent_node)

	if what == "hard" then
		OnFoundHard()
	elseif what == "neither_hard" then
		AdjacencyStack[#AdjacencyStack + 1] = neighbor.parent
	end
end

local Opts = { adjacency_iter = MakeAdjacencyIterator(GatherResolvableBoxes) }

--
-- Connect / Resolve
--

local ConnectAlg = dfs.NewAlgorithm()

local ConnectionGen = 0

local ToResolve = {}

local function DoConnect (graph, box, adj_iter)
	ToResolve[box] = ConnectionGen

	dfs.VisitAdjacentVertices_Once(ConnectAlg, DoConnect, graph, box, adj_iter)
end

local function MakeResolve (func)
	return function(parent, rtype)
		ns.SetResolvedType(parent, rtype)

		for i = 1, parent.numChildren do
			func(parent[i], rtype)
		end
	end
end

--
-- Disconnect / Decay
--

local DisconnectAlg = dfs.NewAlgorithm()

local DecayCandidates = { n = 0 }

local NoHardNodes

local function DoDisconnect (graph, box, adj_iter)
	if NoHardNodes then
		local n = DecayCandidates.n + 1

		DecayCandidates[n], DecayCandidates.n = box, n

		dfs.VisitAdjacentVertices_Once(DisconnectAlg, DoDisconnect, graph, box, adj_iter)
	end
end

local function CanReachHardNode ()
	NoHardNodes = false
end

local ToDecay = {}

local function ExploreDisconnectedNode (node)
	DecayCandidates.n, NoHardNodes = 0, true

	dfs.VisitRoot(DisconnectAlg, DoDisconnect, node.parent, Opts)

	for i = 1, NoHardNodes and DecayCandidates.n or 0 do
		ToDecay[DecayCandidates[i]] = ConnectionGen
	end

	for i = 1, DecayCandidates.n do
		DecayCandidates[i] = false
	end
end

local function MakeDecay (func)
	return function(parent)
		for i = 1, parent.numChildren do
			func(parent[i])
		end

		ns.SetResolvedType(parent, nil)
	end
end

--
-- Cycle check
--

local CycleCheckOpts = {}

local FromBox, FromSide, CycleFormed

CycleCheckOpts.adjacency_iter = MakeAdjacencyIterator(function(neighbor)
	if neighbor.parent == FromBox then
		CycleFormed = true
	elseif nc.GetSide(neighbor) == FromSide then
		AdjacencyStack[#AdjacencyStack + 1] = neighbor.parent
	end
end)

local CycleCheckAlg = dfs.NewAlgorithm()

local function DoCycleCheck (graph, box, adj_iter)
	if not CycleFormed then
		dfs.VisitAdjacentVertices_Once(CycleCheckAlg, DoCycleCheck, graph, box, adj_iter)
	end
end

local function FormsCycle (from, to)
	FromBox, FromSide, CycleFormed = from.parent, nc.GetSide(from)

	dfs.VisitRoot(CycleCheckAlg, DoCycleCheck, to.parent, CycleCheckOpts)

	FromBox = nil

	return CycleFormed
end

--
-- Program building
--

local PendingValues = {}

local function GatherRHS (neighbor, parent_node)
	if nc.GetSide(neighbor) == "rhs" then -- or equivalently, parent node on lhs
		local box = neighbor.parent

		PendingValues[#PendingValues + 1] = box
		PendingValues[#PendingValues + 1] = parent_node

		AdjacencyStack[#AdjacencyStack + 1] = box
	end
end

local BuildOpts = { adjacency_iter = MakeAdjacencyIterator(GatherRHS) }

local SortedBoxes = {}

local BuildAlg = dfs.NewAlgorithm{
	after_visit = function(box)
		SortedBoxes[#SortedBoxes + 1] = box
	end
}

local function DoBuild (graph, box, adj_iter)
	-- CLEAR_VALUES

	dfs.VisitAdjacentVertices_Once(BuildAlg, DoBuild, graph, box, adj_iter)
end

local BuildGen

local IsBuildDirty

local LastInLine

local function Rebuild ()
	if IsBuildDirty then
		BuildGen, IsBuildDirty = (BuildGen or 0) + 1 -- by default, not even last-in-line has generation;
													-- it implicitly has generation "nil", like any other
													-- box, thus the first connection will dirty it

		dfs.VisitTopLevel(BuildAlg, DoBuild, LastInLine, BuildOpts)

		local pi, ni = #PendingValues - 1, 1

		for i = #SortedBoxes, 1, -1 do
			local box = SortedBoxes[i]

			if PendingValues[pi] == box then
--				local name = ??? .. ni
				-- clear values

				repeat
					local parent_node = PendingValues[pi + 1]
					-- SET_VALUE(parent_node.parent, GET_VALUE_NAME(parent_node), name)

					pi, PendingValues[pi], PendingValues[pi + 1] = pi - 2
				until PendingValues[pi] ~= box

				ni = ni + 1
			end

			-- add box to lookup
			-- patch any lookups into box code
			-- append code

			SortedBoxes[i] = nil
		end

		for i = #SortedBoxes, 1, -1 do
			-- remove from lookup
			SortedBoxes[i] = nil
		end

		-- concat and apply
	end
end

--
-- Cluster logic
--

local function ApplyChanges (resize, list, func, arg)
	for box, gen in pairs(list) do
		if gen == ConnectionGen then
			func(box, arg)
            resize(box)
		end

        list[box] = nil
	end
end

local function CanConnect (a, b)
    local compatible = ns.WilcardOrHardType(a) == ns.WilcardOrHardType(b) -- e.g. restrict to vectors, matrices, etc.
    local how1, what1 = ns.QueryRule(a, b, compatible)
    local how2, what2 = ns.QueryRule(b, a, compatible)

    if how1 and how2 and not FormsCycle(a, b) then
        if how1 == "resolve" then
            a.resolve = what1
        elseif how2 == "resolve" then
            b.resolve = what2
        end

        return true
    end
end

local function EnumerateDecayCandidates (a, b)
    local ctype, x, y = ns.Classify(a, b)

    if ctype == "neither_hard" and ns.ResolvedType(a) then -- if a is resolved, so is b
        return 2, a, b
    else
        return ctype == "hard" and 1 or 0, x, y
    end
end

local function FindNodeToResolve (a, b)
    local ctype, x, y = ns.Classify(a, b)

    if ctype == "hard" and not ns.ResolvedType(y) then
        return y, ns.HardType(x)
    elseif ctype == "neither_hard" then
        local atype, btype = ns.ResolvedType(a), ns.ResolvedType(b)

        if atype and not btype then
            return b, atype
        elseif btype and not atype then
            return a, btype
        end
    end
end

local IsDeferred

--- DOCME
function M.DeferDecays ()
	IsDeferred = true
end

--[=[
function M.ResetValues (box)
	local inputs = box.m_inputs

	for k in pairs(box.m_scheme) do
		inputs[k] = nil
	end
end

function M.SetValue (box, name, value)
	box.m_inputs[name] = value
end

local HasDeclaration

local BoxType, Inputs, Scheme

local function ReplaceInCode (s)
	local v = Inputs[k]

	if v ~= nil then
		return v
	elseif s ~= [[DECL]] then
		return Scheme[s](BoxType)
	else
		HasDeclaration = true

		return false
	end
end

function M.SetVarCounter (n)
	VarCounter = n
end

function M.UpdateCode (box)
	local code_form = box.m_code_form

	if code_form then
		BoxType, Inputs, Scheme, HasDeclaration = ns.ResolvedTypeOfParent(box), box.m_inputs, box.m_scheme

		local code = code_form:gsub("%$([_%w]+)", ReplaceInCode)

		if HasDeclaration then
			VarCounter = VarCounter + 1

			local name = "_var" .. VarCounter

			_SetCodeSegmentName_(box, name)

			code = code:gsub([[DECL]], BoxType .. " _var" .. VarCounter)
		end

		Inputs, Scheme = nil

		return code
	end
end
--]=]


--- DOCME
function M.MakeClusterFuncs (ops)
	local resize, decay, resolve = ops.resize, MakeDecay(ops.decay_item), MakeResolve(ops.resolve_item)

	local function DoDecays (how)
		ApplyChanges(resize, ToDecay, decay)

		ConnectionGen = ConnectionGen + 1

		if how == "rebuild" then
			Rebuild()
		end
	end

	return CanConnect, function(how, a, b)
		local aparent, bparent = a.parent, b.parent

		if aparent.build_gen == BuildGen or bparent.build_gen == BuildGen then -- potentially affects code?
			IsBuildDirty = true
		end

		if how == "connect" then -- n.b. display object does NOT exist yet...
			IsDeferred = true -- defer any decays introduced by the next two calls

			nl.BreakConnections(a)
			nl.BreakConnections(b)

			aparent.bound, bparent.bound = aparent.bound + a.bound_bit, bparent.bound + b.bound_bit

			local rnode, rtype = FindNodeToResolve(a, b)

			if rnode then
				OnFoundHard = error -- any hard nodes along the way violate the node's unresolved state

				dfs.VisitRoot(ConnectAlg, DoConnect, rnode.parent, Opts)
			end

			local adgen, bdgen = ToDecay[aparent], ToDecay[bparent]

			if adgen == ConnectionGen and adgen == ToResolve[bparent] then
				ToResolve[bparent] = nil
			elseif bdgen == ConnectionGen and bdgen == ToResolve[aparent] then
				ToResolve[aparent] = nil
			end
			--[=[
			for index, gen in pairs(ToDecay) do -- breaking old connections can put boxes in the to-decay list, but
												-- the new connection might put them in the to-resolve list; these
												-- boxes are already resolved, so remove them from both lists
				if gen == ConnectionGen and ToResolve[index] == gen then
--print("MIRBLE")
					ToDecay[index], ToResolve[index] = nil
				end
			end
			]=]
-- seems to be missing that it's decaying, but the other thing WILL be resolved?
			ApplyChanges(resize, ToDecay, decay)

			if rtype then
				ApplyChanges(resize, ToResolve, resolve, rtype)
			end

			Rebuild()
--DUMP_INFO("connect")
			ConnectionGen, IsDeferred = ConnectionGen + 1
		elseif how == "disconnect" then -- ...but here it usually does, cf. note in FadeAndDie()
			aparent.bound, bparent.bound = aparent.bound - a.bound_bit, bparent.bound - b.bound_bit

			local ncandidates, x, y = EnumerateDecayCandidates(a, b)

			OnFoundHard = CanReachHardNode -- we throw away decay candidates if any node has a hard connection

			if ncandidates == 2 then -- not a hard connection, so either node is a candidate...
				ExploreDisconnectedNode(x)
			end

			if ncandidates >= 1 then -- ...whereas in a hard connection, only the non-hard one is
				ExploreDisconnectedNode(y)
			end
--DUMP_INFO("disconnect")
			if ncandidates > 0 and not IsDeferred then -- defer disconnections happening as a side effect of a connection or deletion
				DoDecays()
				Rebuild()
			end
		end
	end, DoDecays
end

--- DOCME
function M.PutLastInLine (box)
	LastInLine = box
end

--- DOCME
function M.RemoveFromDecayList (box)
	ToDecay[box] = nil
end

--- DOCME
function M.ResumeDecays ()
	IsDeferred = false
end

--- DOCME
function M.SetCodeSegmentName (box, name)
	box.m_code_segment_name = name
end
--[=[
function DUMP_INFO (why)
	local stage = display.getCurrentStage()
	local Connected={}
	local nc = require("corona_ui.patterns.node_cluster")
	print("DUMP", why)
	for i = 1, stage.numChildren do
		local p = stage[i]
		if p.numChildren and p.numChildren >= 2 and p[2].text then
			print("ELEMENT:", p, p[2].text)

			local info = {}
			for k, v in pairs(p) do
if k ~= "_class" and k ~= "_proxy" and k ~= "back" then -- skip some unenlightening stuff
				info[#info + 1] = ("%s = %s"):format(tostring(k), tostring(v))
end
			end
			print("{ " .. table.concat(info, ", ") .. " }")

			for j = 3, p.numChildren do
				local _, n = nc.GetConnectedObjects(p[j], Connected)

				if n > 0 then
					print("NODE: ", p[j + 1].text, NODE_INFO(p[j]))

					for k = 1, n do
						print("CONNECTED TO: ", NODE_INFO(Connected[k]))
					end

					print("")
				end
			end

			print("")
		end
	end
end
--]=]
_SetCodeSegmentName_ = M.SetCodeSegmentName

return M