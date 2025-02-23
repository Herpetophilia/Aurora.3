#define HEAT_CAPACITY_HUMAN 100 //249840 J/K, for a 72 kg person.

/obj/machinery/atmospherics/unary/cryo_cell
	name = "cryo cell"
	desc = "A cryogenic chamber that can freeze occupants while keeping them alive, preventing them from taking any further damage. It can be loaded with a chemical cocktail for various medical benefits."
	desc_info = "The cryogenic chamber, or 'cryo', treats most damage types, most notably genetic damage. It also stabilizes patients \
	in critical condition by placing them in stasis, so they can be treated at a later time.<br>\
	<br>\
	In order for it to work, it must be loaded with chemicals, and the temperature of the solution must reach a certain point. Additionally, it \
	requires a supply of pure oxygen, provided by canisters that are attached. The most commonly used chemicals in the chambers are Cryoxadone and \
	Clonexadone. Clonexadone is more effective in treating all damage, including Genetic damage, but is otherwise functionally identical.<br>\
	<br>\
	Activating the freezer nearby, and setting it to a temperature setting below 150, is recommended before operation! Further, any clothing the patient \
	is wearing that act as an insulator will reduce its effectiveness, and should be removed.<br>\
	<br>\
	Clicking the tube with a beaker full of chemicals in hand will place it in its storage to distribute when it is activated.<br>\
	<br>\
	Click your target with Grab intent, then click on the tube, with an empty hand, to place them in it. Click the tube again to open the menu. \
	Press the button on the menu to activate it. Once they have reached 100 health, right-click the cell and click 'Eject Occupant' to remove them. \
	Remember to turn it off, once you've finished, to save power and chemicals!"
	icon = 'icons/obj/cryogenics.dmi' // map only
	icon_state = "pod_preview"
	density = TRUE
	anchored = TRUE
	layer = 2.8
	interact_offline = TRUE

	var/on = 0
	idle_power_usage = 20
	active_power_usage = 200
	clicksound = 'sound/machines/buttonbeep.ogg'
	clickvol = 30

	var/temperature_archived
	var/mob/living/carbon/human/occupant = null
	var/obj/item/reagent_containers/glass/beaker = null

	var/current_heat_capacity = 50

/obj/machinery/atmospherics/unary/cryo_cell/New()
	..()
	icon = 'icons/obj/cryogenics_split.dmi'
	update_icon()
	initialize_directions = dir

/obj/machinery/atmospherics/unary/cryo_cell/Destroy()
	var/turf/T = loc
	T.contents += contents
	if(beaker)
		beaker.forceMove(get_step(loc, SOUTH)) //Beaker is carefully ejected from the wreckage of the cryotube
	return ..()

/obj/machinery/atmospherics/unary/cryo_cell/atmos_init()
	if(node) return
	var/node_connect = dir
	for(var/obj/machinery/atmospherics/target in get_step(src,node_connect))
		if(target.initialize_directions & get_dir(target,src))
			node = target
			break

/obj/machinery/atmospherics/unary/cryo_cell/process()
	..()
	if(!node)
		return
	if(!on)
		return

	if(occupant)
		if(occupant.stat != 2)
			process_occupant()

	if(air_contents)
		temperature_archived = air_contents.temperature
		heat_gas_contents()
		expel_gas()

	if(abs(temperature_archived-air_contents.temperature) > 1)
		network.update = 1

	return 1

/obj/machinery/atmospherics/unary/cryo_cell/relaymove(mob/user as mob)
	if(user != occupant) //Put this in because apparently if you open the ui and press a button, you're counted as user and can trigger relaymove, this checks if you're inside, and if you aren't it ignores you for the purposes of the relaymove. - Risingvaliant
		return
	if(user.stat)
		return
	go_out()
	return

/obj/machinery/atmospherics/unary/cryo_cell/attack_hand(mob/user)
	ui_interact(user)

 /**
  * The ui_interact proc is used to open and update Nano UIs
  * If ui_interact is not used then the UI will not update correctly
  * ui_interact is currently defined for /atom/movable (which is inherited by /obj and /mob)
  *
  * @param user /mob The mob who is interacting with this ui
  * @param ui_key string A string key to use for this ui. Allows for multiple unique uis on one obj/mob (defaut value "main")
  * @param ui /datum/nanoui This parameter is passed by the nanoui process() proc when updating an open ui
  *
  * @return nothing
  */
