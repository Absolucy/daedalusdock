

//NOTE: Breathing happens once per FOUR TICKS, unless the last breath fails. In which case it happens once per ONE TICK! So oxyloss healing is done once per 4 ticks while oxyloss damage is applied once per tick!

// bitflags for the percentual amount of protection a piece of clothing which covers the body part offers.
// Used with human/proc/get_heat_protection() and human/proc/get_cold_protection()
// The values here should add up to 1.
// Hands and feet have 2.5%, arms and legs 7.5%, each of the torso parts has 15% and the head has 30%
#define THERMAL_PROTECTION_HEAD 0.3
#define THERMAL_PROTECTION_CHEST 0.15
#define THERMAL_PROTECTION_GROIN 0.15
#define THERMAL_PROTECTION_LEG_LEFT 0.075
#define THERMAL_PROTECTION_LEG_RIGHT 0.075
#define THERMAL_PROTECTION_FOOT_LEFT 0.025
#define THERMAL_PROTECTION_FOOT_RIGHT 0.025
#define THERMAL_PROTECTION_ARM_LEFT 0.075
#define THERMAL_PROTECTION_ARM_RIGHT 0.075
#define THERMAL_PROTECTION_HAND_LEFT 0.025
#define THERMAL_PROTECTION_HAND_RIGHT 0.025

/mob/living/carbon/human/Life(delta_time = SSMOBS_DT, times_fired)
	if(notransform)
		return

	. = ..()
	if(QDELETED(src))
		return FALSE

	// Increase germ_level regularly
	if(germ_level < GERM_LEVEL_AMBIENT && prob(30))	//if you're just standing there, you shouldn't get more germs beyond an ambient level
		germ_level++

	//Body temperature stability and damage
	if(dna.species.handle_body_temperature(src, delta_time, times_fired))
		updatehealth()

	if(!IS_IN_STASIS(src))
		if(stat != DEAD) //not dead

			for(var/datum/mutation/human/HM in dna.mutations) // Handle active genes
				HM.on_life(delta_time, times_fired)

		if(stat != DEAD)
			//heart attack stuff
			handle_liver(delta_time, times_fired)

		dna.species.spec_life(src, delta_time, times_fired) // for mutantraces

	if(stat != DEAD)
		return TRUE

/mob/living/carbon/human/calculate_affecting_pressure(pressure)
	var/chest_covered = FALSE
	var/head_covered = FALSE
	for(var/obj/item/clothing/equipped in get_equipped_items())
		if((equipped.body_parts_covered & CHEST) && (equipped.clothing_flags & STOPSPRESSUREDAMAGE))
			chest_covered = TRUE
		if((equipped.body_parts_covered & HEAD) && (equipped.clothing_flags & STOPSPRESSUREDAMAGE))
			head_covered = TRUE

	if(chest_covered && head_covered)
		return ONE_ATMOSPHERE
	if(ismovable(loc))
		/// If we're in a space with 0.5 content pressure protection, it averages the values, for example.
		var/atom/movable/occupied_space = loc
		return (occupied_space.contents_pressure_protection * ONE_ATMOSPHERE + (1 - occupied_space.contents_pressure_protection) * pressure)
	return pressure

/mob/living/carbon/human/breathe(forced)
	if(HAS_TRAIT(src, TRAIT_NOBREATH))
		return FALSE

	return ..()

