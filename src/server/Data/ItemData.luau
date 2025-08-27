local ItemData = {
	["Eggs"] = {
		["BasicPetEgg"] = {
			IsOnShop = true,
			Name = "BasicPetEgg",
			ImageId = "rbxassetid://113319130674402", 
			Price = 50000,
			ShopAppearanceChance = 0.50, -- 50% de chance de aparecer a cada restock
			Category = "Eggs",
			Rarity = 'Epic',
			Stackable = true,
			Description = "Um ovo misterioso que parece quente ao toque. Deixe-o em seu planeta e espere para ver o que nasce!",

			--integração com FarmingService 
			Stages = {
				{
					Name = "Placed", 
					Duration = {10, 20}, 
					ModelPath = "Eggs/BasicPetEgg" 
				},
				{
					Name = "Hatchable", -- Estágio final, pronto para "colher" 
					Duration = 0,
					ModelPath = "Eggs/BasicPetEgg_Hatchable" -- Modelo com rachaduras/brilho
				}
			},

			LootTable = "BasicPetEggLoot", -- Nome da tabela de loot 

			-- Propriedades de planta 
			HarvestCratePoints = 0,
			HarvestValue = 0, 
			Experience = 50, 
			LevelRequired = 1,
			PlotTypes = {"BasicPlot", "LargePlot", "PremiumPlot"}, -- no se aplica
			Placeable = true,
		},
		
		["RarePetEgg"] = {
			IsOnShop = true, 
			Price = 250000,
			ShopAppearanceChance = 0.35, -- 35% de chance 
			Name = "RarePetEgg",
			ImageId = "rbxassetid://78382210989189",
			Category = "Eggs",
			Rarity = 'Legendary',
			Stackable = true,
			Description = "Um ovo raro e brilhante. O que será que vai nascer daqui?",
			Stages = {
				{ Name = "Placed", Duration = {30, 40}, ModelPath = "Eggs/RarePetEgg" },
				{ Name = "Hatchable", Duration = 0, ModelPath = "Eggs/RarePetEgg_Hatchable" } 
			},
			LootTable = "RarePetEggLoot",
			Experience = 250,
			LevelRequired = 1,
			PlotTypes = {"BasicPlot", "LargePlot", "PremiumPlot"},
			Placeable = true,
		},
		["EpicPetEgg"] = {
			IsOnShop = true, 
			Price = 1000000,
			ShopAppearanceChance = 0.15, --15% de chance 

			Name = "EpicPetEgg",
			ImageId = "rbxassetid://113361268471790",
			Category = "Eggs",
			Rarity = 'Limited',
			Stackable = true,
			Description = "Um ovo raro e brilhante. O que será que vai nascer daqui?",
			Stages = {
				{ Name = "Placed", Duration = {60, 70}, ModelPath = "Eggs/EpicPetEgg" },
				{ Name = "Hatchable", Duration = 0, ModelPath = "Eggs/EpicPetEgg_Hatchable" } 
			},
			LootTable = "EpicPetEggLoot",
			Experience = 250,
			LevelRequired = 1,
			PlotTypes = {"BasicPlot", "LargePlot", "PremiumPlot"},
			Placeable = true,
		},
	},
	["Seeds"] = {
		["CarrotSeed"] = {
			IsOnShop = true,
			Plant = "CarrotMature",
			OutOfStockChance = 0, 
			StockRange = {8, 10}, 
			Name = "CarrotSeed",
			--ImageId = "rbxassetid://93874257120696",
			ImageId = "rbxassetid://132199514117021",
			Price = 10,
			Category = "Seeds",
			Rarity = 'Common',
			Stackable = true,
        
			Description = "Uma semente mágica que cresce sob a luz da lua. Produz flores gigantes que brilham com uma aura dourada. Muito valorizada por alquimistas.",

			Stages = {
				{
					Name = "Seed", 
					Duration = {5,6}, 
					ModelPath = "Seeds/CarrotSeed"
				},
				{
					Name = "Sprout", 
					Duration = {5,6}, 
					ModelPath = "Plants/Carrot/CarrotSprout"
				},
				{
					Name = "Mature", 
					Duration = 0,
					ModelPath = "Plants/Carrot/CarrotMature"
				}
			},
			HarvestCratePoints = 1,
			HarvestValue = 3, 
			Experience = 250,
			LevelRequired = 1,
			PlotTypes = {"BasicPlot", "LargePlot", "PremiumPlot"},
			WitheringTime = 300,
			Placeable = true,
		},
		
		["PotatoSeed"] = {
			IsOnShop = true,
			Plant = "PotatoMature",
			OutOfStockChance = 0.1, 
			StockRange = {6,10}, 
			Name = "PotatoSeed",
			--ImageId = "rbxassetid://87277492140936", --Mature
			ImageId = "rbxassetid://117760289173007",
			Price = 75,
			Category = "Seeds",
			Rarity = 'Common',
			Stackable = true,

			Description = "Um tubérculo robusto que cresce escondido sob a terra.Versátil e nutritiva, a batata pode ser cozida, frita ou vendida.",

			Stages = {
				{
					Name = "Seed", 
					Duration = {5, 12}, 
					ModelPath = "Seeds/PotatoSeed"
				},
				{
					Name = "Sprout", 
					Duration = {5, 12}, 
					ModelPath = "Plants/Potato/PotatoSprout"
				},
				{
					Name = "Young", 
					Duration = {5, 12}, 
					ModelPath = "Plants/Potato/PotatoYoung"
				},
				{
					Name = "Mature", 
					Duration = 0,
					ModelPath = "Plants/Potato/PotatoMature"
				}
			},
			
			HarvestCratePoints = 1,
			HarvestValue = 30,
			Experience = 350,
			LevelRequired = 1,
			PlotTypes = {"BasicPlot", "LargePlot", "PremiumPlot"},
			WitheringTime = 240,
			Placeable = true,
		},


		["BambooSeed"] = {
			IsOnShop = true,
			Plant = "BambooMature",
			OutOfStockChance = 0.1, -- 10% de nao vim e 90% de vim 
			StockRange = {5,8}, 
			Name = "BambooSeed",
			--ImageId = "rbxassetid://108630508750213", --Mature
			ImageId = "rbxassetid://103067349800677",
			Price = 450,
			Category = "Seeds",
			Rarity = 'Rare',
			Stackable = true,

			Description = "Bambu resistente e versátil. Material sustentável usado para construções, artesanatos e decoração oriental.",

			Stages = {
				{
					Name = "Seed", 
					Duration = {10,19}, 
					ModelPath = "Seeds/BambooSeed"
				},
				{
					Name = "Sprout", 
					Duration = {10,19}, 
					ModelPath = "Plants/Bamboo/BambooSprout"
				},
				{
					Name = "Mature", 
					Duration = 0,
					ModelPath = "Plants/Bamboo/BambooMature"
				}
			},

			HarvestCratePoints = 2,
			HarvestValue = 15, 
			Experience = 500,
			LevelRequired = 1,
			PlotTypes = {"BasicPlot", "LargePlot", "PremiumPlot"},
			WitheringTime = 300,
			Placeable = true,
		},

		
		["WheatSeed"] = {
			IsOnShop = true,
			Plant = "WheatMature",
			OutOfStockChance = 0.2, 
			StockRange = {4, 8}, 
			Name = "WheatSeed",
			--ImageId = "rbxassetid://122587532542918", --Mature
			ImageId = "rbxassetid://70605043252135",
			Price = 1500, 
			Category = "Seeds",
			Rarity = 'Rare',
			Stackable = true,

			Description = "Grãos dourados que ondulam com o vento.O trigo é a base para pães e rações. Essencial para quem quer expandir a fazenda",

			Stages = {
				{
					Name = "Seed", 
					Duration = {10, 16},
					ModelPath = "Seeds/WheatSeed"
				},
				{
					Name = "Sprout", 
					Duration = {15, 16}, 
					ModelPath = "Plants/Wheat/WheatSprout"
				},
				{
					Name = "Young", 
					Duration = {5, 16}, 
					ModelPath = "Plants/Wheat/WheatYoung"
				},
				{
					Name = "Mature", 
					Duration = 0,
					ModelPath = "Plants/Wheat/WheatMature"
				}
			},

			HarvestCratePoints = 2,
			HarvestValue = 20, 
			Experience = 1000,
			LevelRequired = 1,
			PlotTypes = {"LargePlot", "PremiumPlot"},
			WitheringTime = 180,
			Placeable = true,
		},		
		["CornSeed"] = {
			IsOnShop = true,
			Plant = "CornMature",
			OutOfStockChance = 0.4, 
			StockRange = {2, 4}, 
			Name = "CornSeed",
			--ImageId = "rbxassetid://110298121598825",
			ImageId = "rbxassetid://108575511622913",
			Price = 2100,
			Category = "Seeds",
			Rarity = 'Rare',
			Stackable = true,

			Description = "Cresce rápido ao sol. Ideal para receitas energéticas ou venda na feira. Símbolo de fartura e tradição rural.",

			Stages = {
				{
					Name = "Seed", 
					Duration = {40, 50},
					ModelPath = "Seeds/CornSeed"
				},
				{
					Name = "Sprout", 
					Duration = {20, 30}, 
					ModelPath = "Plants/Corn/CornSprout"
				},
				{
					Name = "Young", 
					Duration =  {10, 15},
					ModelPath = "Plants/Corn/CornYoung"
				},
				{
					Name = "Mature", 
					Duration = 0,
					ModelPath = "Plants/Corn/CornMature"
				}
			},
			HarvestCratePoints = 3,
			HarvestValue = 80,
			Experience = 2000,
			LevelRequired = 1,
			PlotTypes = {"BasicPlot", "LargePlot", "PremiumPlot"},
			WitheringTime = 600,
			Placeable = true,
		},
		["TomatoSeed"] = {
			IsOnShop = true,
			Plant = "TomatoMature",
			OutOfStockChance = 0.4, 
			StockRange = {2, 4}, 
			Name = "TomatoSeed",
			--ImageId = "rbxassetid://71757540337728",
			ImageId = "rbxassetid://136732003825411",
			Price = 3400,
			Category = "Seeds",
			Rarity = 'Rare',
			Stackable = true,

			Description = "Tomate vermelho e suculento, cheio de sabor. Ingrediente fundamental para molhos, saladas e conservas caseiras.",

			Stages = {
				{
					Name = "Seed", 
					Duration = {30, 43}, 
					ModelPath = "Seeds/TomatoSeed"
				},
				{
					Name = "Sprout", 
					Duration = {20, 43},
					ModelPath = "Plants/Tomato/TomatoSprout"
				},
				{
					Name = "Young", 
					Duration =  {40, 43},
					ModelPath = "Plants/Tomato/TomatoYoung"
				},
				{
					Name = "Mature", 
					Duration = 0,
					ModelPath = "Plants/Tomato/TomatoMature"
				}
			},
			HarvestCratePoints = 3,
			HarvestValue = 100, 
			Experience = 3000,
			LevelRequired = 1,
			PlotTypes = {"BasicPlot", "LargePlot", "PremiumPlot"},
			WitheringTime = 600,
			Placeable = true,
		},
		["WaterMelonSeed"] = {
			IsOnShop = true,
			Plant = "WaterMelonMature",
			OutOfStockChance = 0.5, 
			StockRange = {2, 4}, 
			Name = "WaterMelonSeed",
			--ImageId = "rbxassetid://97002373420005",
			ImageId = "rbxassetid://95674646960776",
			Price = 7500, 
			Category = "Seeds",
			Rarity = 'Epic',
			Stackable = true,

			Description = "Melancia gigante e refrescante com polpa vermelha. Fruta perfeita para dias quentes, rica em água e vitaminas",

			Stages = {
				{
					Name = "Seed", 
					Duration = {40, 60}, 
					ModelPath = "Seeds/WaterMelonSeed"
				},
				{
					Name = "Sprout", 
					Duration = {50, 60}, 
					ModelPath = "Plants/WaterMelon/WaterMelonSprout"
				},
				{
					Name = "Young", 
					Duration =  {59, 60}, 
					ModelPath = "Plants/WaterMelon/WaterMelonYoung"
				},
				{
					Name = "Mature", 
					Duration = 0,
					ModelPath = "Plants/WaterMelon/WaterMelonMature"
				}
			},
			HarvestCratePoints = 5,
			HarvestValue = 150, 
			Experience = 5000,
			LevelRequired = 1,
			PlotTypes = {"BasicPlot", "LargePlot", "PremiumPlot"},
			WitheringTime = 600,
			Placeable = true,
		},
	["PineappleSeed"] = {
		IsOnShop = true,
		Plant = "PineappleMature",
		OutOfStockChance = 0.5, 
		StockRange = {2, 4}, 
		Name = "PineappleSeed",
		--ImageId = "rbxassetid://94516589321794",
		ImageId = "rbxassetid://93159337938346",
		Price = 25000, 
		Category = "Seeds",
		Rarity = 'Epic',
		Stackable = true,

			Description = "Abacaxi maduro com coroa espinhosa e polpa doce. Fruta tropical premium, muito valorizada por seu sabor único.",

		Stages = {
			{
				Name = "Seed", 
				Duration = {80,100}, 
				ModelPath = "Seeds/PineappleSeed"
			},
			{
				Name = "Sprout", 
		    	Duration = {90,100}, 
				ModelPath = "Plants/Pineapple/PineappleSprout"
			},
			{
				Name = "Young", 
				Duration =  {99,100}, 
				ModelPath = "Plants/Pineapple/PineappleYoung"
			},
			{
				Name = "Mature", 
				Duration = 0,
				ModelPath = "Plants/Pineapple/PineappleMature"
			}
		},
		
		HarvestCratePoints = 5,
		HarvestValue = 200, 
		Experience = 6000,
		LevelRequired = 1,
		PlotTypes = {"BasicPlot", "LargePlot", "PremiumPlot",},
		WitheringTime = 600,
		Placeable = true,
			IsOnMerchant = true,
			MerchantPrice = 700, -- Price  das cratepoints
	},
	},
	
	["Crates"] = {
		["LuckyBlock"] = {
			Path = "Crates/LuckyBlock",
			Name = "LuckyBlock",
			ImageId = "rbxassetid://115141380873658", 
			Category = "Crates",
			Rarity = 'Rare',
			Stackable = true,
			Description = "Uma caixa com chance de itens mais raros.",
			Placeable = true,
			IsOnMerchant = true,
			MerchantPrice = 300, -- Price  das cratepoints
			IsBigItem = true,
		},
		["LuckyBlockSecret"] = {
			Path = "Crates/LuckyBlockSecret",
			Name = "LuckyBlockSecret",
			ImageId = "rbxassetid://107137792190549", 
			Category = "Crates",
			Rarity = 'Limited',
			Stackable = true,
			Description = "Uma caixa com chance de itens mais raros.",
			Placeable = true, 
			IsOnMerchant = true,
			MerchantPrice = 2500, -- Price  das cratepoints
			IsBigItem = true,
		},
		["LuckyBlockDecorations"] = {
			Path = "Crates/LuckyBlockDecorations",
			Name = "LuckyBlockDecorations",
			ImageId = "rbxassetid://120091710239923", 
			Category = "Crates",
			Rarity = 'Rare',
			Stackable = true,
			Description = "Uma caixa com chance de itens mais raros.",
			Placeable = true, 
			IsBigItem = true,
		},
		["MasterLuckyBlock"] = {
			Path = "Crates/MasterLuckyBlock",
			Name = "MasterLuckyBlock",
			ImageId = "rbxassetid://86744432946686", 
			Category = "Crates",
			Rarity = 'Rare',
			Stackable = true,
			Description = "MasterLuckyBlock",
			Placeable = true, 
		},
		["MasterEggLuckyBlock"] = {
			Path = "Crates/MasterLuckyBlock",
			Name = "MasterEggLuckyBlock",
			ImageId = "rbxassetid://86744432946686", 
			Category = "Crates",
			Rarity = 'Rare',
			Stackable = true,
			Description = "MasterLuckyBlock",
			Placeable = true, 
		},
	},
	["Plants"] = {
		["CarrotMature"] = {
			Path = "Plants/Carrot/CarrotMature",
			Name = "CarrotMature",
			ImageId = "rbxassetid://93874257120696",
			SellingPrice = 25,
			Category = "Plants",
			Rarity = 'Common',
			Stackable = true,
			Description = "Carrot",
			Placeable = true,
			CanPlaceInPlot = true,
			PossibleMutations = {
				{
					Name = "CarrotGold",
					Chance = 0.05 
				},
				-- {
				--     Name = "CarrotCrystal", -- Exemplo futuro
				--     Chance = 0.01
				-- }
			}
		},
		["PotatoMature"] = {
			Path = "Plants/Potato/PotatoMature",
			Name = "PotatoMature", 
			SellingPrice = 160, 
			ImageId = "rbxassetid://87277492140936",
			Category = "Plants",
			Rarity = 'Common',
			Stackable = true,
			Description = "Potato",
			Placeable = true,
			CanPlaceInPlot = true,
			PossibleMutations = {
				{
					Name = "PotatoGold",
					Chance = 0.05 
				},
			}
		},
		["BambooMature"] = {
			Path = "Plants/Bamboo/BambooMature",
			Name = "BambooMature",
			ImageId = "rbxassetid://108630508750213",
			SellingPrice = 480,
			Category = "Plants",
			Rarity = 'Rare',
			Stackable = true,
			Description = "Bamboo",
			Placeable = true,
			CanPlaceInPlot = true,
			PossibleMutations = {
				{
					Name = "BambooGold",
					Chance = 0.05 
				},
			}
		},
		["WheatMature"] = {
			Path = "Plants/Wheat/WheatMature",
			Name = "WheatMature",
			ImageId = "rbxassetid://122587532542918",
			SellingPrice = 1800, 
			Category = "Plants", 
			Rarity = 'Rare',
			Stackable = true,
			Description = "Wheat",
			Placeable = true,
			CanPlaceInPlot = true,
			PossibleMutations = {
				{
					Name = "WheatGold",
					Chance = 0.05 
				},
			}
		},
		["CornMature"] = {
			Path = "Plants/Corn/CornMature",
			Name = "CornMature",
			ImageId = "rbxassetid://110298121598825",
			SellingPrice = 3500, 
			Category = "Plants",
			Rarity = 'Rare', 
			Stackable = true,
			Description = "Corn",
			Placeable = true,
			CanPlaceInPlot = true,
			IsBigItem = true,
			PossibleMutations = {
				{
					Name = "CornGold",
					Chance = 0.05 
				},
			}
		},
		["TomatoMature"] = {
			Path = "Plants/Tomato/TomatoMature",
			Name = "TomatoMature",
			ImageId = "rbxassetid://71757540337728",
			SellingPrice = 6000, 
			Category = "Plants",
			Rarity = 'Rare',
			Stackable = true,
			Description = "Tomato", 
			Placeable = true,
			CanPlaceInPlot = true,
			IsBigItem = true,
			PossibleMutations = {
				{
					Name = "TomatoGold",
					Chance = 0.05 
				},
			}
		},
		["WaterMelonMature"] = {
			Path = "Plants/WaterMelon/WaterMelonMature",
			Name = "WaterMelonMature",
			ImageId = "rbxassetid://97002373420005",
			SellingPrice = 15000, 
			Category = "Plants",
			Rarity = 'Epic',
			Stackable = true,
			Description = "WaterMelon",
			Placeable = true,
			CanPlaceInPlot = true,
			IsBigItem = true,
			PossibleMutations = {
				{
					Name = "WaterMelonGold",
					Chance = 0.05 
				},
			}
		},
		["PineappleMature"] = {
			Path = "Plants/Pineapple/PineappleMature",
			Name = "PineappleMature",
			ImageId = "rbxassetid://94516589321794",
			SellingPrice = 55000, 
			Category = "Plants",
			Rarity = 'Epic',
			Stackable = true,
			Description = "Pineapple",
			Placeable = true,
			CanPlaceInPlot = true,
			IsBigItem = true,
			PossibleMutations = {
				{
					Name = "PineappleGold",
					Chance = 0.05 
				},
			}
		},
		
	},
	["Decoration"] = {
		["Fence"] = {
			Path = "Decoration/Fence",
			ImageId = "rbxassetid://96957029868546",
			IsOnShop = true,
			OutOfStockChance = 0, -- 0% de chance de estar esgotado
			StockRange = {5, 10}, -- Se tiver estoque, será entre 5 e 10
			Name = "Fence",
			Price = 50,
			SellingPrice = 5,
			Category = "Decoration",
			Rarity = 'Common',
			Stackable = true,
			PlacementLimit = 100,

			--icon = "🚧",
			Description = "Decorative fence",
			LevelRequired = 1,
			CanPlaceAnywhere = true,
			Placeable = true,
			IsOnMerchant = true,
			MerchantPrice = 10, -- Price  das cratepoints
			IsBigItem = true,
		},
		["ShopNPC"] = {
			Path = "Decoration/ShopNPC",
			ImageId = "rbxassetid://83540945634185",
			IsOnShop = false,
			OutOfStockChance = 0, -- 0% de chance de estar esgotado
			StockRange = {5, 10}, -- Se tiver estoque, será entre 5 e 10
			Name = "ShopNPC",
			Price = 50,
			SellingPrice = 25,
			Category = "Decoration",
			Rarity = 'Common',
			Stackable = false,
			CannotStore = true,

			--icon = "🚧",
			Description = "ShopNPC",
			LevelRequired = 1,
			CanPlaceAnywhere = true,
			Placeable = true,
		},   
		
		["Flower"] = {
			Path = "Decoration/Flower",
			IsOnShop = true,
			OutOfStockChance = 0.1,  --10% de chance de no vir e 90% de chance de vir
			StockRange = {3, 5}, -- Pode vir de 3 a 5  
			ImageId = "rbxassetid://137133354620600", 
			Name = "Flower", 
			Price = 100, 
			PlacementLimit = 100,
			SellingPrice = 10,
			Category = "Decoration", -- Categoria
			Rarity = 'Common', --Raridade 
			Stackable = true,  -- Stacka
			CanPlaceInPlot = false, -- Pode colocar na plot
			--icon = "🧙",
			Description = "A Simple Flower",
			LevelRequired = 1, -- nivel requerido
			CanPlaceAnywhere = true, -- em qualquer lugar
			Placeable = true, --Pode colocar
		},
		
		["Rock"] = {
			Path = "Decoration/Rock",
			IsOnShop = true,
			OutOfStockChance = 0.1,  --10% de chance de no vir e 90% de chance de vir
			StockRange = {3, 5}, -- Pode vir de 3 a 5  
			ImageId = "rbxassetid://117111857547456", 
			Name = "Rock", 
			Price = 250, 
			SellingPrice = 50,
			PlacementLimit = 100,
			Category = "Decoration", -- Categoria
			Rarity = 'Common', --Raridade 
			Stackable = true,  -- Stacka
			CanPlaceInPlot = false, -- Pode colocar na plot
			--icon = "🧙",
			Description = "A Simple Box",
			LevelRequired = 1, -- nivel requerido
			CanPlaceAnywhere = true, -- em qualquer lugar
			Placeable = true, --Pode colocar
			IsBigItem = true,
		},
		["Box"] = {
			Path = "Decoration/Box",
			IsOnShop = true,
			OutOfStockChance = 0.1,  --10% de chance de no vir e 90% de chance de vir
			StockRange = {3, 5}, -- Pode vir de 3 a 5  
			ImageId = "rbxassetid://103671945019564", 
			Name = "Box", 
			Price = 350, 
			PlacementLimit = 50,
			SellingPrice = 80,
			Category = "Decoration", -- Categoria
			Rarity = 'Common', --Raridade 
			Stackable = true,  -- Stacka
			CanPlaceInPlot = false, -- Pode colocar na plot
			--icon = "🧙",
			Description = "A Simple Box",
			LevelRequired = 1, -- nivel requerido
			CanPlaceAnywhere = true, -- em qualquer lugar
			Placeable = true, --Pode colocar
			IsBigItem = true,
		},
		
		["Mushroom"] = {
			Path = "Decoration/Mushroom",
			IsOnShop = true,
			OutOfStockChance = 0.1,  --de chance de nao vir 
			StockRange = {3, 5}, -- Pode vir de 3 a 5  
			ImageId = "rbxassetid://107757389607054", 
			Name = "Mushroom", 
			Price = 800, 
			PlacementLimit = 50,
			SellingPrice = 90,
			Category = "Decoration", -- Categoria
			Rarity = 'Rare', --Raridade 
			Stackable = true,  -- Stacka
			CanPlaceInPlot = false, -- Pode colocar na plot
			--icon = "🧙",
			Description = "A Simple Mushroom",
			LevelRequired = 1, -- nivel requerido
			CanPlaceAnywhere = true, -- em qualquer lugar
			Placeable = true, --Pode colocar
		},
		
		["Bench"] = {
			Path = "Decoration/Bench",
			IsOnShop = true,
			OutOfStockChance = 0.1,  --de chance de nao vir 
			StockRange = {3, 5}, -- Pode vir de 3 a 5  
			ImageId = "rbxassetid://95595611395955", 
			Name = "Bench", 
			Price = 900, 
			PlacementLimit = 20,
			SellingPrice = 100,
			Category = "Decoration", -- Categoria
			Rarity = 'Rare', --Raridade 
			Stackable = true,  -- Stacka
			CanPlaceInPlot = false, -- Pode colocar na plot
			--icon = "🧙",
			Description = "A Simple Mushroom",
			LevelRequired = 1, -- nivel requerido
			CanPlaceAnywhere = true, -- em qualquer lugar
			Placeable = true, --Pode colocar
			IsOnMerchant = true,
			MerchantPrice = 100, -- Price  das cratepoints
			IsBigItem = true,
		},
		
		["Scarecrow"] = {
			Path = "Decoration/Scarecrow",
			ImageId = "rbxassetid://136862616021246",
			IsOnShop = true,
			OutOfStockChance = 0.1, 
			StockRange = {3, 6}, 
			Name = "Scarecrow",
			SellingPrice = 150,
			Price = 500,
			PlacementLimit = 35,
			Category = "Decoration",
			Rarity = 'Rare',
			Stackable = true,
			CanPlaceInPlot = true,

			--icon = "🧙",
			Description = "A protective scarecrow",
			LevelRequired = 1,
			CanPlaceAnywhere = true,
			Placeable = true,
			IsBigItem = true,
			
		},
		["Well"] = {
			Path = "Decoration/Well",
		    IsOnShop = true,
			OutOfStockChance = 0.3, 
			StockRange = {3, 5}, 
		    ImageId = "rbxassetid://86026034104956",
			Name = "Well",
			Price = 750,
			PlacementLimit = 20,
			SellingPrice = 150,
			Category = "Decoration",
			Rarity = 'Rare',
			Stackable = true,
	        CanPlaceInPlot = true,
			--icon = "🧙",
			Description = "Fountain Water",
			LevelRequired = 1,
			CanPlaceAnywhere = true,
			Placeable = true,
			IsBigItem = true,
		},
		["WheatDeco"] = {
			Path = "Decoration/WheatDeco",
			ImageId = "rbxassetid://136042129611958",
			IsOnShop = true,
			OutOfStockChance = 0.3,
			StockRange = {3,5},
			Name = "WheatDeco",
			Price = 1000,
			PlacementLimit = 30,
			SellingPrice = 200,
			Category = "Decoration",
			Rarity = 'Rare',
			Stackable = true,
			IsBigItem = true,

			--icon = "🚧",
			Description = "Decorative  WheatDeco",
			LevelRequired = 1,
			CanPlaceAnywhere = true,
			Placeable = true,
		},
		["Gnomo"] = {
			Path = "Decoration/Gnomo",
			ImageId = "rbxassetid://125302090185877",
			IsOnShop = true,
			OutOfStockChance = 0.5,
			StockRange = {3,5},
			Name = "Gnomo",
			Price = 3000,
			SellingPrice = 200,
			Category = "Decoration",
			Rarity = 'Epic',
			Stackable = true,
			CanPlaceInPlot = true,
			PlacementLimit = 50,
			--icon = "🚧",
			Description = "Decorative Gnomo",
			LevelRequired = 1,
			CanPlaceAnywhere = true,
			Placeable = true,
			Buffs = {
				MoneyBonus = 0.01, -- +1% de dinheiro na colheita
				GrowthSpeedBonus = 0.2 -- 2% bônus de crescimento
			},
			IsOnMerchant = true,
			MerchantPrice = 280, -- Price  das cratepoints
		},
		["Lighter"] = {
			Path = "Decoration/Lighter",
			IsOnShop = true,
			ImageId = "rbxassetid://127218755043907",
			--DefaultStock = 5,
			OutOfStockChance = 0.7, 
			StockRange = {1, 3}, 
			Name = "Lighter",
			Price = 5000,
			PlacementLimit = 25,
			SellingPrice = 200,
			Category = "Decoration",
			Rarity = 'Epic',
			Stackable = true,

			--icon = "🧙",
			Description = "The one",
			LevelRequired = 1,
			CanPlaceAnywhere = true,
			Placeable = true,
			IsBigItem = true,
		},
		
		["Arch"] = {
			Path = "Decoration/Arch",
			IsOnShop = true,
			ImageId = "rbxassetid://99171378624339",
			--DefaultStock = 5,
			OutOfStockChance = 0.7, 
			StockRange = {1, 3}, 
			Name = "Arch",
			Price = 5500,
			SellingPrice = 200,
			Category = "Decoration",
			Rarity = 'Epic',
			Stackable = true,
			PlacementLimit = 25,

			--icon = "🧙",
			Description = "Simple Arch",
			LevelRequired = 1,
			CanPlaceAnywhere = true,
			Placeable = true,
			IsBigItem = true,
		},
		
		["Wood"] = {
			Path = "Decoration/Wood",
			IsOnShop = true,
			ImageId = "rbxassetid://115927312800635",
			--DefaultStock = 5,
			OutOfStockChance = 0.7, 
			StockRange = {1, 3}, 
			Name = "Wood",
			Price = 7500,
			PlacementLimit = 30,
			SellingPrice = 200,
			Category = "Decoration",
			Rarity = 'Epic',
			Stackable = true,

			--icon = "🧙",
			Description = "The one",
			LevelRequired = 1,
			CanPlaceAnywhere = true,
			Placeable = true,
			IsBigItem = true,
		},
		
		["Fountain"] = {
			Path = "Decoration/Fountain",
			IsOnShop = true,
			ImageId = "rbxassetid://87646666594627",
			--DefaultStock = 5,
			OutOfStockChance = 0.7, 
			StockRange = {1, 3}, 
			Name = "Fountain",
			Price = 8000,
			PlacementLimit = 10,
			SellingPrice = 200,
			Category = "Decoration",
			Rarity = 'Epic',
			Stackable = true,

			--icon = "🧙",
			Description = "The one",
			LevelRequired = 1,
			CanPlaceAnywhere = true,
			Placeable = true,
			IsBigItem = true,
		},
		
		["EspecialTower"] = {
			Path = "Decoration/EspecialTower",
			IsOnShop = true,
			ImageId = "rbxassetid://124711050162702",
			--DefaultStock = 5,
			OutOfStockChance = 0.9, 
			StockRange = {1, 3}, 
			Name = "EspecialTower",
			Price = 10000,
			PlacementLimit = 10,
			SellingPrice = 200,
			Category = "Decoration",
			Rarity = 'Legendary',
			Stackable = true,

			--icon = "🧙",
			Description = "The one",
			LevelRequired = 1,
			CanPlaceAnywhere = true,
			Placeable = true,
			IsOnMerchant = true,
			MerchantPrice = 1500, -- Price  das cratepoints
			IsBigItem = true,
		},
		
		["MegaTree"] = {
			Path = "Decoration/MegaTree",
			IsOnShop = true,
			ImageId = "rbxassetid://136992534117734",
			--DefaultStock = 5,
			OutOfStockChance = 0.9, 
			StockRange = {1, 3}, 
			Name = "MegaTree",
			Price = 10000,
			PlacementLimit = 10,
			SellingPrice = 200,
			Category = "Decoration",
			Rarity = 'Legendary',
			Stackable = true,

			--icon = "🧙",
			Description = "The one",
			LevelRequired = 1,
			CanPlaceAnywhere = true,
			Placeable = true,
			IsBigItem = true,
			IsOnMerchant = true,
			MerchantPrice = 600, -- Price  das cratepoints
			
		},
		
		["LotFus"] = {
			Path = "Decoration/LotFus",
			IsOnShop = true,
			ImageId = "rbxassetid://71998423872932",
			--DefaultStock = 5,
			OutOfStockChance = 0.99, 
			StockRange = {1, 1}, 
			Name = "LotFus",
			Price = 1000000,
			PlacementLimit = 3,
			SellingPrice = 200,
			Category = "Decoration",
			Rarity = 'Limited',
			Stackable = true,

			--icon = "🧙",
			Description = "U Good Enough",
			LevelRequired = 1,
			CanPlaceAnywhere = true,
			Placeable = true,
			IsOnMerchant = true,
			MerchantPrice = 5000, -- Price  das cratepoints
			Buffs = {
								MoneyBonus = 0.05, -- +5% de dinheiro na colheita
								GrowthSpeedBonus = 0.15 -- 15% bônus de crescimento
							},
		},
		
	},
	["Farming"] = {
		["BoostPlot"] = {
			Path = "Farming/BoostPlot",
			
			Name = "BoostPlot",
			ImageId = "rbxassetid://115803476345181",
			SellingPrice = 500,
			Category = "Farming",
			Rarity = 'Common',
			Stackable = true,
			PlacementLimit = 100,
			--Icon = "🟫",
			Description = "Basic plot for common seeds",
			MaxPlants = 1, -- Máximo de plantas por plot
			GrowthBonus = 1.5, -- Multiplicador de crescimento
			LevelRequired = 1,
			--Size = Vector3.new(8, 1, 8), -- Tamanho da plot
			GridSize = 2, -- Divisões internas (2x2 = 4 plantas)
			Placeable = true,
			IsOnMerchant = true,
			MerchantPrice = 150, -- Price  das cratepoints
			IsBigItem = true,
		},
		["CubePlot"] = {
			Path = "Farming/CubePlot",
			ImageId = "rbxassetid://130688496522453",
			Name = "CubePlot",
			SellingPrice = 500,
			Category = "Farming",
			Rarity = 'Common',
			Stackable = true,
			PlacementLimit = 500,
			--Icon = "🟫",
			Description = "Basic plot for common seeds",
			MaxPlants = 3, -- Máximo de plantas por plot
			GrowthBonus = 1, -- Multiplicador de crescimento
			LevelRequired = 1,
			--Size = Vector3.new(8, 1, 8), -- Tamanho da plot
			GridSize = 2, -- Divisões internas (2x2 = 4 plantas)
			Placeable = true,
			IsOnMerchant = true,
			MerchantPrice = 45, -- Price  das cratepoints
		},

		["BasicPlot"] = {
			Path = "Farming/BasicPlot",
			ImageId = "rbxassetid://130688496522453",
			Name = "BasicPlot",
			SellingPrice = 12500,
			Category = "Farming",
			Rarity = 'Rare',
			Stackable = true,
			PlacementLimit = 100,
			--Icon = "🟤",
			Description = "Bigger plot with space for many seeds",
			MaxPlants = 30,
			GrowthBonus = 1,
			LevelRequired = 5,
			--Size = Vector3.new(12, 1, 12),
			GridSize = 3, -- 3x3 = 9 plantas
			Placeable = true,
			IsBigItem = true,
			
		},

		["PremiumPlot"] = {
			Path = "Farming/PremiumPlot",
			ImageId = "rbxassetid://119161984874591",
			Name = "PremiumPlot",
			SellingPrice = 150000,
			Category = "Farming",
			Rarity = 'Legendary',
			Stackable = true,
			PlacementLimit = 10,
			--Icon = "✨",
			Description = "Premium plot with growth bonus",
			MaxPlants = 1,
			GrowthBonus = 2,  
			LevelRequired = 10,
			--Size = Vector3.new(16, 1, 16),
			GridSize = 4, -- 4x4 = 16 plantas
			Placeable = true,
			IsOnMerchant = true,
			MerchantPrice = 2250, -- Price  das cratepoints
			IsBigItem = true,
		}

	},
	["Pets"] = {
		
		["PigPet"] = {
			Path = "Pets/PigPet",
			Name = "PigPet",
			ImageId = "rbxassetid://115685517851864",
			Category = "Pets",
			Rarity = 'Epic',
			Stackable = false, 
			Description = "Um companheiro leal para suas aventuras espaciais. Clique para soltá-lo no seu planeta!",
			Placeable = true, 
			CannotStore = false, 
			CanRide = false,
			PlacementLimit = 3,
			MaxLevel = 50,
			IsBigItem = true,
			BuffIncreasePerLevel = 0.05, -- 5% de aumento por nível sobre o valor base do buff
			Buffs = {
				MoneyBonus = 0.15, -- +15% de dinheiro na colheita
				GrowthSpeedBonus = 0.15 -- 15% bônus de crescimento
			},
			
			AnimationIds = {
				Idle = "rbxassetid://128641669057056",
				Walk = "rbxassetid://127348166806728",
				Sit  = "rbxassetid://116239446900668"
			},
		},
		
		["PigPetGold"] = {
			Path = "Pets/PigPetGold",
			Name = "PigPetGold",
			ImageId = "rbxassetid://112238526138542",
			Category = "Pets",
			Rarity = 'Legendary',
			Stackable = false, 
			Description = "Um companheiro leal para suas aventuras espaciais. Clique para soltá-lo no seu planeta!",
			Placeable = true, 
			CannotStore = false, 
			CanRide = false,
			PlacementLimit = 3,
			MaxLevel = 50,
			IsBigItem = true,
			BuffIncreasePerLevel = 0.05, -- 5% de aumento por nível sobre o valor base do buff
			Buffs = {
				MoneyBonus = 0.8, -- +80% de dinheiro na colheita
				GrowthSpeedBonus = 0.8 -- 80% bônus de crescimento
			},
			AnimationIds = {
				Idle = "rbxassetid://128641669057056",
				Walk = "rbxassetid://127348166806728",
				Sit  = "rbxassetid://116239446900668"
			},
		
		},
		
		["BossPig"] = {
			Path = "Pets/BossPig",
			Name = "BossPig",
			ImageId = "rbxassetid://112287590095292",
			Category = "Pets",
			Rarity = 'Legendary',
			Stackable = false, 
			Description = "Um companheiro leal para suas aventuras espaciais. Clique para soltá-lo no seu planeta!",
			Placeable = true, 
			CannotStore = false, 
			PlacementLimit = 3,
			CanRide = true,
			MaxLevel = 50,
			IsBigItem = true,
			BuffIncreasePerLevel = 0.05, -- 5% de aumento por nível sobre o valor base do buff
			Buffs = {
				MoneyBonus = 2, -- +200% de dinheiro na colheita
				GrowthSpeedBonus = 2 -- 200% bônus de crescimento
			},
			AnimationIds = {
				Idle = "rbxassetid://128641669057056",
				Walk = "rbxassetid://127348166806728",
				Sit  = "rbxassetid://116239446900668"
			},
		},
			["KingPig"] = {
			Path = "Pets/KingPig",
			Name = "KingPig",
				ImageId = "rbxassetid://140313362599361",
				Category = "Pets",
				Rarity = 'Limited',
				Stackable = false, 
				Description = "Um Rei falecido para suas aventuras. Clique para soltá-lo no seu planeta!",
				Placeable = true, 
				CannotStore = false, 
				CanRide = false,
				PlacementLimit = 3,
				MaxLevel = 50,
				IsBigItem = true,
				BuffIncreasePerLevel = 0.05, -- 5% de aumento por nível sobre o valor base do buff
				Buffs = {
					MoneyBonus = 0.8, -- +80% de dinheiro na colheita
					GrowthSpeedBonus = 0.8 -- 80% bônus de crescimento
				},
				AnimationIds = {
					Idle = "rbxassetid://128641669057056",
					Walk = "rbxassetid://127348166806728",
					Sit  = "rbxassetid://116239446900668"
				},
			},
			
		["FrutiniPet"] = {
			Path = "Pets/FrutiniPet",
			Name = "FrutiniPet",
			ImageId = "rbxassetid://110057866769253",
			Category = "Pets",
			Rarity = 'Mythic',
			Stackable = false, 
			Description = "Um companheiro leal para suas aventuras espaciais. Clique para soltá-lo no seu planeta!",
			Placeable = true, 
			CannotStore = false, 
			PlacementLimit = 3,
			CanRide = false,
			MaxLevel = 50,
			IsBigItem = true,
			BuffIncreasePerLevel = 0.05, -- 5% de aumento por nível sobre o valor base do buff
			Buffs = {
				MoneyBonus = 0.75, -- +75% de dinheiro na colheita
				GrowthSpeedBonus = 0.75 -- 75% bônus de crescimento
			},
			AnimationIds = {
				Idle = "rbxassetid://128641669057056",
				Walk = "rbxassetid://127348166806728",
				Sit  = "rbxassetid://116239446900668"
			},
		},
		["TralalelitoPet"] = {
			Path = "Pets/TralalelitoPet",
			Name = "TralalelitoPet",
			ImageId = "rbxassetid://105106243904319",
			Category = "Pets",
			Rarity = 'Limited',
			Stackable = false, 
			Description = "Um companheiro leal para suas aventuras espaciais. Clique para soltá-lo no seu planeta!",
			Placeable = true, 
			CannotStore = false, 
			PlacementLimit = 3,
			CanRide = false,
			MaxLevel = 50,
			BuffIncreasePerLevel = 0.05, -- 5% de aumento por nível sobre o valor base do buff
			Buffs = {
				MoneyBonus = 1.25, -- +125% de dinheiro na colheita
				GrowthSpeedBonus = 1.25 -- 125% bônus de crescimento
			},
			AnimationIds = {
				Idle = "rbxassetid://128641669057056",
				Walk = "rbxassetid://127348166806728",
				Sit  = "rbxassetid://116239446900668"
			},
		},
	},
}



