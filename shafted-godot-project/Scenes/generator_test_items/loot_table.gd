extends Resource
class_name LootTable

# Dictionary of { "item_id_string": weight_int }
# Higher weight = more likely to be selected.
# Example: { "gold_coin": 80, "health_potion": 20 }
# This means gold spawns ~80% of the time, potion ~20%.
@export var items: Dictionary = {}

# Picks a random item_id using weighted probability.
# Returns an empty string if the table is empty.
func pick_item() -> String:
	if items.is_empty():
		return ""

	# Sum all weights
	var total_weight = 0
	for weight in items.values():
		total_weight += weight

	# Roll a random number across the total weight range
	var roll = randi_range(1, total_weight)

	# Walk through items, subtracting weights until the roll is consumed
	var cumulative = 0
	for item_id in items.keys():
		cumulative += items[item_id]
		if roll <= cumulative:
			return item_id

	# Fallback — should never reach here
	return items.keys()[0]
