-- Scorpion Moveset for Ryu (MMDK addon) -- educational demo, v1.1
-- v1.2: configurable donors (Mai/newer fighters via yulgi MMDK fork), spear voice line slot
-- MK-style Scorpion on Ryu, borrowing the closest SF6 animations from other fighters:
--   Spear           B,F + P   Ryu's Hadoken logic + Ed's chain-grab arm animation; hit staggers + pulls
--   Takedown        B,F + K   Ryu's Donkey Kick, re-input, harder knockdown
--   Teleport        D,B + HP  Akuma's Ashura Senku (fallback: Ryu's dash x3, invincible, pass-through)
--   Hellfire Upper  DP + HP/PP  Ryu's Shoryuken + Ken's flame VFX keys
-- Requires REFramework + MMDK. Offline / training only.

local mod_name = "Scorpion Moveset"
local mod_version = 1.2
local mod_author = "Pimpnastie"

------------------------------------------------------------------------------
-- TUNING
------------------------------------------------------------------------------
local cfg = {
	training_only      = true,   -- SAFETY: refuse to modify anything outside Training Mode
	-- Spear
	enable_spear       = true,
	spear_damage       = 500,
	spear_hitstun      = 40,
	spear_pull_x       = -90,    -- negative tries to pull (experimental; set 0 if it pushes away)
	spear_move_time    = 20,
	spear_anim         = true,   -- use Ed's chain-grab animation
	spear_anim_bank    = 1900601,-- Ed SpecialSkill_01 bank
	spear_anim_id      = 60,     -- SP_01_PsychoAnchor motion
	spear_voice_id     = nil,    -- set a SoundID (find one in MMDK Moveset Research > voice preview) for a "Get over here" shout
	-- Takedown
	enable_takedown    = true,
	takedown_damage    = 1100,
	-- Teleport
	enable_teleport    = true,
	teleport_button    = "HP",
	teleport_akuma     = true,   -- false = always use the dash version
	teleport_ratio     = 3.0,    -- dash fallback distance multiplier
	-- Hellfire
	enable_hellfire_fx = true,   -- copy a donor's flame VFX keys onto H and EX Shoryuken
	-- Donor for the flames. Ken works with stock MMDK. For Mai (better fire), install the yulgi MMDK fork,
	-- batch-dump her data, then set char="Mai" and the action IDs of her fiery rising move from her Names.json.
	hellfire_donor     = { char = "Ken", h = 957, ex = 958 },
}

-- Ryu IDs (from MMDK dumps)
local HADO_ACTIONS     = {900, 902, 904, 906, 1052, 1053}
local HADO_PROJECTILES = {909, 910, 911, 913, 1055, 1057}
local DKICK_ACTIONS    = {1025, 1027, 1029, 1031}
local DASH_F           = 17
local SYORYU_H, SYORYU_EX = 934, 936
local DASH_TELEPORT_ID = 1302
local CMD_BACK_FWD, CMD_DOWN_BACK = 50, 51

-- Donor IDs
local AKUMA_ASURA_F    = {1075, 1076, 1077, 1078, 1079, 1080} -- free on Ryu, so branch targets stay valid
local AKUMA_ASURA_BANK = 2200603

------------------------------------------------------------------------------
local tbls = require("MMDK\\tables")
local hit_types = tbls.hit_types
local inputs = tbls.inputs
local characters = tbls.characters

local fn = require("MMDK\\functions")
local clear_list = fn.clear_list
local clone_list_items = fn.clone_list_items
local copy_fields = fn.copy_fields
local edit_hit_dt_tbl = fn.edit_hit_dt_tbl
local to_isvec2 = fn.to_isvec2

-- True only when SF6's Training Mode is running (same check the MMDK batch dumper uses)
local function in_training_mode()
	local ok, result = pcall(function()
		local manager = sdk.get_managed_singleton("app.training.TrainingManager")
		if not manager then return false end
		local core = manager:call("get_BattleCore()")
		if not core then return false end
		local descs = core:get_field("_FighterDescs")
		return descs ~= nil and descs[0] ~= nil
	end)
	return ok and result == true
end