local ItemModels = game.ServerStorage.ItemModels
local DataStoreModule = require(game:GetService("ServerScriptService").Data.DataStoreModule)
local PlantMutationData = require(game:GetService("ServerScriptService").Data.PlantsMutationData)

--[[
FUNÇÕES GERAIS
]]

local RunService = game:GetService("RunService")
local isServer = RunService:IsServer()

local function GenerateStockValue(itemData)
	-- Se o item usa o novo sistema de chance
	if itemData.OutOfStockChance and itemData.StockRange then
		if math.random() <= itemData.OutOfStockChance then
			return 0 -- Esgotado
		else
			-- Gera um valor aleatório dentro do intervalo
			return math.random(itemData.StockRange[1], itemData.StockRange[2])
		end
	else
		-- Fallback para o sistema antigo ou para itens que não devem ser aleatórios
		return itemData.DefaultStock or 0
	end
end

function ItemData:GetSeedFromPlant(plantMatureName)
	if not self["Seeds"] then return nil end
	for seedName, seedData in pairs(self["Seeds"]) do
		if seedData.Plant and seedData.Plant == plantMatureName then
			return seedName 
		end
	end

	-- Retorna nil se nenhuma semente for encontrada
	warn("Nenhuma semente encontrada que produza a planta: ", plantMatureName)
	return nil
