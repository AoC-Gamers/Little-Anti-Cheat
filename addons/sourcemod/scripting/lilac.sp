/*
	Little Anti-Cheat
	Copyright (C) 2018-2023 J_Tanzanite

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

/* Uncomment below line to compile for Team Fortress 2 Classic.
 * You'll need SourceMod 1.10 and SM-TF2Clasic-Tools to compile, if you decide to.
 * Note: Doing so means the compiled plugin won't work correctly
 * for other source games. 
 * SourceMod 1.10: https://www.sourcemod.net/downloads.php?branch=1.10-dev
 * SM-TF2Clasic-Tools: https://github.com/tf2classic/SM-TF2Classic-Tools */
//#define TF2C

#include <sourcemod>
#include <sdktools_engine>
#include <sdktools_entoutput>
#include <convar_class>
#include <lilac>

#undef REQUIRE_PLUGIN /* ... */
#undef REQUIRE_EXTENSIONS
#if defined TF2C
	#include <tf2c>
#else
	#include <tf2>
	#include <tf2_stocks>
#endif
#define REQUIRE_PLUGIN
#define REQUIRE_EXTENSIONS

#pragma semicolon 1
#pragma newdecls required

#include "lilac/lilac_globals.sp" /* Must be at top, contains defines. */

#include "lilac/lilac_aimbot.sp"
#include "lilac/lilac_aimlock.sp"
#include "lilac/lilac_angles.sp"
#include "lilac/lilac_backtrack.sp"
#include "lilac/lilac_bhop.sp"
#include "lilac/lilac_config.sp"
#include "lilac/lilac_convar.sp"
#include "lilac/lilac_database.sp"
#include "lilac/lilac_lerp.sp"
#include "lilac/lilac_macro.sp"
#include "lilac/lilac_noisemaker.sp"
#include "lilac/lilac_ping.sp"
#include "lilac/lilac_stock.sp"
#include "lilac/lilac_string.sp" /* String takes care of chat and names. */


public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESC,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};


