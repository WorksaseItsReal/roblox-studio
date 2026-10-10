--[[
	UIKit
	=====
	Petits constructeurs d'interface pour garder les panneaux lisibles.
	Toute l'UI est créée par code : rien à construire à la main dans Studio.
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local UIKit = {}

-- Crée une instance avec ses propriétés et ses enfants
function UIKit.New(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			(instance :: any)[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UIKit.Corner(parent: Instance, radius: UDim?)
	return UIKit.New("UICorner", { CornerRadius = radius or Theme.Corner, Parent = parent })
end

function UIKit.Stroke(parent: Instance, color: Color3?, thickness: number?)
	return UIKit.New("UIStroke", {
		Color = color or Theme.Stroke,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function UIKit.Padding(parent: Instance, px: number)
	local pad = UDim.new(0, px)
	return UIKit.New("UIPadding", {
		PaddingTop = pad,
		PaddingBottom = pad,
		PaddingLeft = pad,
		PaddingRight = pad,
		Parent = parent,
	})
end

function UIKit.List(
	parent: Instance,
	direction: Enum.FillDirection?,
	padding: number?,
	align: Enum.HorizontalAlignment?
)
	return UIKit.New("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 6),
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function UIKit.Label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextColor3 = Theme.Text,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 24),
	}
	for key, value in props do
		defaults[key] = value
	end
	return UIKit.New("TextLabel", defaults)
end

-- Bouton avec petit effet de survol / clic
function UIKit.Button(text: string, color: Color3, onClick: () -> (), props: { [string]: any }?): TextButton
	local button = UIKit.New("TextButton", {
		Text = text,
		Font = Theme.Font,
		TextSize = 18,
		TextColor3 = Theme.Text,
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Size = UDim2.new(0, 120, 0, 36),
	})
	for key, value in pairs(props or {}) do
		(button :: any)[key] = value
	end
	UIKit.Corner(button, UDim.new(0, 10))
	local scale = UIKit.New("UIScale", { Parent = button })

	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.05 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	button.Activated:Connect(function()
		if not button.Active then
			return
		end
		scale.Scale = 0.95
		TweenService:Create(scale, TweenInfo.new(0.15), { Scale = 1 }):Play()
		onClick()
	end)
	return button
end

function UIKit.SetButtonEnabled(button: TextButton, enabled: boolean, color: Color3)
	button.Active = enabled
	button.AutoButtonColor = false
	button.BackgroundColor3 = if enabled then color else Theme.Disabled
	button.TextColor3 = if enabled then Theme.Text else Theme.TextDim
end

-- Liste défilante dont la taille du contenu s'ajuste automatiquement
function UIKit.ScrollList(parent: Instance, props: { [string]: any }?): ScrollingFrame
	local scroll = UIKit.New("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Stroke,
		Parent = parent,
	})
	for key, value in pairs(props or {}) do
		(scroll :: any)[key] = value
	end
	UIKit.List(scroll, Enum.FillDirection.Vertical, 8)
	UIKit.New("UIPadding", { PaddingRight = UDim.new(0, 10), Parent = scroll })
	return scroll
end

-- Ligne de carte (fond arrondi) utilisée dans les listes
function UIKit.Card(height: number, order: number?): Frame
	local card = UIKit.New("Frame", {
		BackgroundColor3 = Theme.SurfaceLight,
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = order or 0,
	})
	UIKit.Corner(card, UDim.new(0, 10))
	UIKit.Padding(card, 8)
	return card
end

function UIKit.ClearChildren(parent: Instance, keepClass: { string }?)
	for _, child in parent:GetChildren() do
		if not (keepClass and table.find(keepClass, child.ClassName)) then
			child:Destroy()
		end
	end
end

return UIKit