end

local function GetModelFromCustomPath(customPath)
	local pathTable = string.split(customPath, "/")
	
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

function ItemData:FindModel(itemObject, stage)
	if not itemObject then return end
	if itemObject.Path then
		return GetModelFromCustomPath(itemObject.Path)
	end
	if itemObject.Stages and itemObject.Stages[stage or 1] then
		return GetModelFromCustomPath(itemObject.Stages[stage or 1].ModelPath)
	end

	warn("Não foi possível encontrar um ModelPath para o item:", itemObject.Name)
	return nil
end
function ItemData:GetItem(category, itemName)
	if not category or not itemName then 
		warn("❌ GetItem: categoria ou nome do item é nil")
		return
	end
	local formattedCategory = string.upper(string.sub(category, 1, 1)) .. string.sub(category, 2, -1)
	if formattedCategory == "PlantsMutation" then
		return PlantMutationData:GetMutation(itemName)
	end
	if not ItemData[formattedCategory] then 
		warn("❌ A categoria '"..tostring(formattedCategory).."' não existe no ItemData.") 
		return nil 
	end
	for index, item in pairs(ItemData[formattedCategory]) do
		if string.lower(index) == string.lower(itemName:gsub(" ", "")) then
			return item
		end
	end
	return nil
end

function ItemData:GetItemsInCategory(category)
	if not category then
		warn("❌ GetItemsInCategory: categoria é nil")
		return nil
	end
	-- Formata o nome da categoria para corresponder às chaves da tabela (ex: "eggs" -> "Eggs")
	local formattedCategory = string.upper(string.sub(category, 1, 1)) .. string.sub(category, 2, -1)

	-- Retorna a tabela inteira para aquela categoria, ou nil se não existir
	return ItemData[formattedCategory] 