public void OnPluginStart()
{
	LoadTranslations("lilac.phrases.txt");
	aim_suspicion_records = new ArrayList(sizeof(AimSuspicionRecord));
	aim_transition_carry_accounts = new ArrayList();
	aim_legacy_detections = new ArrayList(sizeof(AimLegacyDetection));

#if defined TF2C
	ggame = GAME_TF2;
	/* Post inventory check isn't needed,
	 * as noisemaker spam isn't a thing in TF2Classic. */
	HookEvent("player_teleported", event_teleported, EventHookMode_Post);
	HookEvent("player_death", event_player_death_tf2, EventHookMode_Pre);
#else
	char gamefolder[32];
	GetGameFolderName(gamefolder, sizeof(gamefolder));
	if (StrEqual(gamefolder, "tf", false)) {
		ggame = GAME_TF2;

		HookEvent("post_inventory_application", event_inventoryupdate, EventHookMode_Post);
		HookEvent("player_teleported", event_teleported, EventHookMode_Post);
	}
	else if (StrEqual(gamefolder, "cstrike", false)) {
		ggame = GAME_CSS;
	}
	else if (StrEqual(gamefolder, "left4dead2", false)) {
		ggame = GAME_L4D2;
		HookEvent("map_transition", event_map_transition, EventHookMode_PostNoCopy);
	}
	else if (StrEqual(gamefolder, "left4dead", false)) {
		ggame = GAME_L4D;
	}
	else if (StrEqual(gamefolder, "dod", false)) {
		ggame = GAME_DODS;
	}
	else {
		ggame = GAME_UNKNOWN;
		PrintToServer("[Lilac] This game currently isn't supported, Little Anti-Cheat will still run, but expect some bugs and false positives/bans!");
	}

	if (ggame == GAME_TF2)
		HookEvent("player_death", event_player_death_tf2, EventHookMode_Pre);
	else
		HookEvent("player_death", event_player_death, EventHookMode_Pre);
#endif /* TF2C check. */

	HookEvent("player_spawn", event_teleported, EventHookMode_Post);
	HookEvent("player_changename", event_namechange, EventHookMode_Post);

	HookEntityOutput("trigger_teleport", "OnEndTouch", map_teleport);

	/* Default ban lengths are -1. (Global ConVar). */
	for (int i = 0; i < CHEAT_MAX; i++)
		ban_length_overwrite[i] = -1;

	/* Bans for Bhop last 1 month by default. */
	ban_length_overwrite[CHEAT_BHOP] = 24 * 30 * 60;

	/* Bans for Macros are 15 minutes by default. */
	ban_length_overwrite[CHEAT_MACRO] = 15;

	/* If sv_maxupdaterate is changed mid-game and then this plugin
	 * is loaded, then it could lead to false positives.
	 * Reset all stats on all players already in-game, but ignore lerp.
	 * Also check players already in-game for noisemaker. */
	for (int i = 1; i <= MaxClients; i++) {
		lilac_reset_client(i);
		lilac_lerp_ignore_nolerp_client(i);
#if !defined TF2C
		check_inventory_for_noisemaker(i);
#endif
	}

	forwardhandle = CreateGlobalForward("lilac_cheater_detected",
		ET_Ignore, Param_Cell, Param_Cell);
	forwardhandleban = CreateGlobalForward("lilac_cheater_banned",
		ET_Ignore, Param_Cell, Param_Cell);
	forwardhandleaimtrackingstarted = CreateGlobalForward("lilac_aim_tracking_started",
		ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_String);
	forwardhandleaimtrackingended = CreateGlobalForward("lilac_aim_tracking_ended",
		ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_String, Param_Cell);
	forwardhandleallow = CreateGlobalForward("lilac_allow_cheat_detection",
		ET_Event, Param_Cell, Param_Cell);

	CreateTimer(QUERY_TIMER, timer_query, _, TIMER_REPEAT);
	CreateTimer(5.0, timer_check_ping, _, TIMER_REPEAT);
	CreateTimer(5.0, timer_check_lerp, _, TIMER_REPEAT);
	CreateTimer(0.5, timer_check_aimlock, _, TIMER_REPEAT);
	CreateTimer(60.0 * 5.0, timer_decrement_macro, _, TIMER_REPEAT);

	tick_rate = RoundToNearest(1.0 / GetTickInterval());

	/* Ignore low tickrates. */
	macro_max = (tick_rate >= 60 && tick_rate <= MACRO_LOG_LENGTH) ? 20 : 0;

	if (tick_rate > 50) {
		bhop_settings_min[BHOP_INDEX_MIN] = 5;
		bhop_settings_min[BHOP_INDEX_MAX] = 10;
		bhop_settings_min[BHOP_INDEX_TOTAL] = 1;
	}
	else {
		bhop_settings_min[BHOP_INDEX_MIN] = 10;
		bhop_settings_min[BHOP_INDEX_MAX] = 20;
		bhop_settings_min[BHOP_INDEX_TOTAL] = 3;
	}
	bhop_settings_min[BHOP_INDEX_JUMP] = -1;
	bhop_settings_min[BHOP_INDEX_AIR] = 0;

	/* This sets up convars and such. */
	lilac_config_setup();

	if (icvar[CVAR_LOG])
		lilac_log_first_time_setup();
}

public void OnAllPluginsLoaded()
{
	sourcebanspp_exist = LibraryExists("sourcebans++");
	sourcebans_exist = LibraryExists("sourcebans");
	materialadmin_exist = LibraryExists("materialadmin");
	bansystem_exist = LibraryExists("bansystem_access");

	/* Startup message. */
	PrintToServer("[Little Anti-Cheat %s] Successfully loaded!", PLUGIN_VERSION);
}

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int err_max)
{
	RegPluginLibrary("lilac");

	CreateNative("lilac_GetDetectedInfos", lilac_native_get_detected_infos);
	CreateNative("lilac_IsAimTracking", lilac_native_is_aim_tracking);
	CreateNative("lilac_GetAimTrackingCount", lilac_native_get_aim_tracking_count);
	CreateNative("lilac_GetAimTrackingInfo", lilac_native_get_aim_tracking_info);

	/* Been told this isn't needed, but just in case. */
	MarkNativeAsOptional("SBBanPlayer");
	MarkNativeAsOptional("SBPP_BanPlayer");
	MarkNativeAsOptional("MABanPlayer");
	MarkNativeAsOptional("BSAccess_RequestLilacBan");
	MarkNativeAsOptional("IRC_MsgFlaggedChannels");

	/* Build the log path for the file in case the user has overridden sm_basepath. */
	BuildPath(Path_SM, log_file, sizeof(log_file), "logs/lilac.log");
	return APLRes_Success;
}

public void OnLibraryAdded(const char []name)
{
	if (StrEqual(name, "sourcebans++"))
		sourcebanspp_exist = true;
	else if (StrEqual(name, "sourcebans"))
		sourcebans_exist = true;
	else if (StrEqual(name, "materialadmin"))
		materialadmin_exist = true;
	else if (StrEqual(name, "bansystem_access"))
		bansystem_exist = true;
}

