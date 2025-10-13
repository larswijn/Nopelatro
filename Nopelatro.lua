local nopelatro = SMODS.current_mod

-- SMODS atlas for icon?

SMODS.Atlas {
	key = 'nope_suit',
	px = 71,
	py = 95,
	path = 'AceOfNopes2.png'
}

SMODS.Atlas {
	key = 'nope_suit_HC',
	px = 71,
	py = 95,
	path = 'AceOfNopes2_HC.png'
}

SMODS.Atlas{
	key = "stickers",
	px = 71,
	py = 95,
	path = "nopesticker.png",
}

SMODS.Atlas{
	key = "die",
	px = 71,
	py = 95,
	path = "die.png"
}

SMODS.Atlas{
	key = "balatro",
	px = 353,
	py = 212,
	path = "Nopelatro.png",
	prefix_config = false,
}

SMODS.Atlas{
	key = "shop_sign",
	px = 113,
	py = 57,
	frames = 3,
	path = "ShopSignAnimation.png",
	atlas_table = "ANIMATION_ATLAS",
	prefix_config = false,
}

SMODS.DeckSkin {
	key = "nope_suit",
	suit = "Diamonds",
	loc_txt = "Nope!",
	palettes = {
		{
			key = "lc",
			ranks = {'2', '3', '4', '5', '6', '7', '8', '9', '10', 'Jack', 'Queen', "King", "Ace",},
			display_ranks = {"Ace", "King", "Queen", "Jack", '10', '9', '8', '7', '6', '5', '4', '3', '2'},
			atlas = "bad_nope_suit",
			pos_style = 'deck',
			--[[suit_icon = {
				atlas = icon_lc.key,
			},--]]
		},
		{
			key = "hc",
			ranks = {'2', '3', '4', '5', '6', '7', '8', '9', '10', 'Jack', 'Queen', "King", "Ace",},
			display_ranks = {"Ace", "King", "Queen", "Jack", '10', '9', '8', '7', '6', '5', '4', '3', '2'},
			atlas = "bad_nope_suit_HC",
			pos_style = 'deck',
			--[[suit_icon = {
				atlas = icon_lc.key,
			},--]]
		}
	}
}

SMODS.Sticker {
	-- `eval SMODS.Stickers["bad_nope"]:apply(dp.hovered, true)` in case of debugging
	key = "nope",
	atlas = "stickers",
	pos = { x = 0, y = 0 },
	-- description in localization file
	rate = 1,
	badge_colour = nopelatro.badge_colour,
	config = { extra = { odds = 2 } },
	should_apply = function(self, card, center, area, bypass_roll)
		if center.bad_nope_compat == false then
			return false
		end
		if center.consumeable then
			return true
		elseif center.set == "Joker" then
			return true
		elseif center.set == "Voucher" then
			-- Voucher compat, maybe? Doesn't seem to work without patches regardless. Also not very vanilla
			return true
		-- playing cards, maybe? Not very vanilla either
		end
	end,
	apply = function(self, card, val)
		card.ability[self.key] = val
		if val then
			card.ability.bad_nope_chance = self.config.extra.odds
		end
	end,
	loc_vars = function(self, info_queue, card)
		local numerator, denominator = SMODS.get_probability_vars(card, 1, card.ability.bad_nope_chance, 'bad_nope')
		return { vars = { numerator, denominator } }
	end
}

SMODS.Joker:take_ownership('oops',
    {
		rarity = 4,
		cost = 20,
		bad_nope_compat = false,
		atlas = "die",
		pos = { x = 0, y = 0},
		blueprint_compat = true,
		soul_pos = { x = 1, y = 0},
		calculate = function (self, card, context)
			if context.mod_probability then
				return {
					numerator = context.numerator * 2
				}
			end
		end,
    },
    false  -- show nopelatro mod badge
)

SMODS.Consumable:take_ownership('soul',
	{
		bad_nope_compat = false,
	},
	true  -- hide nopelatro mod badge
)