end



--[[
FUNÇÕES PARA LIDAR COM PLANTAS
]]
function getItemByProperty(list, propName, value)
	for index, item in ipairs(list) do
		if item[propName] and item[propName] == value then
			return item
		end
	end
	return nil
end

function ItemData:GetDecorationsInStock(player)
	local DecorationStockDataStore = DataStoreModule.GetDataStore(player, "DecorationStock")
	local DecorationPlayerStock = DecorationStockDataStore:GetData({})

	local finalStock = {}
	local playerHasDecoration = {} -- Usado para evitar adicionar duplicatas

	-- 1. Percorre o estoque salvo do jogador
	for _, savedData in ipairs(DecorationPlayerStock) do
		local masterData = ItemData["Decoration"][savedData.DecorationId]
		-- Verifica se a decoração ainda existe e está na loja
		if masterData and masterData.IsOnShop then
			savedData.DecorationData = masterData -- Anexa os dados completos
			table.insert(finalStock, savedData)
			playerHasDecoration[savedData.DecorationId] = true
		end
	end

	-- 2. Percorre a lista mestre de decorações no ItemData
	for decorationName, masterData in pairs(ItemData["Decoration"]) do
		-- Adiciona itens novos que o jogador não tem
		if masterData.IsOnShop and not playerHasDecoration[decorationName] then
			local newData = {
				DecorationId = decorationName,
				Stock = GenerateStockValue(masterData), 
				Favourite = false,
				DecorationData = masterData
			}
			table.insert(finalStock, newData)
		end
	end

	DecorationStockDataStore:SetData(finalStock)
	return finalStock
