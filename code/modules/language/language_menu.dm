/datum/language_menu
	var/datum/language_holder/language_holder

/datum/language_menu/New(_language_holder)
	language_holder = _language_holder

/datum/language_menu/Destroy()
	language_holder = null
	. = ..()

/datum/language_menu/ui_state(mob/user)
	return GLOB.language_menu_state

/datum/language_menu/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "LanguageMenu")
		ui.open()

/datum/language_menu/ui_data(mob/user)
	var/list/data = list()

	var/atom/movable/AM = language_holder.get_atom()
	if(isliving(AM))
		data["is_living"] = TRUE
	else
		data["is_living"] = FALSE

	data["languages"] = list()
	for(var/datum/language/language as anything in GLOB.all_languages)
		var/result = language_holder.has_language(language) || language_holder.has_language(language, TRUE)
		if(!result)
			continue
		var/list/L = list()

		L["name"] = initial(language.name)
		L["desc"] = initial(language.desc)
		L["key"] = initial(language.key)
		L["is_default"] = (language == language_holder.selected_language)
		if(AM)
			L["can_speak"] = AM.can_speak_language(language)
			L["can_understand"] = AM.has_language(language)

		data["languages"] += list(L)

	if(check_rights_for(user.client, R_ADMIN) || isobserver(AM))
		data["admin_mode"] = TRUE
		data["omnitongue"] = language_holder.bypass_speaking_limitations

		data["unknown_languages"] = list()
		for(var/datum/language/language as anything in GLOB.all_languages)
			if(language_holder.has_language(language) || language_holder.has_language(language, TRUE))
				continue
			var/list/L = list()

			L["name"] = language.name
			L["desc"] = language.desc
			L["key"] = language.key

			data["unknown_languages"] += list(L)
	return data

/datum/language_menu/ui_act(action, params)
	. = ..()
	if(.)
		return
	var/mob/user = usr
	var/atom/movable/AM = language_holder.get_atom()

	var/language_name = params["language_name"]
	var/datum/language/language_datum

	for(var/datum/language/language as anything in GLOB.all_languages)
		if(language_name == language.name)
			language_datum = language

	var/is_admin = check_rights_for(user.client, R_ADMIN)

	switch(action)
		if("select_default")
			if(language_datum && AM.can_speak_language(language_datum))
				language_holder.set_selected_language(language_datum)
				. = TRUE
		if("grant_language")
			if((is_admin || isobserver(AM)) && language_datum)
				var/list/choices = list("Only Spoken", "Only Understood", "Both")
				var/choice = tgui_input_list(user, "How do you want to add this language?", "[language_datum]", choices)
				if(isnull(choice))
					return
				var/spoken = FALSE
				var/understood = FALSE
				switch(choice)
					if("Only Spoken")
						spoken = TRUE
					if("Only Understood")
						understood = TRUE
					if("Both")
						spoken = TRUE
						understood = TRUE
				if(language_holder.blocked_languages && language_holder.blocked_languages[language_datum])
					choice = tgui_alert(user, "Do you want to lift the blockage that's also preventing the language to be spoken or understood?", "[language_datum]", list("Yes", "No"))
					if(choice == "Yes")
						language_holder.remove_blocked_language(language_datum, LANGUAGE_ALL)
				language_holder.grant_language(language_datum, understood, spoken)
				if(is_admin)
					message_admins("[key_name_admin(user)] granted the [language_name] language to [key_name_admin(AM)].")
					log_admin("[key_name(user)] granted the language [language_name] to [key_name(AM)].")
				. = TRUE
		if("remove_language")
			if((is_admin || isobserver(AM)) && language_datum)
				var/list/choices = list("Only Spoken", "Only Understood", "Both")
				var/choice = tgui_input_list(user, "Which part do you wish to remove?", "[language_datum]", choices)
				if(isnull(choice))
					return
				var/spoken = FALSE
				var/understood = FALSE
				switch(choice)
					if("Only Spoken")
						spoken = TRUE
					if("Only Understood")
						understood = TRUE
					if("Both")
						spoken = TRUE
						understood = TRUE
				language_holder.remove_language(language_datum, understood, spoken)
				if(is_admin)
					message_admins("[key_name_admin(user)] removed the [language_name] language to [key_name_admin(AM)].")
					log_admin("[key_name(user)] removed the language [language_name] to [key_name(AM)].")
				. = TRUE
		if("toggle_omnitongue")
			if(is_admin || isobserver(AM))
				language_holder.bypass_speaking_limitations = !language_holder.bypass_speaking_limitations
				if(is_admin)
					message_admins("[key_name_admin(user)] [language_holder.bypass_speaking_limitations ? "enabled" : "disabled"] the ability to speak all languages (that they know) of [key_name_admin(AM)].")
					log_admin("[key_name(user)] [language_holder.bypass_speaking_limitations ? "enabled" : "disabled"] the ability to speak all languages (that_they know) of [key_name(AM)].")
				. = TRUE