public void OnLibraryRemoved(const char []name)
{
	if (StrEqual(name, "sourcebans++"))
		sourcebanspp_exist = false;
	else if (StrEqual(name, "sourcebans"))
		sourcebans_exist = false;
	else if (StrEqual(name, "materialadmin"))
		materialadmin_exist = false;
	else if (StrEqual(name, "bansystem_access"))
		bansystem_exist = false;
}

public void OnClientPutInServer(int client)
{
	lilac_reset_client(client);
	int accountId = GetSteamAccountID(client);
	if (accountId > 0) {
		lilac_aim_suspicion_promote_legacy(client, accountId);
		lilac_aim_suspicion_restore_client(client, accountId);
	}
	lilac_string_check_name(client);

	CreateTimer(30.0, timer_welcome, GetClientUserId(client));
}

public void OnClientDisconnect(int client)
{
	if (aim_map_transition_pending) {
		lilac_aim_suspicion_clear_legacy_user(GetClientUserId(client));
		lilac_aimbot_reset_client(client);
		playerinfo_aimlock[client] = 0;
		playerinfo_aimlock_sus[client] = 0;
		aim_suspicion_accountid[client] = 0;
		return;
	}

	lilac_aim_suspicion_clear_account(aim_suspicion_accountid[client], LilacAimTrackingEnd_Disconnected);
	lilac_aim_suspicion_clear_legacy_user(GetClientUserId(client));
	lilac_aimbot_reset_client(client);
	playerinfo_aimlock[client] = 0;
	playerinfo_aimlock_sus[client] = 0;
	aim_suspicion_accountid[client] = 0;
}

public void OnClientAuthorized(int client, const char[] auth)
{
	int accountId = GetSteamAccountID(client);
	if (accountId > 0 && accountId != aim_suspicion_accountid[client]) {
		if (aim_suspicion_accountid[client] > 0)
			lilac_aim_suspicion_clear_account(aim_suspicion_accountid[client], LilacAimTrackingEnd_Disconnected);
		lilac_aim_suspicion_promote_legacy(client, accountId);
		lilac_aim_suspicion_restore_client(client, accountId);
	}
}

public Action event_map_transition(Event event, const char[] name, bool dontBroadcast)
{
	aim_map_transition_pending = true;
	if (aim_map_carry_cleanup_timer != INVALID_HANDLE) {
		KillTimer(aim_map_carry_cleanup_timer);
		aim_map_carry_cleanup_timer = INVALID_HANDLE;
	}
	aim_transition_carry_accounts.Clear();
	/* Unauthenticated detections have no stable identity to carry across chapters. */
	int legacyUserids[MAXPLAYERS + 1];
	int legacyUseridCount = 0;
	for (int i = 0; i < aim_legacy_detections.Length; i++) {
		AimLegacyDetection detection;
		aim_legacy_detections.GetArray(i, detection, sizeof(detection));
		bool alreadyAdded = false;
		for (int j = 0; j < legacyUseridCount; j++) {
			if (legacyUserids[j] == detection.userid) {
				alreadyAdded = true;
				break;
			}
		}
		if (!alreadyAdded)
			legacyUserids[legacyUseridCount++] = detection.userid;
	}
	for (int i = 0; i < legacyUseridCount; i++) {
		int userid = legacyUserids[i];
		int client = GetClientOfUserId(userid);
		if (client < 1 || client > MaxClients || !is_player_valid(client))
			continue;

		int accountId = GetSteamAccountID(client);
		if (accountId > 0) {
			lilac_aim_suspicion_promote_legacy(client, accountId);
			continue;
		}

		for (int j = 0; j < aim_legacy_detections.Length; j++) {
			AimLegacyDetection detection;
			aim_legacy_detections.GetArray(j, detection, sizeof(detection));
			if (detection.userid != userid)
				continue;
			if (detection.cheat == CHEAT_AIMBOT)
				lilac_aimbot_set_client_detections(client, 0);
			else if (detection.cheat == CHEAT_AIMLOCK)
				playerinfo_aimlock[client] = 0;
		}
	}
	aim_legacy_detections.Clear();
	AimSuspicionRecord record;
	for (int i = 0; i < aim_suspicion_records.Length; i++) {
		aim_suspicion_records.GetArray(i, record, sizeof(record));
		if (record.detections <= 0)
			continue;

		bool alreadyAdded = false;
		for (int j = 0; j < aim_transition_carry_accounts.Length; j++) {
			if (aim_transition_carry_accounts.Get(j) == record.accountId) {
				alreadyAdded = true;
				break;
			}
		}
		if (!alreadyAdded)
			aim_transition_carry_accounts.Push(record.accountId);
	}
	return Plugin_Continue;
}

