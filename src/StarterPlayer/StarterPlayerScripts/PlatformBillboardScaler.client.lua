-- PlatformBillboardScaler.client.lua
-- Keeps PlatformBillboard BillboardGuis at a truly fixed screen pixel size
-- by using the camera's projection math to compute the exact stud size needed.

local RunService = game:GetService("RunService")
local camera = workspace.CurrentCamera

-- Desired size on screen in pixels — change these to resize
local TARGET_W = 120
local TARGET_H = 38

-- Cache billboards on load
local billboards = {}
task.wait(3)
for _, obj in pairs(workspace:GetDescendants()) do
	if obj:IsA("BillboardGui") and obj.Name == "PlatformBillboard" then
		table.insert(billboards, obj)
	end
end

RunService.RenderStepped:Connect(function()
	local viewportSize = camera.ViewportSize
	-- Focal length in pixels derived from vertical FOV
	local focalLength = (viewportSize.Y * 0.5) / math.tan(math.rad(camera.FieldOfView * 0.5))

	for _, billboard in ipairs(billboards) do
		local adornee = billboard.Adornee
		if adornee and adornee:IsA("BasePart") then
			-- WorldToScreenPoint returns depth along the camera's look direction,
			-- which correctly accounts for both distance and viewing angle.
			local billboardWorldPos = adornee.Position + Vector3.new(0, billboard.StudsOffset.Y, 0)
			local _, _, depth = camera:WorldToScreenPoint(billboardWorldPos)
			depth = math.max(0.1, depth)

			-- Invert the projection: studs = pixels * depth / focalLength
			billboard.Size = UDim2.new(0, TARGET_W * depth / focalLength, 0, TARGET_H * depth / focalLength)
		end
	end
end)