/mob/living/carbon/human/check_breath(datum/gas_mixture/breath, forced = FALSE)

	var/L = getorganslot(ORGAN_SLOT_LUNGS)

	if(!L)
		if(!HAS_TRAIT(src, TRAIT_NOCRITDAMAGE))
			adjustOxyLoss(HUMAN_FAILBREATH_OXYLOSS)

		failed_last_breath = TRUE

		var/datum/species/S = dna.species

		if(S.breathid == GAS_OXYGEN)
			throw_alert(ALERT_NOT_ENOUGH_OXYGEN, /atom/movable/screen/alert/not_enough_oxy)
		else if(S.breathid == GAS_PLASMA)
			throw_alert(ALERT_NOT_ENOUGH_PLASMA, /atom/movable/screen/alert/not_enough_plas)
		else if(S.breathid == GAS_CO2)
			throw_alert(ALERT_NOT_ENOUGH_CO2, /atom/movable/screen/alert/not_enough_co2)
		else if(S.breathid == GAS_NITROGEN)
			throw_alert(ALERT_NOT_ENOUGH_NITRO, /atom/movable/screen/alert/not_enough_nitro)

		return FALSE
	else
		if(istype(L, /obj/item/organ/lungs))
			var/obj/item/organ/lungs/lun = L
			var/breath_return = lun.check_breath(breath, src, forced)
			if(breath_return == BREATH_OKAY)
				adjustOxyLoss(HUMAN_OXYLOSS_RECOVERY)
				return TRUE

			if(breath_return >= BREATH_SILENT_DAMAGING) // Breath succeeded
				return TRUE

			if((breath_return == BREATH_FAILED) && !HAS_TRAIT(src, TRAIT_NOCRITDAMAGE))
				adjustOxyLoss(HUMAN_FAILBREATH_OXYLOSS)

			// Failed a breath for one reason or another.
			blur_eyes(3)
			if(prob(20) && COOLDOWN_FINISHED(src, mob_cooldowns["check_breath_gasp"]))
				spawn(-1)
					emote(/datum/emote/living/carbon/gasp_air)
					COOLDOWN_START(src, mob_cooldowns["check_breath_gasp"], 10 SECONDS)
			return FALSE

/// Environment handlers for species
/mob/living/carbon/human/handle_environment(datum/gas_mixture/environment, delta_time, times_fired)
	return dna.species.handle_environment(src, environment, delta_time, times_fired)

/**
 * Adjust the core temperature of a mob
 *
 * vars:
 * * amount The amount of degrees to change body temperature by
 * * min_temp (optional) The minimum body temperature after adjustment
 * * max_temp (optional) The maximum body temperature after adjustment
 */
/mob/living/carbon/human/proc/adjust_coretemperature(amount, min_temp=0, max_temp=INFINITY)
	set_coretemperature(clamp(coretemperature + amount, min_temp, max_temp))

/mob/living/carbon/human/proc/set_coretemperature(value)
	SEND_SIGNAL(src, COMSIG_HUMAN_CORETEMP_CHANGE, coretemperature, value)
	coretemperature = value

/**
 * get_body_temperature Returns the body temperature with any modifications applied
 *
 * This applies the result from proc/get_body_temp_normal_change() against the bodytemp_normal
 * for the species and returns the result
 *
 * arguments:
 * * apply_change (optional) Default True This applies the changes to body temperature normal
 */
/mob/living/carbon/human/get_body_temp_normal(apply_change=TRUE)
	if(!apply_change)
		return dna.species.bodytemp_normal
	return dna.species.bodytemp_normal + get_body_temp_normal_change()

/mob/living/carbon/human/get_body_temp_heat_damage_limit()
	return dna.species.heat_level_1

/mob/living/carbon/human/get_body_temp_cold_damage_limit()
	return dna.species.cold_level_1

/mob/living/carbon/human/proc/get_thermal_protection()
	var/thermal_protection = 0 //Simple check to estimate how protected we are against multiple temperatures
	if(wear_suit)
		if((wear_suit.heat_protection & CHEST) && (wear_suit.max_heat_protection_temperature >= FIRE_SUIT_MAX_TEMP_PROTECT))
			thermal_protection += (wear_suit.max_heat_protection_temperature * 0.7)
	if(head)
		if((head.heat_protection & HEAD) && (head.max_heat_protection_temperature >= FIRE_HELM_MAX_TEMP_PROTECT))
			thermal_protection += (head.max_heat_protection_temperature * THERMAL_PROTECTION_HEAD)
	thermal_protection = round(thermal_protection)
	return thermal_protection

//END FIRE CODE