public void OnMapStart()
{
	/* LevelEnd disconnects clients before map start. Their account-keyed records and
	 * one-shot expiry timers survive this slot teardown and are restored on auth. */
	aim_map_transition_pending = false;
	if (aim_transition_carry_accounts.Length > 0)
		aim_map_carry_cleanup_timer = CreateTimer(120.0, timer_aim_tracking_map_carry_cleanup);
}

public Action timer_aim_tracking_map_carry_cleanup(Handle timer)
{
	aim_map_carry_cleanup_timer = INVALID_HANDLE;
	for (int i = 0; i < aim_transition_carry_accounts.Length; i++) {
		int accountId = aim_transition_carry_accounts.Get(i);
		if (lilac_aim_suspicion_find_client(accountId) == 0)
			lilac_aim_suspicion_clear_account(accountId, LilacAimTrackingEnd_Disconnected);
	}
	aim_transition_carry_accounts.Clear();
	return Plugin_Continue;
}

public void OnPluginEnd()
{
	for (int i = aim_suspicion_records.Length - 1; i >= 0; i--)
		lilac_aim_suspicion_remove_record(i, LilacAimTrackingEnd_PluginUnload);
}

public void TF2_OnConditionRemoved(int client, TFCond condition)
{
	if (condition == TFCond_Taunting)
		playerinfo_time_teleported[client] = GetGameTime();
	else if (condition == TFCond_HalloweenKart)
		playerinfo_time_bumpercart[client] = GetGameTime();
}

public Action event_teleported(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid", -1));

	if (is_player_valid(client))
		playerinfo_time_teleported[client] = GetGameTime();

	return Plugin_Continue;
}

public void map_teleport(const char[] output, int caller, int activator, float delay)
{
	if (!is_player_valid(activator) || IsFakeClient(activator))
		return;

	playerinfo_time_teleported[activator] = GetGameTime();
}

public Action timer_welcome(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	/* Todo: Considering there are log-only options now...
	 * Perhaps I should check if ANYTHING can ban at all. */
	if (is_player_valid(client) && icvar[CVAR_WELCOME]
		&& icvar[CVAR_ENABLE] && icvar[CVAR_BAN])
		PrintToChat(client, "[Lilac] %T", "welcome_msg", client, PLUGIN_VERSION);

	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3],
				float angles[3], int& weapon, int& subtype, int& cmdnum,
				int& tickcount, int& seed, int mouse[2])
{
	static int lbuttons[MAXPLAYERS + 1];

	if (!is_player_valid(client) || IsFakeClient(client))
		return Plugin_Continue;

	/* Increment the index. */
	if (++playerinfo_index[client] >= CMD_LENGTH)
		playerinfo_index[client] = 0;

	/* Store when the tick was processed. */
	playerinfo_time_usercmd[client][playerinfo_index[client]] = GetGameTime();

	/* Store information. */
	lilac_backtrack_store_tickcount(client, tickcount);
	set_player_log_angles(client, angles, playerinfo_index[client]);
	playerinfo_buttons[client][playerinfo_index[client]] = buttons;
	playerinfo_actions[client][playerinfo_index[client]] = 0;

	if ((buttons & IN_ATTACK) && bullettime_can_shoot(client))
		playerinfo_actions[client][playerinfo_index[client]] |= ACTION_SHOT;

	if (icvar[CVAR_ENABLE]) {
		/* Detect Angle-Cheats. */
		if (icvar[CVAR_ANGLES])
			lilac_angles_check(client, angles);

		/* Detect Macros. */
		if (macro_max && icvar[CVAR_MACRO])
			lilac_macro_check(client, buttons, lbuttons[client]);

		/* Detect bhop. */
		if (!force_disable_bhop && icvar[CVAR_BHOP])
			lilac_bhop_check(client, buttons, lbuttons[client]);

		/* Patch Angle-Cheats. */
		if (icvar[CVAR_PATCH_ANGLES])
			lilac_angles_patch(angles);

		/* Patch Backtracking. */
		if (icvar[CVAR_BACKTRACK_PATCH])
			tickcount = lilac_backtrack_patch(client, tickcount);
	}

	lbuttons[client] = buttons;

	return Plugin_Continue;
}
