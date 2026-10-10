--[[
	PathMath
	========
	Évaluation d'une polyligne : position et direction à une distance donnée.

	Utilisé par :
	- le SERVEUR pour connaître la position exacte d'une créature sur le chemin
	  (vérification de distance lors d'un achat) ;
	- le CLIENT pour animer localement les créatures (mouvement fluide, zéro
	  réplication réseau par frame).
	Les deux utilisent la même formule déterministe :
	  distance = StartDistance + (tempsServeur - StartTime) * Speed

	Les points sont stockés en attributs Vector3 sur une instance :
	  Count = n, WP1 ... WPn   (chemin principal, Workspace.Map.PathData)
	  PointCount = n, P1 ... Pn (trajets courts : créature qui rejoint une base)
]]

export type Path = {
	Points: { Vector3 },
	Cumulative: { number }, -- distance cumulée au point i
	Length: number,
}

local PathMath = {}

function PathMath.Build(points: { Vector3 }): Path
	assert(#points >= 2, "Un chemin doit contenir au moins 2 points")
	local cumulative = { 0 }
	local total = 0
	for i = 2, #points do
		total += (points[i] - points[i - 1]).Magnitude
		cumulative[i] = total
	end
	return {
		Points = points,
		Cumulative = cumulative,
		Length = total,
	}
end

-- Renvoie la position et la direction (unitaire) à "distance" studs du début
function PathMath.Evaluate(path: Path, distance: number): (Vector3, Vector3)
	local points = path.Points
	local cumulative = path.Cumulative

	if distance <= 0 then
		local dir = points[2] - points[1]
		return points[1], if dir.Magnitude > 0 then dir.Unit else Vector3.zAxis
	end
	if distance >= path.Length then
		local n = #points
		local dir = points[n] - points[n - 1]
		return points[n], if dir.Magnitude > 0 then dir.Unit else Vector3.zAxis
	end

	-- Recherche dichotomique du segment [i, i+1] contenant la distance
	local low, high = 1, #points - 1
	while low < high do
		local mid = (low + high + 1) // 2
		if cumulative[mid] <= distance then
			low = mid
		else
			high = mid - 1
		end
	end

	local a, b = points[low], points[low + 1]
	local segmentLength = cumulative[low + 1] - cumulative[low]
	local alpha = if segmentLength > 0 then (distance - cumulative[low]) / segmentLength else 0
	local direction = b - a
	return a:Lerp(b, alpha), if direction.Magnitude > 0 then direction.Unit else Vector3.zAxis
end

-- Lecture du chemin principal (attributs Count / WP1..WPn)
function PathMath.ReadMainPath(holder: Instance): Path?
	local count = holder:GetAttribute("Count")
	if type(count) ~= "number" or count < 2 then
		return nil
	end
	local points = {}
	for i = 1, count do
		local point = holder:GetAttribute("WP" .. i)
		if typeof(point) ~= "Vector3" then
			return nil
		end
		points[i] = point
	end
	return PathMath.Build(points)
end

function PathMath.WriteMainPath(holder: Instance, points: { Vector3 })
	holder:SetAttribute("Count", #points)
	for i, point in points do
		holder:SetAttribute("WP" .. i, point)
	end
end

-- Trajets courts (attributs PointCount / P1..Pn), utilisés par les "walkers"
function PathMath.ReadInlinePath(holder: Instance): Path?
	local count = holder:GetAttribute("PointCount")
	if type(count) ~= "number" or count < 2 then
		return nil
	end
	local points = {}
	for i = 1, count do
		local point = holder:GetAttribute("P" .. i)
		if typeof(point) ~= "Vector3" then
			return nil
		end
		points[i] = point
	end
	return PathMath.Build(points)
end

function PathMath.WriteInlinePath(holder: Instance, points: { Vector3 })
	holder:SetAttribute("PointCount", #points)
	for i, point in points do
		holder:SetAttribute("P" .. i, point)
	end
end

return PathMath