-- local functions
local function nope_event(used_tarot)
	return G.E_MANAGER:add_event(Event({trigger = 'after', delay = 0.4, func = function()
		attention_text({
			text = localize('k_nope_ex'),
			scale = 1.3, 
			hold = 1.4,
			major = used_tarot,
			backdrop_colour = G.C.SECONDARY_SET.Tarot,
			align = (G.STATE == G.STATES.TAROT_PACK or G.STATE == G.STATES.SPECTRAL_PACK or G.STATE == G.STATES.SMODS_BOOSTER_OPENED) and 'tm' or 'cm',
			offset = {x = 0, y = (G.STATE == G.STATES.TAROT_PACK or G.STATE == G.STATES.SPECTRAL_PACK or G.STATE == G.STATES.SMODS_BOOSTER_OPENED) and -0.2 or 0},
			silent = true
		})
		G.E_MANAGER:add_event(Event({trigger = 'after', delay = 0.06*G.SETTINGS.GAMESPEED, blockable = false, blocking = false, func = function()
			play_sound('tarot2', 0.76, 0.4);return true end}))
		play_sound('tarot2', 1, 0.4)
		used_tarot:juice_up(0.3, 0.5)
		return true 
	end}))
end

local function wrap_function_with_nope(func)
	-- "wraps" target function with a check for `G.GAME.bad_nope` and returns prematurely
	-- useful for when you want to hook multiple functions with the exact same functionality
	local function wrapper(...)
		if G.GAME and G.GAME.bad_nope and not G.GAME.bypass_bad_nope then
			G.GAME.bad_nope_blocked = true
			return
		end
		return func(...)
	end
	return wrapper
end

local function copy_table(t, depth)
	if type(t) ~= "table" then
		return t
	end
	depth = depth or 1
	local res = {}

	for k, v in pairs(t) do
		if type(v) == "table" and depth <= 5 then
			res[k] = copy_table(v, depth + 1)
		else
			res[k] = v

		end
	end

	return res
end

local function table_size(t)
	local size = 0
	local last_index = nil
	while true do
		last_index = next(t, last_index)
		if last_index then
			size = size + 1
		else
			return size
		end
	end
end

local function tables_match(a, b, depth)
	assert(type(a) == "table", "First parameter must be a table!")
	assert(type(b) == "table", "Second parameter must be a table!")
	depth = depth or 1

	local a_size = 0;
	for k, v in pairs(a) do
		local v_b = b[k]
		if type(v) ~= type(v_b) then
			return false
		end

		if type(v) == "table" and depth <= 5 then
			local res = tables_match(v, v_b, depth + 1)
			if res ~= true then
				return res
			end

		elseif b[k] ~= v then
			return false
		end

		a_size = a_size + 1
	end

	return a_size == table_size(b)
end

-- hooks
local old_game_init_game_object = Game.init_game_object
function Game:init_game_object()
	local result = old_game_init_game_object(self)
	result.modifiers = result.modifiers or {}
	result.modifiers["enable_bad_nope"] = nopelatro.config.enable_nope_sticker
	return result
end

local old_calculate_joker = Card.calculate_joker
function Card:calculate_joker(context)
	if context.mod_probability or context.fix_probability or context.pseudorandom_result then
		-- do NOT fuck with these probability contexts, prone to causing infinite loops
		return old_calculate_joker(self, context)
	end
	
	if context.first_hand_drawn and (self.ability.name == 'DNA' or self.ability.name == 'Trading Card') then
		-- Don't NOPE when setting jiggle for DNA and Trading card
		return old_calculate_joker(self, context)
	end

	-- This calculate is caused by a card that is supposed to Nope!
	if G.GAME.bad_nope and not context.blueprint_card then
		G.GAME.bad_nope_blocked = true
		return nil
	end

	local should_nope = nil
	local undo_actions = function() end
	local ability_copy = nil
	
	if self and self.ability and self.ability.bad_nope then
		-- only do this when card has the sticker and the context isn't probability-related; yes, blueprints stack 1/2 chances
		if SMODS.pseudorandom_probability(self, 'bad_nope', 1, self.ability.bad_nope_chance) then
			-- success, let the card activate normally
		else
			-- failure, revert activation and show nope
			should_nope = true
			local consumeable_buffer = G.GAME.consumeable_buffer
			local dollar_buffer = G.GAME.dollar_buffer
			local joker_buffer = G.GAME.joker_buffer
			local game_pool_buffer = copy_table(G.GAME.pool_flags)
			local other_card_ability = context.other_card and copy_table(context.other_card.ability) or nil
			ability_copy = copy_table(self.ability)

			undo_actions = function ()
				G.GAME.consumeable_buffer = consumeable_buffer
				G.GAME.dollar_buffer = dollar_buffer
				G.GAME.joker_buffer = joker_buffer
				G.GAME.pool_flags = game_pool_buffer
				self.ability = ability_copy

				if other_card_ability then
					context.other_card.ability = other_card_ability
				end
			end

		end
	end

	G.GAME.bad_nope = should_nope and self.config.center.key or G.GAME.bad_nope or false
	G.GAME.bad_nope_blocked = G.GAME.bad_nope_blocked or false
	local res = old_calculate_joker(self, context)
	local old_bad_nope_blocked = G.GAME.bad_nope_blocked
	if not context.blueprint_card then
		G.GAME.bad_nope = false
		G.GAME.bad_nope_blocked = false
	end
	
	if should_nope or old_bad_nope_blocked then
		local do_nope = res or old_bad_nope_blocked or not tables_match(ability_copy, self.ability)
		-- Nope popup when card was supposed to activate
		if do_nope then
			undo_actions()
			if context.end_of_round and context.repetition then
				-- Weird edgecase with Mime: (unenhanced) cards have no effect but still trigger this context
				-- returning "again" for these cards in this context gets silently ignored, but returning anything else gives a message/pop-up
				-- so we explicitly return nil to avoid unexpected "Nope!"s
				return nil
			elseif context.individual then
				return {
					message = localize('k_nope_ex'),
					colour = G.C.PURPLE,
					card = self
				}
			else
				card_eval_status_text(context.blueprint_card or self, 'extra', nil, nil, nil, {message = localize('k_nope_ex'), colour = G.C.PURPLE})
			end
		end
		return nil
	end

	return res