end

function ItemData:RestockPlayerDecorationsToDefault(player)
	local DecorationStockDataStore = DataStoreModule.GetDataStore(player, "DecorationStock")
	local oldStock = DecorationStockDataStore:GetData({}) -- Pega o estoque ANTIGO
	local updatedStock = {}
	local newlyRestockedFavorites = {}

	for decorationName, decorationData in pairs(ItemData["Decoration"]) do
		if decorationData.IsOnShop then
			local existingStock = getItemByProperty(oldStock, "DecorationId", decorationName)
			local newStockValue = GenerateStockValue(decorationData)
			local isFavourite = existingStock and existingStock.Favourite or false

			-- Checa se um item favorito foi reabastecido
			if isFavourite and newStockValue > 0 then
				table.insert(newlyRestockedFavorites, decorationData.Name)
			end

			table.insert(updatedStock, {
				DecorationId = decorationName,
				Stock = newStockValue, 
				Favourite = isFavourite,
				DecorationData = decorationData
			})
		end
	end
	DecorationStockDataStore:SetData(updatedStock)
	if #newlyRestockedFavorites > 0 then
		local NotifyPlayerEvent = game.ReplicatedStorage.RemoteEvents.Shop:FindFirstChild("NotifyPlayer")
		if NotifyPlayerEvent then
			NotifyPlayerEvent:FireClient(player, "Seus itens favoritos de decoração voltaram ao estoque!", newlyRestockedFavorites)
		end
	end

	return {
		success = true,
		message = "Estoque de decorações reabastecido",
		itemsUpdated = #updatedStock
	}