/obj/machinery/atmospherics/unary/cryo_cell/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = 1)

	if(user == occupant || user.stat)
		return

	// this is the data which will be sent to the ui
	var/list/data = list()
	data["isOperating"] = on
	data["hasOccupant"] = occupant ? 1 : 0

	var/list/occupantData = list()
	if (occupant)
		occupantData["name"] = occupant.name
		occupantData["stat"] = occupant.stat
		occupantData["bodyTemperature"] = occupant.bodytemperature
		occupantData["brain_activity"] = occupant.get_brain_status()
		occupantData["pulse"] = occupant.get_pulse(GETPULSE_TOOL)
		occupantData["blood_o2"] = occupant.get_blood_oxygenation()
		occupantData["blood_pressure"] = occupant.get_blood_pressure()
		occupantData["cloneLoss"] = occupant.getCloneLoss()
		occupantData["bruteLoss"] = occupant.getBruteLoss()
		occupantData["fireLoss"] = occupant.getFireLoss()
		occupantData["toxLoss"] = occupant.getToxLoss()
		occupantData["oxyLoss"] = occupant.getOxyLoss()
		occupantData["cryostasis"] = "[occupant.stasis_value]"
	data["occupant"] = occupantData

	data["cellTemperature"] = round(air_contents.temperature)
	data["cellTemperatureStatus"] = "good"
	if(air_contents.temperature > T0C) // if greater than 273.15 kelvin (0 celcius)
		data["cellTemperatureStatus"] = "bad"
	else if(air_contents.temperature > 225)
		data["cellTemperatureStatus"] = "average"

	data["isBeakerLoaded"] = beaker ? 1 : 0
	data["beakerLabel"] = null
	data["beakerVolume"] = 0
	if(beaker)
		data["beakerLabel"] = beaker.label_text ? beaker.label_text : null
		for(var/_R in beaker.reagents.reagent_volumes)
			data["beakerVolume"] += REAGENT_VOLUME(beaker.reagents, _R)

	// update the ui if it exists, returns null if no ui is passed/found
	ui = SSnanoui.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		ui = new(user, src, ui_key, "cryo.tmpl", "Cryo Cell Control System", 520, 410)
		ui.set_initial_data(data)
		ui.open()
		ui.set_auto_update(1)

/obj/machinery/atmospherics/unary/cryo_cell/Topic(href, href_list)
	if(usr == occupant)
		return 0 // don't update UIs attached to this object

	if(..())
		return 0 // don't update UIs attached to this object

	if(href_list["switchOn"])
		on = 1
		update_icon()

	if(href_list["switchOff"])
		on = 0
		update_icon()

	if(href_list["ejectBeaker"])
		if(beaker)
			beaker.forceMove(get_step(loc, SOUTH))
			beaker = null

	if(href_list["ejectOccupant"])
		if(!occupant || isslime(usr) || ispAI(usr))
			return 0 // don't update UIs attached to this object
		go_out()

	add_fingerprint(usr)
	return 1 // update UIs attached to this object

/obj/machinery/atmospherics/unary/cryo_cell/attackby(var/obj/item/G as obj, var/mob/user as mob)
	if(istype(G, /obj/item/reagent_containers/glass))
		if(beaker)
			to_chat(user, "<span class='warning'>A beaker is already loaded into the machine.</span>")
			return TRUE

		beaker =  G
		user.drop_from_inventory(G,src)
		user.visible_message("[user] adds \a [G] to \the [src]!", "You add \a [G] to \the [src]!")
	else if(istype(G, /obj/item/grab))
		var/obj/item/grab/grab = G
		var/mob/living/L = grab.affecting

		if (!istype(L))
			return

		var/bucklestatus = L.bucklecheck(user)
		if(!bucklestatus)
			return TRUE

		user.visible_message("<span class='notice'>[user] starts putting [L] into [src].</span>", "<span class='notice'>You start putting [L] into [src].</span>", range = 3)
		if(do_mob(user, L, 30, needhand = 0))
			for(var/mob/living/carbon/slime/M in range(1, L))
				if(M.victim == L)
					to_chat(user, SPAN_WARNING("[L] will not fit into the cryo because they have a slime latched onto their head."))
					return TRUE
			if(put_mob(L))
				user.visible_message("<span class='notice'>[user] puts [L] into [src].</span>", "<span class='notice'>You put [L] into [src].</span>", range = 3)
				qdel(G)
	return TRUE

