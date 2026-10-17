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

#if defined _lilac_included
 #endinput
#endif
#define _lilac_included

/* In case anyone wants to change this later on in a pull request or whatever,
 * DON'T DON'T DON'T DON'T DON'T DON'T DON'T DON'T DON'T DON'T DON'T!!!
 * ...  DON'T...
 * These values cannot be changed due to forwards,
 *     changing them will cause issues for other plugins.
 * You can add new stuff, but not change the number of anything here. */
#define CHEAT_ANGLES             0
#define CHEAT_CHATCLEAR          1
#define CHEAT_CONVAR             2
#define CHEAT_NOLERP             3
#define CHEAT_BHOP               4
#define CHEAT_AIMBOT             5
#define CHEAT_AIMLOCK            6
// #define CHEAT_ANTI_DUCK_DELAY    7 /* Deprecated - Unsupported game */
#define CHEAT_NOISEMAKER_SPAM    8
#define CHEAT_MACRO              9 /* Macros aren't actually cheats, but are forwarded as such. */
#define CHEAT_NEWLINE_NAME      10
#define CHEAT_MAX               11

/**
 * Why Lilac ended an Aimbot/Aimlock suspect tracking window.
 */
enum LilacAimTrackingEndReason
{
	LilacAimTrackingEnd_Expired = 0, /**< All normalized detections expired. No ban was requested. */
	LilacAimTrackingEnd_Disconnected, /**< The tracked client disconnected. */
	LilacAimTrackingEnd_BanRequested, /**< Lilac is about to request a ban from a provider. */
	LilacAimTrackingEnd_PluginUnload /**< Lilac is unloading while tracking is active. */
}

/**
 * Called when a player is detected cheating.
 *
 * @param client        Client index of the player.
 * @param cheat         Cheat type. (See lilac_global #L38-#L48)
 * @noreturn
 */
forward void lilac_cheater_detected(int client, int cheat);

/**
 * Called when a player reaches two normalized Aimbot or Aimlock detections
 * whose ten-minute Lilac suspicion windows overlap. This is the start of a
 * tracking window, not confirmation that the player is cheating.
 *
 * Ordering: lilac_cheater_detected for the second detection runs first. For
 * this tracking window, lilac_aim_tracking_ended runs once when it closes.
 *
 * @param client        Client index at start time.
 * @param cheat         CHEAT_AIMBOT or CHEAT_AIMLOCK.
 * @param accountId     Stable Steam account ID.
 * @param steamId64     Stable SteamID64 string.
 * @noreturn
 */
forward void lilac_aim_tracking_started(int client, int cheat, int accountId, const char[] steamId64);

/**
 * Reports the tracking-start identity without changing the original forward ABI.
 * @param client        Client index at start time.
 * @param cheat         CHEAT_AIMBOT or CHEAT_AIMLOCK.
 * @param accountId     Stable Steam account ID.
 * @param steamId64     Stable SteamID64 string.
 * @param incidentId    Stable UUID v4 for this tracking window.
 * @noreturn
 */
forward void lilac_aim_tracking_incident_started(int client, int cheat, int accountId, const char[] steamId64, const char[] incidentId);

/**
 * Called once when an active Aimbot/Aimlock tracking window ends.
 * Expired means Lilac has no remaining normalized detections in its ten-minute
 * counters; Disconnected and PluginUnload also discard the live counter state.
 * BanRequested is emitted only when Lilac proceeds to ask a ban provider.
 *
 * Ordering: for a ban, lilac_cheater_banned runs first; this forward runs next;
 * lilac_cheater_ban_request_queued follows only if BanSystem accepts its async
 * request. The queued forward does not confirm persisted sanctions.
 *
 * @param client        Current client index, or 0 when the account is offline.
 * @param cheat         CHEAT_AIMBOT or CHEAT_AIMLOCK.
 * @param accountId     Stable Steam account ID captured at start time.
 * @param steamId64     Stable SteamID64 string captured at start time.
 * @param reason        Why the tracking window ended.
 * @noreturn
 */
forward void lilac_aim_tracking_ended(int client, int cheat, int accountId, const char[] steamId64, LilacAimTrackingEndReason reason);

/**
 * Called before Lilac requests a ban for cheating. This is not confirmation
 * that any provider accepted or persisted a ban.
 *
 * @param client        Client index of the player.
 * @param cheat         Cheat type. (See lilac_global #L38-#L48)
 * @noreturn
 */
forward void lilac_cheater_banned(int client, int cheat);

/**
 * Reports the exact Lilac automatic-ban decision with the UUID captured when
 * its tracking window started. This is not a persisted sanction confirmation.
 * The UUID is also passed to BanSystem Access; central linkage requires the
 * atomic sanction commit, target and node/server to match.
 *
 * @param client        Client index of the player.
 * @param cheat         Cheat type (CHEAT_AIMBOT or CHEAT_AIMLOCK).
 * @param accountId     Stable Steam account ID targeted by the ban.
 * @param steamId64     Stable SteamID64 string.
 * @param incidentId    UUID v4 used by the private detection and sanction.
 * @noreturn
 */
