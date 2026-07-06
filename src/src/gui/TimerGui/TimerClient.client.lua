local updateTimer = game.ReplicatedStorage:WaitForChild("UpdateTimer")
local roundResult = game.ReplicatedStorage:WaitForChild("RoundResult")
local gui = script.Parent
local label = gui:WaitForChild("Frame"):WaitForChild("TimerLabel")
local sublabel = gui:WaitForChild("Frame"):WaitForChild("SubLabel")

-- Results label (hidden by default)
local resultsLabel = Instance.new("TextLabel")
resultsLabel.Size = UDim2.new(0, 400, 0, 100)
resultsLabel.Position = UDim2.new(0.5, -200, 0.5, -50)
resultsLabel.BackgroundTransparency = 1
resultsLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
resultsLabel.TextScaled = true
resultsLabel.Font = Enum.Font.GothamBold
resultsLabel.Text = ""
resultsLabel.Parent = gui

roundResult.OnClientEvent:Connect(function(message)
	resultsLabel.Text = message
	task.wait(5)
	resultsLabel.Text = ""
end)

updateTimer.OnClientEvent:Connect(function(phase, timeLeft)
	if phase == "HIDE" then
		local mins = math.floor(timeLeft / 60)
		local secs = timeLeft % 60
		label.Text = string.format("HIDE: %d:%02d", mins, secs)
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		if timeLeft == 0 then
			sublabel.Text = "HE IS HERE!"
			sublabel.TextColor3 = Color3.fromRGB(255, 0, 0)
		elseif timeLeft <= math.ceil(timeLeft / 2) then
			sublabel.Text = "He is approaching..."
		else
			sublabel.Text = "Find somewhere to hide!"
		end
	elseif phase == "HUNT" then
		local mins = math.floor(timeLeft / 60)
		local secs = timeLeft % 60
		label.Text = string.format("SURVIVE: %d:%02d", mins, secs)
		label.TextColor3 = Color3.fromRGB(255, 80, 80)
		sublabel.Text = "NoLander is hunting..."
	elseif phase == "END" then
		label.Text = "ROUND OVER"
		label.TextColor3 = Color3.fromRGB(255, 255, 0)
		sublabel.Text = ""
	end
end)