/obj/machinery/atmospherics/unary/cryo_cell/MouseDrop_T(atom/movable/O as mob|obj, mob/living/user as mob)
	if(!istype(user))
		return
	if(!ismob(O))
		return
	var/mob/living/L = O
	for(var/mob/living/carbon/slime/M in range(1,L))
		if(M.victim == L)
			to_chat(usr, SPAN_WARNING("[L.name] will not fit into the cryo because they have a slime latched onto their head."))
			return

	var/bucklestatus = L.bucklecheck(user)
	if (!bucklestatus)
		return

	if(L == user)
		user.visible_message("<span class='notice'>[user] starts climbing into [src].</span>", "<span class='notice'>You start climbing into [src].</span>", range = 3)
	else
		user.visible_message("<span class='notice'>[user] starts putting [L] into the cryopod.</span>", "<span class='notice'>You start putting [L] into [src].</span>", range = 3)
	if (do_mob(user, L, 30, needhand = 0))
		if (bucklestatus == 2)
			var/obj/structure/LB = L.buckled_to
			LB.user_unbuckle(user)
		if(put_mob(L))
			if(L == user)
				user.visible_message("<span class='notice'>[user] climbs into [src].</span>", "<span class='notice'>You climb into [src].</span>", range = 3)
			else
				user.visible_message("<span class='notice'>[user] puts [L] into [src].</span>", "<span class='notice'>You put [L] into [src].</span>", range = 3)
				if(user.pulling == L)
					user.pulling = null

/obj/machinery/atmospherics/unary/cryo_cell/update_icon()
	cut_overlays()
	var/list/ovr = list()
	icon_state = "pod[on]"
	var/image/I

	I = image(icon, "pod[on]_top")
	I.layer = 5 // this needs to be fairly high so it displays over most things, but it needs to be under lighting (at 10)
	I.pixel_z = 32
	ovr += I

	if(occupant)
		var/image/pickle = image(occupant.icon, occupant.icon_state)
		pickle.overlays = occupant.overlays
		pickle.pixel_z = 18
		pickle.layer = 5
		ovr += pickle

	I = image(icon, "lid[on]")
	I.layer = 5
	ovr += I

	I = image(icon, "lid[on]_top")
	I.layer = 5
	I.pixel_z = 32
	ovr += I

	add_overlay(ovr)

/obj/machinery/atmospherics/unary/cryo_cell/proc/process_occupant()
	if(air_contents.total_moles < 10)
		return
	if(occupant)
		if(occupant.stat == 2)
			return
		occupant.bodytemperature += 2*(air_contents.temperature - occupant.bodytemperature)*current_heat_capacity/(current_heat_capacity + air_contents.heat_capacity())
		occupant.bodytemperature = max(occupant.bodytemperature, air_contents.temperature) // this is so ugly i'm sorry for doing it i'll fix it later i promise
		occupant.set_stat(UNCONSCIOUS)
		if(occupant.bodytemperature < T0C)
			//severe damage should heal waaay slower without proper chemicals
			if(occupant.bodytemperature < 225)
				if(!occupant.is_diona())
					var/heal_brute = occupant.getBruteLoss() ? min(1, 20/occupant.getBruteLoss()) : 0
					var/heal_fire = occupant.getFireLoss() ? min(1, 20/occupant.getFireLoss()) : 0
					occupant.heal_organ_damage(heal_brute,heal_fire)
				else
					occupant.adjustFireLoss(3)//Cryopods kill diona. This damage combines with the normal cold temp damage, and their disabled regen
		var/has_cryo = REAGENT_VOLUME(occupant.reagents, /singleton/reagent/cryoxadone) >= 1
		var/has_clonexa = REAGENT_VOLUME(occupant.reagents, /singleton/reagent/clonexadone) >= 1
		var/has_cryo_medicine = has_cryo || has_clonexa
		if(beaker && !has_cryo_medicine)
			beaker.reagents.trans_to_mob(occupant, 1, CHEM_BLOOD)

/obj/machinery/atmospherics/unary/cryo_cell/proc/heat_gas_contents()
	if(air_contents.total_moles < 1)
		return
	var/air_heat_capacity = air_contents.heat_capacity()
	var/combined_heat_capacity = current_heat_capacity + air_heat_capacity
	if(combined_heat_capacity > 0)
		var/combined_energy = T20C*current_heat_capacity + air_heat_capacity*air_contents.temperature
		air_contents.temperature = combined_energy/combined_heat_capacity

/obj/machinery/atmospherics/unary/cryo_cell/proc/expel_gas()
	if(air_contents.total_moles < 1)
		return