//This proc returns a number made up of the flags for body parts which you are protected on. (such as HEAD, CHEST, GROIN, etc. See setup.dm for the full list)
/mob/living/carbon/human/proc/get_heat_protection_flags(temperature) //Temperature is the temperature you're being exposed to.
	var/thermal_protection_flags = 0
	//Handle normal clothing
	if(head)
		if(head.max_heat_protection_temperature && head.max_heat_protection_temperature >= temperature)
			thermal_protection_flags |= head.heat_protection
	if(wear_suit)
		if(wear_suit.max_heat_protection_temperature && wear_suit.max_heat_protection_temperature >= temperature)
			thermal_protection_flags |= wear_suit.heat_protection
	if(w_uniform)
		if(w_uniform.max_heat_protection_temperature && w_uniform.max_heat_protection_temperature >= temperature)
			thermal_protection_flags |= w_uniform.heat_protection
	if(shoes)
		if(shoes.max_heat_protection_temperature && shoes.max_heat_protection_temperature >= temperature)
			thermal_protection_flags |= shoes.heat_protection
	if(gloves)
		if(gloves.max_heat_protection_temperature && gloves.max_heat_protection_temperature >= temperature)
			thermal_protection_flags |= gloves.heat_protection
	if(wear_mask)
		if(wear_mask.max_heat_protection_temperature && wear_mask.max_heat_protection_temperature >= temperature)
			thermal_protection_flags |= wear_mask.heat_protection

	return thermal_protection_flags

/mob/living/carbon/human/get_heat_protection(temperature)
	var/thermal_protection_flags = get_heat_protection_flags(temperature)
	var/thermal_protection = heat_protection

	// Apply clothing items protection
	if(thermal_protection_flags)
		if(thermal_protection_flags & HEAD)
			thermal_protection += THERMAL_PROTECTION_HEAD
		if(thermal_protection_flags & CHEST)
			thermal_protection += THERMAL_PROTECTION_CHEST
		if(thermal_protection_flags & GROIN)
			thermal_protection += THERMAL_PROTECTION_GROIN
		if(thermal_protection_flags & LEG_LEFT)
			thermal_protection += THERMAL_PROTECTION_LEG_LEFT
		if(thermal_protection_flags & LEG_RIGHT)
			thermal_protection += THERMAL_PROTECTION_LEG_RIGHT
		if(thermal_protection_flags & FOOT_LEFT)
			thermal_protection += THERMAL_PROTECTION_FOOT_LEFT
		if(thermal_protection_flags & FOOT_RIGHT)
			thermal_protection += THERMAL_PROTECTION_FOOT_RIGHT
		if(thermal_protection_flags & ARM_LEFT)
			thermal_protection += THERMAL_PROTECTION_ARM_LEFT
		if(thermal_protection_flags & ARM_RIGHT)
			thermal_protection += THERMAL_PROTECTION_ARM_RIGHT
		if(thermal_protection_flags & HAND_LEFT)
			thermal_protection += THERMAL_PROTECTION_HAND_LEFT
		if(thermal_protection_flags & HAND_RIGHT)
			thermal_protection += THERMAL_PROTECTION_HAND_RIGHT

	return min(1, thermal_protection)

//See proc/get_heat_protection_flags(temperature) for the description of this proc.
/mob/living/carbon/human/proc/get_cold_protection_flags(temperature)
	var/thermal_protection_flags = 0
	//Handle normal clothing

	if(head)
		if(head.min_cold_protection_temperature && head.min_cold_protection_temperature <= temperature)
			thermal_protection_flags |= head.cold_protection
	if(wear_suit)
		if(wear_suit.min_cold_protection_temperature && wear_suit.min_cold_protection_temperature <= temperature)
			thermal_protection_flags |= wear_suit.cold_protection
	if(w_uniform)
		if(w_uniform.min_cold_protection_temperature && w_uniform.min_cold_protection_temperature <= temperature)
			thermal_protection_flags |= w_uniform.cold_protection
	if(shoes)
		if(shoes.min_cold_protection_temperature && shoes.min_cold_protection_temperature <= temperature)
			thermal_protection_flags |= shoes.cold_protection
	if(gloves)
		if(gloves.min_cold_protection_temperature && gloves.min_cold_protection_temperature <= temperature)
			thermal_protection_flags |= gloves.cold_protection
	if(wear_mask)
		if(wear_mask.min_cold_protection_temperature && wear_mask.min_cold_protection_temperature <= temperature)
			thermal_protection_flags |= wear_mask.cold_protection

	return thermal_protection_flags