forward void lilac_cheater_ban_incident(int client, int cheat, int accountId, const char[] steamId64, const char[] incidentId);

/**
 * Called after BanSystem Access accepts one asynchronous ban request.
 * This reports queue acceptance only. Observe BSCore_OnSanctionCreateCompleted
 * and require success plus a sanction ID before treating the ban as persisted.
 *
 * @param client        Client index at request time.
 * @param cheat         Cheat type.
 * @param accountId     Stable Steam account ID targeted by the request.
 * @param requestId     Local Core request ID for completion correlation.
 * @noreturn
 */
forward void lilac_cheater_ban_request_queued(int client, int cheat, int accountId, int requestId);

/**
 * Allows external plugins to interrupt a cheat detection before Lilac continues.
 *
 * Important: internally Lilac creates this as an event-style forward and treats
 * any non-zero return value as "block detection". Because this include exposes
 * the callback as bool, the practical contract is:
 * false = allow detection to continue
 * true = interrupt detection
 *
 * @param client        Client index of the player.
 * @param cheat         Cheat type. (See lilac_global #L38-#L48)
 * @return              true to interrupt the cheat detection process, false to allow it.
 */
forward bool lilac_allow_cheat_detection(int client, int cheat);

/**
 * Get the player details informations of the currently cheat flagged.
 * Best moment to call this function is in the lilac_cheater_detected callback.
 *
 * @param client        Client index of the player.
 * @param buffer        Buffer to store the informations in.
 * @param maxlen        Maximal length of the buffer.
 * @return              1 If informations found and stored into buffer. Otherwise -1.
 */
native int lilac_GetDetectedInfos(int client, char[] buffer, int maxlen);

/**
 * Query whether the connected client currently has an active Aimbot/Aimlock
 * tracking window. Intended for consumers that load after Lilac.
 *
 * @param client        Client index.
 * @param cheat         CHEAT_AIMBOT or CHEAT_AIMLOCK.
 * @return              True only when this client has an active tracking window.
 */
native bool lilac_IsAimTracking(int client, int cheat);

/** Returns the number of active Aimbot/Aimlock tracking windows. */
native int lilac_GetAimTrackingCount();

/**
 * Reads one active tracking window by zero-based index.
 * @param index     Index in the active snapshot.
 * @param client    Current client index, or 0 when the account is offline.
 * @param cheat     CHEAT_AIMBOT or CHEAT_AIMLOCK.
 * @param accountId Stable Steam account ID.
 * @param steamId64 Stable SteamID64 string.
 * @param maxlen    Size of steamId64 buffer.
 * @return          True when index exists, false otherwise.
 */
native bool lilac_GetAimTrackingInfo(int index, int &client, int &cheat, int &accountId, char[] steamId64, int maxlen);

/** Reads the stable incident UUID for an active tracking row. */
native bool lilac_GetAimTrackingIncidentInfo(int index, char[] incidentId, int maxlen);

// Instead of having to implant this into each plugin who want to use forwards
stock void GetCheatName(int type, char[] buffer, int maxlen)
{
    switch(type)
    {
        case CHEAT_ANGLES:Format(buffer, maxlen, "Angles");
        case CHEAT_CHATCLEAR:Format(buffer, maxlen, "Chat Clear");
        case CHEAT_CONVAR:Format(buffer, maxlen, "Convar");
        case CHEAT_NOLERP:Format(buffer, maxlen, "NoLerp");
        case CHEAT_BHOP:Format(buffer, maxlen, "Bhop");
        case CHEAT_AIMBOT:Format(buffer, maxlen, "Aimbot");
        case CHEAT_AIMLOCK:Format(buffer, maxlen, "Aimlock");
        case CHEAT_NOISEMAKER_SPAM:Format(buffer, maxlen, "NoiseMaker spam");
        case CHEAT_MACRO:Format(buffer, maxlen, "Macro");
        case CHEAT_NEWLINE_NAME:Format(buffer, maxlen, "NewLine Name");
    }
}

public SharedPlugin __pl_lilac =
{
    name = "lilac",
    file = "lilac.smx",
    #if defined REQUIRE_PLUGIN
    required = 1
    #else
    required = 0
    #endif
};

public void __pl_lilac_SetNTVOptional()
{
    MarkNativeAsOptional("lilac_GetDetectedInfos");
    MarkNativeAsOptional("lilac_IsAimTracking");
    MarkNativeAsOptional("lilac_GetAimTrackingCount");
    MarkNativeAsOptional("lilac_GetAimTrackingInfo");
    MarkNativeAsOptional("lilac_GetAimTrackingIncidentInfo");
}