local function imgui_options()
	local c
	c, cfg.enable_spear       = imgui.checkbox("Spear (B,F+P)", cfg.enable_spear)
	c, cfg.spear_anim         = imgui.checkbox("  Ed chain-grab animation", cfg.spear_anim)
	c, cfg.enable_takedown    = imgui.checkbox("Takedown (B,F+K)", cfg.enable_takedown)
	c, cfg.enable_teleport    = imgui.checkbox("Teleport (D,B+" .. cfg.teleport_button .. ")", cfg.enable_teleport)
	c, cfg.teleport_akuma     = imgui.checkbox("  Akuma Ashura Senku version", cfg.teleport_akuma)
	c, cfg.enable_hellfire_fx = imgui.checkbox("Hellfire flame VFX (" .. cfg.hellfire_donor.char .. ")", cfg.enable_hellfire_fx)
	imgui.text("Changes apply next match")
	imgui.text(in_training_mode() and "Training Mode: moveset active" or "Not in Training Mode: moveset disabled")
end

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------
local dmg_id -- reset each match

-- "Product/Animation/esf/esf019/v00/motionlist/SpecialSkill/esf019v00_SpecialSkill_01.motlist" from bank 1900601
local function motlist_for_bank(bank)
	local esf = math.floor(bank / 100000)
	local slot = bank % 100
	return string.format("Product/Animation/esf/esf%03d/v00/motionlist/SpecialSkill/esf%03dv00_SpecialSkill_%02d.motlist", esf, esf, slot)
end

-- Load another fighter's animation bank into Ryu. Returns true if it worked.
local function borrow_bank(data, bank)
	local path = motlist_for_bank(bank)
	local ok, res = pcall(data.add_dynamic_motionbank, data, path, bank)
	if ok and res then return true end
	print("[Scorpion] could not load " .. path .. " -- using fallback")
	return false
end

local function trigger_ids_for(data, action_ids)
	local ids = {}
	for _, aid in ipairs(action_ids) do
		for tid, _ in pairs(data.triggers_by_act_id[aid] or {}) do table.insert(ids, tid) end
	end
	return ids
end

local function sync_modern(data, trig_ids)
	for _, tid in ipairs(trig_ids) do
		local trig = data.triggers[tid]
		if trig then copy_fields(trig.norm, trig.sprt) end
	end
end

