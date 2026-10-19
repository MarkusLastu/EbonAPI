local NS = SkillTreeAutoLoad

local Plan = {}
NS.Plan = Plan

local parentsOf, childrenOf, maxRankOf, costsOf, isStartNode

local EMPTY = {}

local function BuildGraph()
    if parentsOf then return true end

    local db = EbonAPI.Ebonhold.TalentDatabase()
    local tree = db and db[0]
    if not (tree and tree.nodes and tree.links) then return false end

    parentsOf, childrenOf, maxRankOf, costsOf, isStartNode = {}, {}, {}, {}, {}

    for _, node in ipairs(tree.nodes) do
        maxRankOf[node.id] = #(node.spells or {})
        costsOf[node.id] = node.soulPointsCosts or {}
        if node.isStart then isStartNode[node.id] = true end
    end

    for _, link in ipairs(tree.links) do
        local parentId, childId = link[1], link[2]

        local parents = parentsOf[childId]
        if not parents then
            parents = {}
            parentsOf[childId] = parents
        end
        parents[#parents + 1] = parentId

        local kids = childrenOf[parentId]
        if not kids then
            kids = {}
            childrenOf[parentId] = kids
        end
        kids[#kids + 1] = childId
    end

    return true
end

local function RankCost(nodeId, fromRank, toRank)
    local costs = costsOf[nodeId]
    if not costs then return 0 end

    local total = 0
    for rank = fromRank + 1, toRank do
        total = total + (costs[rank] or 0)
    end
    return total
end

function Plan.ComputeMissing(targets, snapshot)
    local missing, count = {}, 0
    snapshot = snapshot or EMPTY

    for nodeId, targetRank in pairs(targets or EMPTY) do
        if (snapshot[nodeId] or 0) < targetRank then
            missing[nodeId] = targetRank
            count = count + 1
        end
    end

    return missing, count
end

local function PushLinked(linked, set, seen, stack)
    for i = 1, (linked and #linked or 0) do
        local nodeId = linked[i]
        if set[nodeId] and not seen[nodeId] then
            seen[nodeId] = true
            stack[#stack + 1] = nodeId
        end
    end
end

function Plan.LargestGroup(set)
    if not BuildGraph() then return set end

    local seen, best, bestSize = {}, set, 0
    for startId in pairs(set) do
        if not seen[startId] then
            seen[startId] = true
            local group, size, stack = {}, 0, { startId }

            while #stack > 0 do
                local nodeId = stack[#stack]
                stack[#stack] = nil
                group[nodeId] = set[nodeId]
                size = size + 1
                PushLinked(parentsOf[nodeId], set, seen, stack)
                PushLinked(childrenOf[nodeId], set, seen, stack)
            end

            if size > bestSize then best, bestSize = group, size end
        end
    end

    return best
end

function Plan.ComputeProgress(targets, snapshot)
    if not BuildGraph() then return nil end

    snapshot = snapshot or EMPTY
    local ownedCost, totalCost, ownedNodes, totalNodes = 0, 0, 0, 0

    for nodeId, targetRank in pairs(targets or EMPTY) do
        if maxRankOf[nodeId] then
            local costs = costsOf[nodeId]
            local currentRank = snapshot[nodeId] or 0
            if currentRank > targetRank then currentRank = targetRank end

            for rank = 1, targetRank do
                local cost = costs[rank] or 0
                totalCost = totalCost + cost
                if rank <= currentRank then ownedCost = ownedCost + cost end
            end

            totalNodes = totalNodes + 1
            if currentRank >= targetRank then ownedNodes = ownedNodes + 1 end
        end
    end

    return ownedCost, totalCost, ownedNodes, totalNodes
end

local function HeapPush(costs, ids, size, cost, id)
    size = size + 1

    local i = size
    while i > 1 do
        local up = math.floor(i / 2)
        local upCost, upId = costs[up], ids[up]
        if upCost < cost or (upCost == cost and upId < id) then break end
        costs[i], ids[i] = upCost, upId
        i = up
    end

    costs[i], ids[i] = cost, id
    return size
end

local function HeapPop(costs, ids, size)
    local topCost, topId = costs[1], ids[1]
    local holdCost, holdId = costs[size], ids[size]

    costs[size], ids[size] = nil, nil
    size = size - 1

    if size > 0 then
        local i = 1
        while true do
            local down = i * 2
            if down > size then break end

            local right = down + 1
            if right <= size then
                local leftCost, leftId = costs[down], ids[down]
                local rightCost, rightId = costs[right], ids[right]
                if rightCost < leftCost or (rightCost == leftCost and rightId < leftId) then
                    down = right
                end
            end

            local downCost, downId = costs[down], ids[down]
            if holdCost < downCost or (holdCost == downCost and holdId < downId) then break end
            costs[i], ids[i] = downCost, downId
            i = down
        end
        costs[i], ids[i] = holdCost, holdId
    end

    return topCost, topId, size
end

local wipe = wipe or function(t) for k in pairs(t) do t[k] = nil end end

local goals, waiting = {}, {}
local heapCosts, heapIds = {}, {}

local function ClassifyNode(nodeId, snapshot)
    if isStartNode[nodeId] then return true end

    local parents = parentsOf[nodeId]
    if not parents then return false end

    local unmet = 0
    for i = 1, #parents do
        local parentId = parents[i]
        local parentMax = maxRankOf[parentId] or 0

        if parentMax == 0 then return false end

        if (snapshot[parentId] or 0) < parentMax then
            if goals[parentId] ~= parentMax then return false end
            unmet = unmet + 1
        end
    end

    if unmet == 0 then return true end

    waiting[nodeId] = unmet
    return false
end

function Plan.ComputeProgressive(targets, snapshot, budget)
    if not BuildGraph() then return nil end

    snapshot = snapshot or EMPTY
    wipe(goals)
    wipe(waiting)
    wipe(heapCosts)
    wipe(heapIds)

    for nodeId, targetRank in pairs(targets or EMPTY) do
        local maxRank = maxRankOf[nodeId]
        if maxRank then
            local goal = (targetRank > maxRank) and maxRank or targetRank
            if (snapshot[nodeId] or 0) < goal then goals[nodeId] = goal end
        end
    end

    local heapSize = 0

    for nodeId in pairs(goals) do
        if ClassifyNode(nodeId, snapshot) then
            local rank = snapshot[nodeId] or 0
            heapSize = HeapPush(heapCosts, heapIds, heapSize,
                RankCost(nodeId, rank, rank + 1), nodeId)
        end
    end

    local chosen, chosenCount, spent = {}, 0, 0
    local remaining = budget or 0
    local blockedCost

    while heapSize > 0 do
        local cost, nodeId
        cost, nodeId, heapSize = HeapPop(heapCosts, heapIds, heapSize)

        if cost > remaining then
            blockedCost = cost
            break
        end

        local newRank = (chosen[nodeId] or snapshot[nodeId] or 0) + 1
        if not chosen[nodeId] then chosenCount = chosenCount + 1 end
        chosen[nodeId] = newRank
        remaining = remaining - cost
        spent = spent + cost

        if newRank < goals[nodeId] then
            heapSize = HeapPush(heapCosts, heapIds, heapSize,
                RankCost(nodeId, newRank, newRank + 1), nodeId)
        end

        if newRank >= (maxRankOf[nodeId] or 0) then
            local kids = childrenOf[nodeId]
            for i = 1, (kids and #kids or 0) do
                local childId = kids[i]
                local unmet = waiting[childId]
                if unmet then
                    unmet = unmet - 1
                    if unmet > 0 then
                        waiting[childId] = unmet
                    else
                        waiting[childId] = nil
                        local rank = chosen[childId] or snapshot[childId] or 0
                        heapSize = HeapPush(heapCosts, heapIds, heapSize,
                            RankCost(childId, rank, rank + 1), childId)
                    end
                end
            end
        end
    end

    return chosen, spent, chosenCount, blockedCost
end
