/datum/controller/subsystem/ping
	name = "Ping"
	priority = SS_PRIORITY_PING
	init_order = SS_INIT_PING
	wait = 4 SECONDS
	flags = SS_NO_INIT
	runlevels = RUNLEVEL_INIT | RUNLEVEL_LOBBY | RUNLEVEL_SETUP | RUNLEVEL_GAME | RUNLEVEL_POSTGAME
	init_stage = INITSTAGE_EARLY

	var/list/currentrun = list()

/datum/controller/subsystem/ping/stat_entry(msg)
	msg = "P:[clients.len]"
	return ..()

/datum/controller/subsystem/ping/fire(resumed = FALSE)
	// Prepare the new batch of clients
	if (!resumed)
		src.currentrun = clients.Copy()

	// De-reference the list for sanic speeds
	var/list/currentrun = src.currentrun

	while (currentrun.len)
		var/client/client = currentrun[currentrun.len]
		currentrun.len--

		if (client?.tgui_panel?.is_ready())
			// Send a soft ping
			client.tgui_panel.window.send_message("ping/soft", list(
				// Slightly less than the subsystem timer (somewhat arbitrary)
				// to prevent incoming pings from resetting the afk state
				"afk" = client.is_afk(3.5 SECONDS),
			))

		if (MC_TICK_CHECK)
			return