-- Give a move private copies of its damage tables (from src_move's tables), optionally editing them
local function remap_damage(data, move, src_move, edits, param_types)
	if not (move and move.AttackCollisionKey) then return end
	src_move = src_move or move
	local map = {}
	for _, key in ipairs(move.AttackCollisionKey) do
		local old = key.AttackDataListIndex
		if old and old ~= -1 then
			if not map[old] then
				local src_tbl = (src_move.dmg or {})[old] or (move.dmg or {})[old]
				if src_tbl then
					local new_tbl = data:clone_dmg(src_tbl, dmg_id)
					if edits then edit_hit_dt_tbl(new_tbl, param_types or hit_types.allhit, edits) end
					move.dmg = move.dmg or {}
					move.dmg[dmg_id] = new_tbl
					map[old] = dmg_id
					dmg_id = dmg_id + 1
				end
			end
			if map[old] then key.AttackDataListIndex = map[old] end
		end
	end
end

local function set_motion(move, bank, motion_id)
	for _, key in ipairs(move.MotionKey or {}) do
		key.MotionType = bank
		key.MotionID = motion_id
	end
end

-- New special trigger for action_id, cloned from Ryu's H Hadoken trigger
local function add_special(data, action_id, cmd_id, dirs, button)
	local new_trigs, new_ids = data:clone_triggers(904, action_id, {0}, 118)
	local conds, frames = {}, {}
	for i = 1, #dirs do conds[i] = 2; frames[i] = 11 end
	data:add_command(cmd_id, 0, dirs, conds, frames, {total_frame=-1}, new_ids)
	for _, trig in ipairs(new_trigs) do
		trig.norm.ok_key_flags = button
		copy_fields(trig.norm, trig.sprt)
	end
end

------------------------------------------------------------------------------
local function apply_moveset_changes(data)
	if cfg.training_only and not in_training_mode() then
		print("[Scorpion] not in Training Mode -- moveset NOT applied")
		return false
	end

	print(os.clock() .. " Running MMDK function for " .. data.name .. "\n	" .. mod_name .. " v" .. mod_version)
	local moves = data.moves_dict.By_ID
	dmg_id = 4100

	-- TELEPORT (first: clones Hadoken's trigger before Hadoken gets re-input)
	if cfg.enable_teleport then
		local button = inputs[cfg.teleport_button] or inputs.HP
		local done = false

		if cfg.teleport_akuma and borrow_bank(data, AKUMA_ASURA_BANK) then
			local akuma = data:get_simple_fighter_data("Akuma")
			local amoves = akuma and akuma.moves_dict.By_ID
			if amoves and amoves[AKUMA_ASURA_F[1]] then
				for _, aid in ipairs(AKUMA_ASURA_F) do
					local m = amoves[aid] and data:clone_action(amoves[aid], aid)
					if m then
						-- Akuma's hurt/push rects don't exist on Ryu: make the whole teleport invincible + pass-through
						if m.DamageCollisionKey then clear_list(m.DamageCollisionKey.list) end
						if m.PushCollisionKey then clear_list(m.PushCollisionKey.list) end
					end
				end
				add_special(data, AKUMA_ASURA_F[1], CMD_DOWN_BACK, {inputs.DOWN, inputs.BACK}, button)
				done = true
			end
		end

		if not done and moves[DASH_F] then -- fallback: long invincible dash
			local tp = data:clone_action(moves[DASH_F], DASH_TELEPORT_ID)
			if tp then
				for _, key in ipairs(tp.PlaceKey or {}) do key.Ratio = cfg.teleport_ratio end
				if tp.PushCollisionKey then clear_list(tp.PushCollisionKey.list) end
				if tp.DamageCollisionKey then clear_list(tp.DamageCollisionKey.list) end
				add_special(data, DASH_TELEPORT_ID, CMD_DOWN_BACK, {inputs.DOWN, inputs.BACK}, button)
			end
		end
	end

	-- SPEAR
	if cfg.enable_spear then
		local trig_ids = trigger_ids_for(data, HADO_ACTIONS)
		data:add_command(CMD_BACK_FWD, 0, {inputs.BACK, inputs.FORWARD}, {2, 2}, {11, 11}, {total_frame=-1}, trig_ids)
		sync_modern(data, trig_ids)

		for _, pid in ipairs(HADO_PROJECTILES) do
			remap_damage(data, moves[pid], nil, {
				DmgValue = cfg.spear_damage,
				HitStun  = cfg.spear_hitstun,
				MoveTime = cfg.spear_move_time,
				MoveDest = to_isvec2(cfg.spear_pull_x, 0),
			}, hit_types.groundhit_only)
		end

		if cfg.spear_voice_id then
			for _, aid in ipairs(HADO_ACTIONS) do
				local m = moves[aid]
				if m and m.VoiceKey and m.VoiceKey.list._size > 0 then m.VoiceKey.list[0].SoundID = cfg.spear_voice_id end
			end
		end

		if cfg.spear_anim and borrow_bank(data, cfg.spear_anim_bank) then
			for _, aid in ipairs(HADO_ACTIONS) do
				if moves[aid] then set_motion(moves[aid], cfg.spear_anim_bank, cfg.spear_anim_id) end
			end
		end
	end

	-- TAKEDOWN
	if cfg.enable_takedown then
		local trig_ids = trigger_ids_for(data, DKICK_ACTIONS)
		data:add_command(CMD_BACK_FWD, 0, {inputs.BACK, inputs.FORWARD}, {2, 2}, {11, 11}, {total_frame=-1}, trig_ids)
		sync_modern(data, trig_ids)
		for _, aid in ipairs(DKICK_ACTIONS) do
			remap_damage(data, moves[aid], nil, {
				DmgValue = cfg.takedown_damage, DmgType = 11, MoveType = 13, MoveDest = to_isvec2(200, 70),
			})
		end
	end

	-- HELLFIRE VFX
	if cfg.enable_hellfire_fx then
		local donor = cfg.hellfire_donor
		local ok, dd = pcall(data.get_simple_fighter_data, data, donor.char)
		local dmoves = ok and dd and dd.moves_dict and dd.moves_dict.By_ID
		if dmoves then
			for ryu_id, donor_id in pairs({ [SYORYU_H] = donor.h, [SYORYU_EX] = donor.ex }) do
				local dst, src = moves[ryu_id], dmoves[donor_id]
				if dst and src and dst.VfxKey and src.VfxKey then
					clone_list_items(src.VfxKey.list, dst.VfxKey.list)
				end
			end
		else
			print("[Scorpion] no MMDK data for " .. tostring(donor.char) .. " -- dump it first; flames skipped")
		end
	end

	return true
end

return {
	apply_moveset_changes = apply_moveset_changes,
	imgui_options = imgui_options,
	mod_version = mod_version,
	mod_name = mod_name,
	mod_author = mod_author,
}