end

function ItemData:GetSeedsInStock(player)
	local SeedStockDataStore = DataStoreModule.GetDataStore(player, "SeedStock")
	local SeedPlayerStock = SeedStockDataStore:GetData({})
	
	local updatedStock = SeedPlayerStock
	
	for i, seedData in pairs(ItemData["Seeds"]) do
		if not getItemByProperty(SeedPlayerStock, "SeedId", i) and seedData.IsOnShop then
			local newData = {
				SeedId = i,
				Stock = GenerateStockValue(seedData), 
				Favourite = false,
			}
			table.insert(updatedStock, newData)
		end
	end
	
	for i, seedData in ipairs(SeedPlayerStock) do
		if not ItemData["Seeds"][seedData.SeedId] or not ItemData["Seeds"][seedData.SeedId].IsOnShop then
			table.remove(updatedStock, i)
		elseif ItemData["Seeds"][seedData.SeedId] then
			updatedStock[i].SeedData = ItemData["Seeds"][seedData.SeedId]
		end
	end
	
	SeedStockDataStore:SetData(updatedStock)
	
	return updatedStock	
end

function ItemData:RestockPlayerToDefault(player)
	local SeedStockDataStore = DataStoreModule.GetDataStore(player, "SeedStock")
	local oldStock = SeedStockDataStore:GetData({}) 

	local updatedStock = {}
	local newlyRestockedFavorites = {}

	for seedId, seedData in pairs(ItemData["Seeds"]) do
		if seedData.IsOnShop then
			local existingStock = getItemByProperty(oldStock, "SeedId", seedId)
			local newStockValue = GenerateStockValue(seedData)
			local isFavourite = existingStock and existingStock.Favourite or false
			if isFavourite and newStockValue > 0 then
				table.insert(newlyRestockedFavorites, seedData.Name)
			end

			table.insert(updatedStock, {
				SeedId = seedId,
				Stock = newStockValue, 
				Favourite = isFavourite,
				SeedData = seedData
			})
		end
	end

	SeedStockDataStore:SetData(updatedStock)
	if #newlyRestockedFavorites > 0 then
		local NotifyPlayerEvent = game.ReplicatedStorage.RemoteEvents.Shop:FindFirstChild("NotifyPlayer")
		if NotifyPlayerEvent then
			NotifyPlayerEvent:FireClient(player, "Suas sementes favoritas voltaram ao estoque!", newlyRestockedFavorites)
		end
	end

	return {
		success = true,
		message = "Estoque de sementes reabastecido",
		itemsUpdated = #updatedStock
	}
