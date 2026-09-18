--!nonstrict
-- Küçük arayüz yapı taşları. Paneller bunların üstünde kısa kalıyor.
local Theme = require(script.Parent.Theme)

local Widgets = {}

function Widgets.create(className: string, props: { [string]: any }, children: { Instance }?): Instance
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

local create = Widgets.create

function Widgets.corner(radius: number?): UICorner
	return create("UICorner", { CornerRadius = UDim.new(0, radius or Theme.corner) })
end

function Widgets.stroke(color: Color3?, thickness: number?): UIStroke
	return create("UIStroke", {
		Color = color or Theme.color.stroke,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Widgets.padding(amount: number?): UIPadding
	local value = UDim.new(0, amount or Theme.padding)
	return create("UIPadding", {
		PaddingTop = value,
		PaddingBottom = value,
		PaddingLeft = value,
		PaddingRight = value,
	})
end

function Widgets.list(direction: Enum.FillDirection?, gap: number?): UIListLayout
	return create("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})
end

function Widgets.frame(props: { [string]: any }, children: { Instance }?): Frame
	local merged = {
		BackgroundColor3 = Theme.color.panel,
		BorderSizePixel = 0,
	}
	for key, value in props do
		merged[key] = value
	end
	return create("Frame", merged, children) :: Frame
end

function Widgets.text(props: { [string]: any }): TextLabel
	local merged = {
		BackgroundTransparency = 1,
		Font = Theme.font.body,
		TextColor3 = Theme.color.text,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
	}
	for key, value in props do
		merged[key] = value
	end
	return create("TextLabel", merged) :: TextLabel
end

function Widgets.button(props: { [string]: any }, onClick: (() -> ())?): TextButton
	local merged = {
		BackgroundColor3 = Theme.color.accent,
		BorderSizePixel = 0,
		Font = Theme.font.title,
		TextColor3 = Theme.color.text,
		TextSize = 15,
		AutoButtonColor = true,
	}
	for key, value in props do
		merged[key] = value
	end
	local button = create("TextButton", merged, { Widgets.corner(8) }) :: TextButton
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

function Widgets.scroller(props: { [string]: any }): ScrollingFrame
	local merged = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.color.stroke,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}
	for key, value in props do
		merged[key] = value
	end
	return create("ScrollingFrame", merged) :: ScrollingFrame
end

-- Başlıklı, kapatılabilir panel. Dönen tabloda içerik alanı ve aç/kapa var.
export type Panel = {
	root: Frame,
	content: ScrollingFrame,
	setOpen: (boolean) -> (),
	isOpen: () -> boolean,
	toggle: () -> (),
}

function Widgets.panel(parent: Instance, title: string, size: UDim2): Panel
	local root = Widgets.frame({
		Name = title,
		Size = size,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		Parent = parent,
		ZIndex = 5,
	}, { Widgets.corner(14), Widgets.stroke() })

	local header = Widgets.frame({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Theme.color.panelAlt,
		Parent = root,
		ZIndex = 6,
	}, { Widgets.corner(14) })

	Widgets.text({
		Text = title,
		Font = Theme.font.title,
		TextSize = 19,
		Size = UDim2.new(1, -60, 1, 0),
		Position = UDim2.fromOffset(16, 0),
		Parent = header,
		ZIndex = 6,
	})

	local content = Widgets.scroller({
		Name = "Content",
		Size = UDim2.new(1, -20, 1, -60),
		Position = UDim2.fromOffset(10, 52),
		Parent = root,
		ZIndex = 6,
	})
	Widgets.list(Enum.FillDirection.Vertical, 8).Parent = content

	local panel = {} :: Panel

	function panel.isOpen()
		return root.Visible
	end

	function panel.setOpen(open: boolean)
		root.Visible = open
	end

	function panel.toggle()
		root.Visible = not root.Visible
	end

	Widgets.button({
		Text = "✕",
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.new(1, -40, 0, 6),
		BackgroundColor3 = Theme.color.panel,
		Parent = header,
		ZIndex = 7,
	}, function()
		panel.setOpen(false)
	end)

	panel.root = root
	panel.content = content
	return panel
end

-- Satır: solda başlık/alt başlık, sağda buton.
function Widgets.row(parent: Instance, title: string, subtitle: string, buttonText: string?, onClick: (() -> ())?)
	local row = Widgets.frame({
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = Theme.color.panelAlt,
		Parent = parent,
		ZIndex = 6,
	}, { Widgets.corner(8) })

	local titleLabel = Widgets.text({
		Text = title,
		Font = Theme.font.title,
		TextSize = 16,
		Size = UDim2.new(1, -130, 0, 22),
		Position = UDim2.fromOffset(12, 8),
		Parent = row,
		ZIndex = 7,
	})

	local subtitleLabel = Widgets.text({
		Text = subtitle,
		TextColor3 = Theme.color.textDim,
		TextSize = 13,
		Size = UDim2.new(1, -130, 0, 18),
		Position = UDim2.fromOffset(12, 30),
		Parent = row,
		ZIndex = 7,
	})

	local button = nil
	if buttonText then
		button = Widgets.button({
			Text = buttonText,
			Size = UDim2.fromOffset(104, 34),
			Position = UDim2.new(1, -116, 0.5, -17),
			Parent = row,
			ZIndex = 7,
		}, onClick)
	end

	return { root = row, title = titleLabel, subtitle = subtitleLabel, button = button }
end

function Widgets.bar(parent: Instance, color: Color3): (Frame, (number) -> ())
	local track = Widgets.frame({
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundColor3 = Theme.color.panelAlt,
		Parent = parent,
		ZIndex = 6,
	}, { Widgets.corner(7) })

	local fill = Widgets.frame({
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color,
		Parent = track,
		ZIndex = 7,
	}, { Widgets.corner(7) })

	return track, function(alpha: number)
		fill.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
	end
end

return Widgets
