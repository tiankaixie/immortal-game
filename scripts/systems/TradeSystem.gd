extends Node
## TradeSystem — Trading Post and NPC Merchant management
##
## Handles:
## - NPC merchant stock generation and rotation
## - Buy/sell transactions
## - Price fluctuation based on supply/demand
## - Sect contracts (fetch quests for bonus rewards)
## - Dungeon mid-run merchant encounters
##
## Design: Trading is primarily between runs at the Sect Hub.
## Dungeon merchants offer limited mid-run purchases.

# ─── Constants ─────────────────────────────────────────────────
const BASE_BUY_MULTIPLIER: float = 1.5   # Items cost 1.5x their sell value
const BASE_SELL_MULTIPLIER: float = 0.5   # Selling gets 50% of base value
const PRICE_FLUCTUATION_RANGE: float = 0.2  # ±20% price variance
const MAX_MERCHANT_ITEMS: int = 12        # Max items in shop per refresh
const DUNGEON_MERCHANT_ITEMS: int = 5     # Items available from dungeon merchant

# ─── State ─────────────────────────────────────────────────────
## Current merchant inventory (refreshes after each run)
var merchant_stock: Array[Dictionary] = []

## Price modifiers based on player trading history
## { item_category: price_modifier }
## Selling lots of one category → price drops; not selling → price rises
var price_modifiers: Dictionary = {}

## Active contracts (fetch quests)
var active_contracts: Array[Dictionary] = []
const MAX_ACTIVE_CONTRACTS: int = 3

# ─── Signals ───────────────────────────────────────────────────
signal item_purchased(item: Dictionary, cost: int)
signal item_sold(item: Dictionary, revenue: int)
signal stock_refreshed()
signal contract_completed(contract: Dictionary, reward: Dictionary)
signal contract_accepted(contract: Dictionary)

func _ready() -> void:
	print("[TradeSystem] Initialized")
	# TODO: Connect to GameManager.run_ended to refresh stock

# ─── Merchant Stock Generation ─────────────────────────────────
func refresh_merchant_stock() -> void:
	"""Generate new merchant inventory. Called after each run."""
	merchant_stock.clear()
	
	# TODO: Generate a mix of:
	# - Equipment (random, biased toward Spirit/Treasure rarity)
	# - Consumables (healing pills, temporary buffs)
	# - Crafting materials
	# - Skill scrolls (rare)
	
	for i in range(MAX_MERCHANT_ITEMS):
		var item := _generate_merchant_item()
		item["price"] = _calculate_buy_price(item)
		merchant_stock.append(item)
	
	stock_refreshed.emit()

func _generate_merchant_item() -> Dictionary:
	"""Generate a single item for the merchant's stock.
	
	TODO: Pull from proper item databases.
	Placeholder implementation generates basic items.
	"""
	var item_types := ["equipment", "consumable", "material"]
	var item_type: String = item_types[randi() % item_types.size()]
	
	match item_type:
		"consumable":
			return _generate_consumable()
		"material":
			return _generate_material()
		_:
			# Equipment — delegate to EquipmentSystem
			# TODO: var equip_sys = get_node("/root/EquipmentSystem")
			return {
				"id": "placeholder_%d" % randi(),
				"type": "equipment",
				"name": "灵器",
				"base_value": 50,
				"category": "equipment",
			}

func _generate_consumable() -> Dictionary:
	"""Generate a random consumable item (pills, talismans, etc.)."""
	var consumables := [
		{ "name": "回气丹", "desc": "Restores 30% HP", "effect": "heal_30", "base_value": 20 },
		{ "name": "灵力丹", "desc": "Restores 50% Spiritual Power", "effect": "mana_50", "base_value": 25 },
		{ "name": "破境丹", "desc": "+20% cultivation XP for one run", "effect": "xp_boost_20", "base_value": 100 },
		{ "name": "金刚符", "desc": "+30% defense for 60s", "effect": "def_buff_30", "base_value": 40 },
		{ "name": "疾风符", "desc": "+20% speed for 60s", "effect": "speed_buff_20", "base_value": 35 },
	]
	var template: Dictionary = consumables[randi() % consumables.size()]
	
	return {
		"id": "consumable_%d" % randi(),
		"type": "consumable",
		"name": template["name"],
		"description": template["desc"],
		"effect": template["effect"],
		"base_value": template["base_value"],
		"category": "consumable",
	}

func _generate_material() -> Dictionary:
	"""Generate a random crafting material."""
	var materials := [
		{ "name": "灵石矿", "desc": "Raw spirit stone ore", "base_value": 10 },
		{ "name": "妖兽核", "desc": "Demonic beast core", "base_value": 30 },
		{ "name": "千年灵草", "desc": "Thousand-year spirit herb", "base_value": 50 },
		{ "name": "天外陨铁", "desc": "Meteoric iron", "base_value": 80 },
	]
	var template: Dictionary = materials[randi() % materials.size()]
	
	return {
		"id": "material_%d" % randi(),
		"type": "material",
		"name": template["name"],
		"description": template["desc"],
		"base_value": template["base_value"],
		"category": "material",
	}

# ─── Pricing ───────────────────────────────────────────────────
func _calculate_buy_price(item: Dictionary) -> int:
	"""Calculate the buy price for an item, factoring in price modifiers."""
	var base_price: float = item.get("base_value", 10) * BASE_BUY_MULTIPLIER
	var category: String = item.get("category", "misc")
	var modifier: float = price_modifiers.get(category, 1.0)
	
	# Add random variance
	var variance := randf_range(1.0 - PRICE_FLUCTUATION_RANGE, 1.0 + PRICE_FLUCTUATION_RANGE)
	
	return max(1, int(base_price * modifier * variance))

