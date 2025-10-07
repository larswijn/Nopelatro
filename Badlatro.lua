local badlatro = SMODS.current_mod

-- SMODS atlas for icon?

SMODS.Atlas {
	key = 'nope_suit',
	px = 71,
	py = 95,
	path = 'AceOfNopes2.png'
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
		}
	}
}

SMODS.Sticker {
	key = "nope",
	atlas = "stickers",
	pos = { x = 0, y = 0 },
	-- description in localization file
	rate = 1,
	badge_colour = badlatro.badge_colour,
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
		soul_pos = { x = 1, y = 0},
    },
    false  -- show badlatro mod badge
)

SMODS.Consumable:take_ownership('soul',
	{
		bad_nope_compat = false,
	},
	true  -- hide badlatro mod badge
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
			local res = tables_match(v, v_b)
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
	result.modifiers["enable_bad_nope"] = badlatro.config.enable_nope_sticker
	return result
end

local old_calculate_joker = Card.calculate_joker
function Card:calculate_joker(context)
	-- This calculate is caused by a card that is supposed to Nope!
	if G.GAME.bad_nope and not context.blueprint_card then
		G.GAME.bad_nope_blocked = true
		return nil
	end

	local should_nope = nil
	local undo_actions = nil
	local ability_copy = nil
	
	if self and self.ability and self.ability.bad_nope and not context.blueprint_card and
			not context.mod_probability and not context.fix_probability and not context.pseudorandom_result then
		-- only do this when card has the sticker and the context isn't probability-related; yes, blueprints stack 1/2 chances
		if SMODS.pseudorandom_probability(self, 'bad_nope', 1, self.ability.bad_nope_chance) then
			-- success, let the card activate
		else
			-- failure, prevent activation
			should_nope = true
			local consumeable_buffer = G.GAME.consumeable_buffer
			local dollar_buffer = G.GAME.dollar_buffer
			local joker_buffer = G.GAME.joker_buffer
			local other_card_ability = context.other_card and copy_table(context.other_card.ability) or nil
			ability_copy = copy_table(self.ability)

			undo_actions = function ()
				G.GAME.consumeable_buffer = consumeable_buffer
				G.GAME.dollar_buffer = dollar_buffer
				G.GAME.joker_buffer = joker_buffer
				self.ability = ability_copy

				if other_card_ability then
					context.other_card.ability = other_card_ability
				end
			end

		end
	end
	
	G.GAME.bad_nope = should_nope
	local res = old_calculate_joker(self, context)
	G.GAME.bad_nope = false
	if should_nope then
		-- Nope popup when card was supposed to activate
		if res or G.GAME.bad_nope_blocked or not tables_match(ability_copy, self.ability) then
			undo_actions()
			card_eval_status_text(context.blueprint_card or self, 'extra', nil, nil, nil, {message = localize('k_nope_ex'), colour = G.C.PURPLE})
		end
		G.GAME.bad_nope_blocked = false
		return nil
	end

	return res
end

local old_disable = Blind.disable
function Blind:disable(...)
	if G.GAME and G.GAME.bad_nope then
		G.GAME.bad_nope_blocked = true
		return
	end

	return old_disable(self, ...)
end

local old_set_ability = Card.set_ability
function Card:set_ability(...)
	if G.GAME and G.GAME.bad_nope then
		G.GAME.bad_nope_blocked = true
		return
	end
	old_set_ability(self, ...)
end

-- Prevent events being added while calculating a card that should Nope!
local old_add_event = EventManager.add_event
function EventManager:add_event(...)
	if G.GAME and G.GAME.bad_nope then
		G.GAME.bad_nope_blocked = true
		return
	end
    
	return old_add_event(self, ...)
end

-- Prevent popups while calculating a card that should Nope!
local old_card_eval_status_text = card_eval_status_text
function card_eval_status_text(...)
	if G.GAME.bad_nope then
		G.GAME.bad_nope_blocked = true
		return
	end
    
	return old_card_eval_status_text(...)
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

SMODS.current_mod.config_tab = function()
    return {n=G.UIT.ROOT, config = {align = "cl", minh = G.ROOM.T.h*0.25, padding = 0.0, r = 0.1, colour = G.C.GREY}, nodes = {
        {n = G.UIT.R, config = { padding = 0.05 }, nodes = {
            {n = G.UIT.C, config = { align = "cr", minw = G.ROOM.T.w*0.25, padding = 0.05 }, nodes = {
                create_toggle{ label = localize("bad_enable_nope_sticker"), active_colour = badlatro.badge_colour, ref_table = badlatro.config, ref_value = "enable_nope_sticker" },
            }},
        }}
    }}
end

sendDebugMessage("Badlatro loaded", "Badlatro")
