local badlatro = SMODS.current_mod

-- SMODS atlas for icon?

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
	if self and self.ability and self.ability.bad_nope and
			not context.mod_probability and not context.fix_probability and not context.pseudorandom_result then
		-- only do this when card has the sticker and the context isn't probability-related; yes, blueprints stack 1/2 chances
		if SMODS.pseudorandom_probability(self, 'bad_nope', 1, self.ability.bad_nope_chance) then
			-- success, let the card activate
		else
			-- failure, prevent activation
			return nil
		end
	end
	
	return old_calculate_joker(self, context)
end

local old_calculate_dollar_bonus = Card.calculate_dollar_bonus
function Card:calculate_dollar_bonus()
	if self and self.ability and self.ability.bad_nope then
		-- only do this when card has the sticker and the context isn't probability-related; yes, blueprints stack 1/2 chances
		if SMODS.pseudorandom_probability(self, 'bad_nope', 1, self.ability.bad_nope_chance) then
			-- success, let the card activate
		else
			-- failure, prevent activation
			return nil
		end
	end
	
	return old_calculate_dollar_bonus(self)
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
    local scale = 5/6
    return {n=G.UIT.ROOT, config = {align = "cl", minh = G.ROOM.T.h*0.25, padding = 0.0, r = 0.1, colour = G.C.GREY}, nodes = {
        {n = G.UIT.R, config = { padding = 0.05 }, nodes = {
            {n = G.UIT.C, config = { align = "cr", minw = G.ROOM.T.w*0.25, padding = 0.05 }, nodes = {
                create_toggle{ label = localize("bad_enable_nope_sticker"), active_colour = badlatro.badge_colour, ref_table = badlatro.config, ref_value = "enable_nope_sticker" },
            }},
        }}
    }}
end

sendDebugMessage("Badlatro loaded", "Badlatro")
