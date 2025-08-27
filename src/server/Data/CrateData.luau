local CrateData = {
	
	["MasterLuckyBlock"] = {
		DisplayName = "Shiny Crate",
		ItemName = "MasterLuckyBlock", 
		ItemCategory = "Crates",
		--Price = 500, 
		PointsNeed = 100,
		LootTable = {
			{ Category = "Crates", Name = "LuckyBlock", Weight = 75 }, 
			{ Category = "Crates", Name = "LuckyBlockDecorations", Weight = 24 },
			{ Category = "Crates", Name = "LuckyBlockSecret", Weight = 1 }, 
			},
		IsMasterCrate = true,
	},

	--["MasterEggLuckyBlock"] = {
	--	DisplayName = "EggLuckyBlock",
	--	ItemName = "MasterEggLuckyBlock", 
	--	ItemCategory = "Crates",
	--	--Price = 500, 
	--	PointsNeed = 100,
	--	LootTable = {
	--		{ Category = "Eggs", Name = "BasicPetEgg", Weight = 50 }, 
	--		{ Category = "Eggs", Name = "RarePetEgg", Weight = 49 },
	--		{ Category = "Eggs", Name = "EpicPetEgg", Weight = 1 }, 
	--	},
	--	IsMasterCrate = true,
	--},
	["LuckyBlock"] = {
		DisplayName = "Lucky Block",
		ItemName = "LuckyBlock", 
		ItemCategory = "Crates",
		LootTable = {
			{ Category = "Seeds", Name = "CarrotSeed", Weight = 35 },
			{ Category = "Decoration", Name = "Fence", Weight = 30 }, 
			{ Category = "Farming", Name = "BasicPlot", Weight = 15 }, 
			{ Category = "Seeds", Name = "WaterMelonSeed", Weight = 10 },
			{ Category = "Decoration", Name = "Gnomo", Weight =6 },
			{ Category = "Decoration", Name = "Arch", Weight = 3 },
			{ Category = "Eggs", Name = "BasicPetEgg", Weight = 1 },
		}
	},

	["LuckyBlockDecorations"] = {
		DisplayName = "Decorations Crate",
		ItemName = "LuckyBlockDecorations", 
		ItemCategory = "Crates",
		LootTable = {
			{ Category = "Decoration", Name = "Flower", Weight = 28 },
			{ Category = "Decoration", Name = "Rock", Weight = 23 },
			{ Category = "Decoration", Name = "Mushroom", Weight = 17 },
			{ Category = "Decoration", Name = "Bench", Weight = 13 },
			{ Category = "Decoration", Name = "Well", Weight = 10 },
			{ Category = "Decoration", Name = "Gnomo", Weight = 5 },
			{ Category = "Decoration", Name = "Lighter", Weight = 2.5 },
			{ Category = "Decoration", Name = "MegaTree", Weight = 1 },
			{ Category = "Decoration", Name = "EspecialTower", Weight = 0.5 },
		}
	},
	["LuckyBlockSecret"] = {
		DisplayName = "Caixa Secreta",
		ItemName = "LuckyBlockSecret", 
		ItemCategory = "Crates",
		LootTable = {
			{ Category = "Seeds", Name = "TomatoSeed", Weight = 25 },
			{ Category = "Seeds", Name = "CornSeed", Weight = 20 },
			{ Category = "Seeds", Name = "WaterMelonSeed", Weight = 15 },
			{ Category = "Seeds", Name = "PineappleSeed", Weight = 12 },
			{ Category = "Decoration", Name = "Fountain", Weight = 10 },
			{ Category = "Farming", Name = "PremiumPlot", Weight = 5 },
			{ Category = "Decoration", Name = "EspecialTower", Weight = 4 },
			{ Category = "Decoration", Name = "MegaTree", Weight = 3 },
			{ Category = "Decoration", Name = "LotFus", Weight = 1 },
		}
	},
	
}	
return CrateData