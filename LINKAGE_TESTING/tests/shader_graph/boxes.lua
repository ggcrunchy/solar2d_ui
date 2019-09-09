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

-- Modules --
local dfs = require("tests.shader_graph.dfs")
local ns = require("tests.shader_graph.node_state")

-- Exports --
local M = {}

--
--
--

--
-- Connectedness search
--

local AdjacentBoxes = {}

local function AuxAdjacentBoxesIter (_, i)
	i = i + 1

	if i <= AdjacentBoxes.n then
		return i, AdjacentBoxes[i]
	else -- clean up when done
		for j = 1, AdjacentBoxes.n do
			AdjacentBoxes[j] = false
		end
	end
end

local OnFoundHard

local function GatherAdjacentBoxes (neighbor, node)
	local what = ns.Classify(neighbor, node)

	if what == "hard" then
		OnFoundHard()
	elseif what == "neither_hard" then
		local n = AdjacentBoxes.n + 1

		AdjacentBoxes.n, AdjacentBoxes[n] = n, neighbor
	end
end

local function AdjacentBoxesIter (_, node) -- TODO: node works as index EXCEPT with undo / redo
	AdjacentBoxes.n = 0

	ns.VisitConnectedNodes(node.parent, GatherAdjacentBoxes, node)

	return AuxAdjacentBoxesIter, AdjacentBoxes.n, 0
end

local function AuxTopLevelNode (x, ok)
	if ok then
		return false, nil, x
	end
end

local function TopLevelNode (top_level_vertices)
	return AuxTopLevelNode, top_level_vertices, true
end

local Opts = { adjacency_iter = AdjacentBoxesIter, top_level_iter = TopLevelNode }

--
-- Connect / Resolve
--

local ConnectAlg = dfs.NewAlgorithm()

local ConnectionGen = 0

local ToResolve = {}

local function DoConnect (graph, node, adj_iter)
	ToResolve[node.parent] = ConnectionGen

	dfs.VisitAdjacentVertices_Once(ConnectAlg, DoConnect, graph, node, adj_iter)
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

local function DoDisconnect (graph, node, adj_iter)
	local n = DecayCandidates.n + 1

	DecayCandidates[n], DecayCandidates.n = node.parent, n

	dfs.VisitAdjacentVertices_Once(DisconnectAlg, DoDisconnect, graph, node, adj_iter)
end

local function CanReachHardNode ()
	DecayCandidates.n = 0 / 0
end

local ToDecay = {}

local function ExploreDisconnectedNode (node)
	DecayCandidates.n = 0

	dfs.VisitTopLevel(DisconnectAlg, DoDisconnect, node, Opts)

	if DecayCandidates.n == DecayCandidates.n then -- unable to reach hard node?
		for i = 1, DecayCandidates.n do
			ToDecay[DecayCandidates[i]], DecayCandidates[i] = ConnectionGen, false
		end
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

    if how1 and how2 then
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

--- DOCME
function M.MakeClusterFuncs (ops)
	local resize, decay, resolve = ops.resize, MakeDecay(ops.decay_item), MakeResolve(ops.resolve_item)

	local function DoDecays ()
		ApplyChanges(resize, ToDecay, decay)

		ConnectionGen = ConnectionGen + 1
	end

	return CanConnect, function(how, a, b)
		local aparent, bparent = a.parent, b.parent

		if how == "connect" then -- n.b. display object does NOT exist yet...
			IsDeferred = true -- defer any decays introduced by the next two calls

			ns.BreakConnections(a)
			ns.BreakConnections(b)

			aparent.bound, bparent.bound = aparent.bound + a.bound_bit, bparent.bound + b.bound_bit

			local rnode, rtype = FindNodeToResolve(a, b)

			if rnode then
				OnFoundHard = error -- any hard nodes along the way violate the node's unresolved state

				dfs.VisitTopLevel(ConnectAlg, DoConnect, rnode, Opts)
			end

			for index, gen in pairs(ToDecay) do -- breaking old connections can put boxes in the to-decay list, but
												-- the new connection might put them in the to-resolve list; these
												-- boxes are already resolved, so remove them from both lists
				if gen == ConnectionGen and ToResolve[index] == gen then
					ToDecay[index], ToResolve[index] = nil
				end
			end

			ApplyChanges(resize, ToDecay, decay)

			if rtype then
				ApplyChanges(resize, ToResolve, resolve, rtype)
			end

		--	DUMP_INFO("connect")
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

		--	DUMP_INFO("disconnect")
			if ncandidates > 0 and not IsDeferred then -- defer disconnections happening as a side effect of a connection or deletion
				DoDecays()
			end
		end
	end, DoDecays
end

--- DOCME
function M.RemoveFromDecayList (box)
	ToDecay[box] = nil
end

--- DOCME
function M.ResumeDecays ()
	IsDeferred = false
end

return M
--[=[
function DUMP_INFO (why)
	local stage = display.getCurrentStage()
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
]=]