end

local old_calculate_dollar_bonus = Card.calculate_dollar_bonus
function Card:calculate_dollar_bonus()
	local should_nope = false
	if self and self.ability and self.ability.bad_nope then
		-- only do this when card has the sticker and the context isn't probability-related; yes, blueprints stack 1/2 chances
		if SMODS.pseudorandom_probability(self, 'bad_nope', 1, self.ability.bad_nope_chance) then
			-- success, let the card activate
		else
			-- failure, prevent activation
			should_nope = true
		end
	end

	local res = old_calculate_dollar_bonus(self)
	-- Nope popup when card was supposed to activate 
	if should_nope then
		if res then
			card_eval_status_text(self, 'extra', nil, nil, nil, {message = localize('k_nope_ex'), colour = G.C.PURPLE})
		end
		return nil
	end

	return res
end

local old_use_consumeable = Card.use_consumeable
function Card:use_consumeable(area, copier)
	if self and self.ability and self.ability.bad_nope then
		-- only do this when card has the sticker and the context isn't probability-related; yes, blueprints stack 1/2 chances
		if SMODS.pseudorandom_probability(self, 'bad_nope', 1, self.ability.bad_nope_chance) then
			-- success, let the card activate
		else
			-- failure, prevent activation
			nope_event(copier or self)
			return nil
		end
	end
	
	return old_use_consumeable(self, area, copier)
end

Blind.disable = wrap_function_with_nope(Blind.disable)
SMODS.destroy_cards = wrap_function_with_nope(SMODS.destroy_cards)
EventManager.add_event = wrap_function_with_nope(EventManager.add_event)
card_eval_status_text = wrap_function_with_nope(card_eval_status_text)
level_up_hand = wrap_function_with_nope(level_up_hand)

SMODS.current_mod.config_tab = function()
    return {n=G.UIT.ROOT, config = {align = "cl", minh = G.ROOM.T.h*0.25, padding = 0.0, r = 0.1, colour = G.C.GREY}, nodes = {
        {n = G.UIT.R, config = { padding = 0.05 }, nodes = {
            {n = G.UIT.C, config = { align = "cr", minw = G.ROOM.T.w*0.25, padding = 0.05 }, nodes = {
                create_toggle{ label = localize("bad_enable_nope_sticker"), active_colour = nopelatro.badge_colour, ref_table = nopelatro.config, ref_value = "enable_nope_sticker" },
            }},
        }}
    }}
end

-- safe-guard against nested folders (unapplied lovely patches)
local lovely_toml_info = NFS.getInfo(SMODS.current_mod.path .. "lovely.toml")
local lovely_dir_items = NFS.getInfo(SMODS.current_mod.path .. "lovely") and NFS.getDirectoryItems(SMODS.current_mod.path .. "lovely")
local should_have_lovely = lovely_toml_info or (lovely_dir_items and #lovely_dir_items > 0)
if should_have_lovely then
    -- if we have detected a `lovely.toml` file or a non-empty `lovely` directory (assumption that it contains lovely patches)
    assert(SMODS.current_mod.lovely, "Failed to detect Nopelatro lovely patches.\n\nPlease make SURE your Nopelatro folder is NOT nested (it should look like Mods/Nopelatro/<files>, not Mods/Nopelatro/Nopelatro/<files>).\n\n\n\n")
end

sendDebugMessage("Nopelatro loaded", "nopelatro")