func _calculate_sell_price(item: Dictionary) -> int:
	"""Calculate sell price for a player's item."""
	var base_price: float = item.get("base_value", 10) * BASE_SELL_MULTIPLIER
	var category: String = item.get("category", "misc")
	var modifier: float = price_modifiers.get(category, 1.0)
	
	return max(1, int(base_price * modifier))

func get_sell_price(item: Dictionary) -> int:
	"""Public method to check what an item would sell for."""
	return _calculate_sell_price(item)

# ─── Transactions ──────────────────────────────────────────────
func buy_item(item_index: int) -> bool:
	"""Purchase an item from merchant stock.
	
	Returns true if purchase succeeded.
	"""
	if item_index < 0 or item_index >= merchant_stock.size():
		push_error("[TradeSystem] Invalid item index: %d" % item_index)
		return false
	
	var item: Dictionary = merchant_stock[item_index]
	var cost: int = item["price"]
	
	if not PlayerData.spend_spirit_stones(cost):
		print("[TradeSystem] Not enough spirit stones (%d required)" % cost)
		return false
	
	# Add to player inventory
	PlayerData.inventory.append(item)
	PlayerData.inventory_changed.emit()
	
	# Remove from merchant stock
	merchant_stock.remove_at(item_index)
	
	item_purchased.emit(item, cost)
	return true

func sell_item(inventory_index: int) -> bool:
	"""Sell an item from player inventory.
	
	Returns true if sale succeeded.
	"""
	if inventory_index < 0 or inventory_index >= PlayerData.inventory.size():
		push_error("[TradeSystem] Invalid inventory index: %d" % inventory_index)
		return false
	
	var item: Dictionary = PlayerData.inventory[inventory_index]
	
	# Can't sell soul-bound items
	if item.get("soul_bound", false):
		print("[TradeSystem] Cannot sell soul-bound items")
		return false
	
	var revenue := _calculate_sell_price(item)
	
	# Remove from inventory and add currency
	PlayerData.inventory.remove_at(inventory_index)
	PlayerData.add_spirit_stones(revenue)
	PlayerData.inventory_changed.emit()
	
	# Update price modifier (selling lots of one category lowers price)
	_update_price_modifier(item.get("category", "misc"), -0.02)
	
	item_sold.emit(item, revenue)
	return true

# ─── Price Fluctuation ─────────────────────────────────────────
func _update_price_modifier(category: String, change: float) -> void:
	"""Adjust price modifier for a category.
	
	Negative change = selling pressure (prices drop).
	Positive change = demand pressure (prices rise).
	Clamped to [0.5, 2.0] range.
	"""
	var current: float = price_modifiers.get(category, 1.0)
	price_modifiers[category] = clamp(current + change, 0.5, 2.0)

func normalize_prices() -> void:
	"""Slowly normalize all price modifiers toward 1.0.
	Called after each run to prevent extreme price swings.
	"""
	for category in price_modifiers:
		var current: float = price_modifiers[category]
		price_modifiers[category] = move_toward(current, 1.0, 0.05)

# ─── Contracts System ──────────────────────────────────────────
func generate_contracts() -> void:
	"""Generate new sect contracts (fetch quests).
	
	Contracts ask the player to acquire specific items/materials
	from dungeon runs in exchange for bonus rewards.
	"""
	active_contracts.clear()
	
	# TODO: Generate from a contract template database
	var templates := [
		{
			"desc": "Collect 3 Demonic Beast Cores",
			"requirement": { "item_id": "beast_core", "count": 3 },
			"reward": { "spirit_stones": 200, "item": null },
		},
		{
			"desc": "Retrieve a Treasure-grade or higher weapon",
			"requirement": { "rarity_min": 2, "slot": "weapon", "count": 1 },
			"reward": { "spirit_stones": 500, "item": null },
		},
		{
			"desc": "Gather 5 Thousand-Year Spirit Herbs",
			"requirement": { "item_id": "spirit_herb", "count": 5 },
			"reward": { "spirit_stones": 150, "cultivation_xp": 50 },
		},
	]
	
	templates.shuffle()
	for i in range(min(MAX_ACTIVE_CONTRACTS, templates.size())):
		var contract: Dictionary = templates[i].duplicate(true)
		contract["id"] = "contract_%d" % randi()
		contract["progress"] = 0
		active_contracts.append(contract)
		contract_accepted.emit(contract)

func check_contract_progress(item: Dictionary) -> void:
	"""Check if a newly acquired item progresses any active contracts.
	
	Called when player picks up loot or purchases items.
	"""
	for contract in active_contracts:
		# TODO: Match item against contract requirements
		# TODO: Increment progress
		# TODO: If complete, grant reward and remove contract
		pass

# ─── Dungeon Merchant ─────────────────────────────────────────
func generate_dungeon_merchant_stock(floor_level: int) -> Array[Dictionary]:
	"""Generate limited stock for a mid-run dungeon merchant.
	
	Dungeon merchants sell consumables and occasional equipment.
	Stock is influenced by current floor level.
	"""
	var stock: Array[Dictionary] = []
	
	for i in range(DUNGEON_MERCHANT_ITEMS):
		var item: Dictionary
		if randf() < 0.7:
			item = _generate_consumable()
		else:
			item = _generate_material()
		
		# Dungeon merchant prices are higher (scarcity premium)
		item["price"] = int(item.get("base_value", 10) * 2.0 * (1.0 + floor_level * 0.1))
		stock.append(item)
	
	return stock
