local EggLootData = {

	-- Esta chave corresponde ao campo "LootTable"
	["BasicPetEggLoot"] = {
		LootTable = {
			{ Category = "Pets", Name = "PigPet", Weight = 90 }, -- 90% de chance
			{ Category = "Pets", Name = "PigPetGold", Weight = 10 }, 
			{ Category = "Pets", Name = "BossPig", Weight = 1 }, 
			{ Category = "Pets", Name = "KingPig", Weight = 0.1 },
		}
	},

	["RarePetEggLoot"] = {
		LootTable = {
			{ Category = "Pets", Name = "FrutiniPet", Weight = 100}, 
		}
	},
	
	["EpicPetEggLoot"] = {
		LootTable = {
			{ Category = "Pets", Name = "TralalelitoPet", Weight = 100}, 
		}
	},
	
	["LegendaryPetEggLoot"] = {
	},
}	

return EggLootData