//	var/datum/gas_mixture/expel_gas = new
//	var/remove_amount = air_contents.total_moles()/50
//	expel_gas = air_contents.remove(remove_amount)

	// Just have the gas disappear to nowhere.
	//expel_gas.temperature = T20C // Lets expel hot gas and see if that helps people not die as they are removed
	//loc.assume_air(expel_gas)

/obj/machinery/atmospherics/unary/cryo_cell/proc/go_out()
	if(!( occupant ))
		return
	//for(var/obj/O in src)
	//	O.forceMove(loc)
	if (occupant.client)
		occupant.client.eye = occupant.client.mob
		occupant.client.perspective = MOB_PERSPECTIVE
	occupant.forceMove(get_step(loc, SOUTH))	//this doesn't account for walls or anything, but i don't forsee that being a problem.
	if (occupant.bodytemperature < 261 && occupant.bodytemperature >= 70) //Patch by Aranclanos to stop people from taking burn damage after being ejected
		occupant.bodytemperature = 261									  // Changed to 70 from 140 by Zuhayr due to reoccurance of bug.
	occupant = null
	current_heat_capacity = initial(current_heat_capacity)
	update_use_power(POWER_USE_IDLE)
	update_icon()

/obj/machinery/atmospherics/unary/cryo_cell/proc/put_mob(mob/living/carbon/human/M as mob)
	if (stat & (NOPOWER|BROKEN))
		to_chat(usr, "<span class='warning'>The cryo cell is not functioning.</span>")
		return
	if (!istype(M))
		to_chat(usr, "<span class='danger'>The cryo cell cannot handle such a lifeform!</span>")
		return
	if (occupant)
		to_chat(usr, "<span class='danger'>The cryo cell is already occupied!</span>")
		return
	if (M.abiotic())
		to_chat(usr, "<span class='warning'>Subject may not have abiotic items on.</span>")
		return
	if(!node)
		to_chat(usr, "<span class='warning'>The cell is not correctly connected to its pipe network!</span>")
		return
	if (M.client)
		M.client.perspective = EYE_PERSPECTIVE
		M.client.eye = src
	M.stop_pulling()
	M.forceMove(src)
	M.ExtinguishMob()
	if(M.health > -100 && (M.health < 0 || M.sleeping))
		to_chat(M, "<span class='notice'><b>You feel a cold liquid surround you. Your skin starts to freeze up.</b></span>")
	occupant = M
	current_heat_capacity = HEAT_CAPACITY_HUMAN
	update_use_power(POWER_USE_ACTIVE)
//	M.metabslow = 1
	add_fingerprint(usr)
	update_icon()
	return 1

/obj/machinery/atmospherics/unary/cryo_cell/verb/move_eject()
	set name = "Eject occupant"
	set category = "Object"
	set src in oview(1)
	if(usr == occupant)//If the user is inside the tube...
		if (usr.stat == 2)//and he's not dead....
			return
		to_chat(usr, "<span class='notice'>Release sequence activated. This will take two minutes.</span>")
		sleep(1200)
		if(!src || !usr || !occupant || (occupant != usr)) //Check if someone's released/replaced/bombed him already
			return
		go_out()//and release him from the eternal prison.
	else
		if (usr.stat != 0)
			return
		go_out()
	add_fingerprint(usr)
	return

/obj/machinery/atmospherics/unary/cryo_cell/verb/move_inside()
	set name = "Move Inside"
	set category = "Object"
	set src in oview(1)
	for(var/mob/living/carbon/slime/M in range(1,usr))
		if(M.victim == usr)
			to_chat(usr, SPAN_WARNING("You cannot do this while a slime is latched onto you!"))
			return
	if (usr.stat != 0)
		return
	usr.visible_message("<span class='notice'>[usr] climbs into [src].</span>", "<span class='notice'>You climb into [src].</span>", range = 3)
	put_mob(usr)
	return

/atom/proc/return_air_for_internal_lifeform(var/mob/living/lifeform)
	return return_air()

/obj/machinery/atmospherics/unary/cryo_cell/return_air_for_internal_lifeform()
	//assume that the cryo cell has some kind of breath mask or something that
	//draws from the cryo tube's environment, instead of the cold internal air.
	if(loc)
		return loc.return_air()

/datum/data/function/proc/reset()
	return

/datum/data/function/proc/r_input(href, href_list, mob/user as mob)
	return

/datum/data/function/proc/display()
	return

#undef HEAT_CAPACITY_HUMAN