/mob/living/carbon/human/get_cold_protection(temperature)
	// There is an occasional bug where the temperature is miscalculated in areas with small amounts of gas.
	// This is necessary to ensure that does not affect this calculation.
	// Space's temperature is 2.7K and most suits that are intended to protect against any cold, protect down to 2.0K.
	temperature = max(temperature, 2.7)
	var/thermal_protection_flags = get_cold_protection_flags(temperature)
	var/thermal_protection = cold_protection

	// Apply clothing items protection
	if(thermal_protection_flags)
		if(thermal_protection_flags & HEAD)
			thermal_protection += THERMAL_PROTECTION_HEAD
		if(thermal_protection_flags & CHEST)
			thermal_protection += THERMAL_PROTECTION_CHEST
		if(thermal_protection_flags & GROIN)
			thermal_protection += THERMAL_PROTECTION_GROIN
		if(thermal_protection_flags & LEG_LEFT)
			thermal_protection += THERMAL_PROTECTION_LEG_LEFT
		if(thermal_protection_flags & LEG_RIGHT)
			thermal_protection += THERMAL_PROTECTION_LEG_RIGHT
		if(thermal_protection_flags & FOOT_LEFT)
			thermal_protection += THERMAL_PROTECTION_FOOT_LEFT
		if(thermal_protection_flags & FOOT_RIGHT)
			thermal_protection += THERMAL_PROTECTION_FOOT_RIGHT
		if(thermal_protection_flags & ARM_LEFT)
			thermal_protection += THERMAL_PROTECTION_ARM_LEFT
		if(thermal_protection_flags & ARM_RIGHT)
			thermal_protection += THERMAL_PROTECTION_ARM_RIGHT
		if(thermal_protection_flags & HAND_LEFT)
			thermal_protection += THERMAL_PROTECTION_HAND_LEFT
		if(thermal_protection_flags & HAND_RIGHT)
			thermal_protection += THERMAL_PROTECTION_HAND_RIGHT

	return min(1, thermal_protection)

/mob/living/carbon/human/handle_random_events(delta_time, times_fired)
	//Puke if toxloss is too high
	if(stat)
		return
	if(getToxLoss() < 45 || nutrition <= 20)
		return

	lastpuke += DT_PROB(30, delta_time)
	if(lastpuke >= 50) // about 25 second delay I guess // This is actually closer to 150 seconds
		vomit(20)
		lastpuke = 0


/mob/living/carbon/human/has_smoke_protection()
	if(isclothing(wear_mask))
		if(wear_mask.clothing_flags & BLOCK_GAS_SMOKE_EFFECT)
			return TRUE
	if(isclothing(glasses))
		if(glasses.clothing_flags & BLOCK_GAS_SMOKE_EFFECT)
			return TRUE
	if(isclothing(head))
		var/obj/item/clothing/CH = head
		if(CH.clothing_flags & BLOCK_GAS_SMOKE_EFFECT)
			return TRUE
	return ..()

/mob/living/carbon/human/set_heartattack(status)
	. = ..()
	if(.)
		update_health_hud()

#undef THERMAL_PROTECTION_HEAD
#undef THERMAL_PROTECTION_CHEST
#undef THERMAL_PROTECTION_GROIN
#undef THERMAL_PROTECTION_LEG_LEFT
#undef THERMAL_PROTECTION_LEG_RIGHT
#undef THERMAL_PROTECTION_FOOT_LEFT
#undef THERMAL_PROTECTION_FOOT_RIGHT
#undef THERMAL_PROTECTION_ARM_LEFT
#undef THERMAL_PROTECTION_ARM_RIGHT
#undef THERMAL_PROTECTION_HAND_LEFT
#undef THERMAL_PROTECTION_HAND_RIGHT