end
--// Função para obter o path do modelo para um estágio específico
function ItemData:GetPlantStageModelPath(itemName, stageIndex)
	return GetModelFromCustomPath(ItemData:GetItem("Seeds", itemName)["Stages"][stageIndex]["ModelPath"])
end
--// Função para obter dados de um estágio específico
function ItemData:GetPlantStageData(itemName, stageIndex)
	return ItemData:GetItem("Plants", itemName)["Stages"][stageIndex]
end

--// Função para obter o próximo estágio
function ItemData:GetNextStage(itemName, currentStage)
    return ItemData:GetItem("Seeds", itemName)["Stages"][currentStage+1]
end
--// Função para verificar se uma planta está no estágio final
function ItemData:IsPlantMature(itemName, stageIndex)
	return stageIndex >= #ItemData:GetItem("Seeds", itemName)["Stages"]
end
function ItemData:GetTotalGrowTime(itemName)
	local seedData = ItemData:GetItem("Seeds", itemName)
	if not seedData then return 0 end

	local totalTime = 0
	for i = 1, #seedData.Stages - 1 do 
		totalTime += seedData.Stages[i].Duration
	end

	return totalTime
end
--//canplotfunctions
function ItemData:CanPlantInPlot(itemName, plotName)
	local seedData = ItemData:GetItem("Seeds", itemName)
	local plotData = ItemData:GetItem("Farming", plotName)

	if not seedData or not plotData then return false end
    --Verificar se o tipo de solo da semente está na lista de tipos de solo compatíveis do plot
	for _, compatiblePlot in pairs(seedData.PlotTypes) do
		if compatiblePlot == plotName then
			return true
		end
	end

	return false
end
--//level
function ItemData:CanPlayerPlace(itemCategory, itemName, playerLevel)
	local itemData = ItemData:GetItem(itemCategory, itemName)
	if not itemData then return false end
	return playerLevel >= itemData.LevelRequired
end
--// =============================================================================
--// SISTEMA DE VALIDAÇÃO
--// =============================================================================
--//val
function ItemData:ValidatePlacement(itemCategory, itemName, playerLevel, plotName)
	if not self:CanPlayerPlace(itemCategory, itemName, playerLevel) then
		return false, "Nível insuficiente"
	end

	if itemCategory == "Seeds" and plotName then
		if not ItemData:CanPlantInPlot(itemName, plotName) then
			return false, "Semente incompatível com esta plot"
		end
	end

	return true, "Colocação válida"
end

return ItemData
