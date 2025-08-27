local PlantMutationData = {
	["PlantsMutation"] = {
		["CarrotGold"] = {
			Path = "PlantsMutation/Carrot/CarrotGold",
			Name = "CarrotGold",
			ImageId = "rbxassetid://83482609250148",
			SellingPrice = 250, 
			Category = "PlantsMutation",
			Rarity = 'Gold',
			Stackable = true,
			Description = "Golden Carrot - Uma cenoura mutante brilhante e valiosa",
			Placeable = true,
			CanPlaceInPlot = true,
		},
		["PotatoGold"] = {
			Path = "PlantsMutation/Potato/PotatoGold",
			Name = "PotatoGold", 
			SellingPrice = 875, 
			ImageId = "rbxassetid://123823664883067",
			Category = "PlantsMutation",
			Rarity = 'Gold',
			Stackable = true,
			Description = "Golden Potato - Uma batata mutante dourada e nutritiva",
			Placeable = true,
			CanPlaceInPlot = true,
		},
		["BambooGold"] = {
			Path = "PlantsMutation/Bamboo/BambooGold",
			Name = "BambooGold",
			ImageId = "rbxassetid://109444455163624",
			SellingPrice = 1750,
			Category = "PlantsMutation",
			Rarity = 'Gold',
			Stackable = true,
			Description = "Golden Bamboo - Bambu mutante com propriedades mágicas",
			Placeable = true,
			CanPlaceInPlot = true,
		},
		["WheatGold"] = {
			Path = "PlantsMutation/Wheat/WheatGold",
			Name = "WheatGold",
			ImageId = "rbxassetid://136284174128774",
			SellingPrice = 3750, 
			Category = "PlantsMutation", 
			Rarity = 'Gold',
			Stackable = true,
			Description = "Golden Wheat - Trigo mutante dourado de alto valor",
			Placeable = true,
			CanPlaceInPlot = true,
		},
		["CornGold"] = {
			Path = "PlantsMutation/Corn/CornGold",
			Name = "CornGold",
			ImageId = "rbxassetid://115268960454910",
			SellingPrice = 9000,
			Category = "PlantsMutation",
			Rarity = 'Gold',
			Stackable = true,
			Description = "Golden Corn - Milho mutante com grãos dourados",
			Placeable = true,
			CanPlaceInPlot = true,
		},
		["TomatoGold"] = {
			Path = "PlantsMutation/Tomato/TomatoGold",
			Name = "TomatoGold",
			ImageId = "rbxassetid://93931673409385",
			SellingPrice = 6750, 
			Category = "PlantsMutation",
			Rarity = 'Gold',
			Stackable = true,
			Description = "Golden Tomato - Tomate mutante dourado com sabor intenso", 
			Placeable = true,
			CanPlaceInPlot = true,
		},
		["WaterMelonGold"] = {
			Path = "PlantsMutation/WaterMelon/WaterMelonGold",
			Name = "WaterMelonGold",
			ImageId = "rbxassetid://112665356818913",
			SellingPrice = 13750, 
			Category = "PlantsMutation",
			Rarity = 'Gold',
			Stackable = true,
			Description = "Golden WaterMelon - Melancia mutante dourada gigante",
			Placeable = true,
			CanPlaceInPlot = true,
		},
		["PineappleGold"] = {
			Path = "PlantsMutation/Pineapple/PineappleGold",
			Name = "PineappleGold",
			ImageId = "rbxassetid://121396220704075",
			SellingPrice = 16750, 
			Category = "PlantsMutation",
			Rarity = 'Gold',
			Stackable = true,
			Description = "Golden Pineapple - Abacaxi mutante dourado premium",
			Placeable = true,
			CanPlaceInPlot = true,
		},
	}
}



-- Função para obter uma mutação específica
function PlantMutationData:GetMutation(mutationName)
	if not mutationName then 
		warn("❌ GetMutation: nome da mutação é nil")
		return
	end
	return PlantMutationData["PlantsMutation"][mutationName]
end
-- Função para obter todas as mutações
function PlantMutationData:GetAllMutations()
	return PlantMutationData["PlantsMutation"]
end

function PlantMutationData:HasMutation(plantName)
	local ItemData = require(game:GetService("ServerScriptService").Data.ItemData)
	if not plantName then return false end
	local originalPlantData = ItemData:GetItem("Plants", plantName)
	if originalPlantData and originalPlantData.PossibleMutations and next(originalPlantData.PossibleMutations) then
		return true
	end
	return false
end

-- Função para obter o modelo da mutação
function PlantMutationData:FindMutationModel(mutationName) 
	local mutation = self:GetMutation(mutationName) 
	if not mutation then return nil end

	local pathTable = string.split(mutation.Path, "/")
	local ItemModels = game.ServerStorage.ItemModels

	local itemModel = nil
	local lastPath = ItemModels:FindFirstChild(pathTable[1])

	for index, pathObj in ipairs(pathTable) do
		if index == 1 then continue end
		if lastPath then
			if index == #pathTable then
				itemModel = lastPath:FindFirstChild(pathObj)
			elseif lastPath:FindFirstChild(pathObj) then
				lastPath = lastPath:FindFirstChild(pathObj)
			end			
		end		
	end

	return itemModel
end


return PlantMutationData