server_port = "2302" -- update this with your port. If port is invalid, your server will not be included.




api_version = "1.11.0.0"


current_map = nil
race = false
mode = 0
player_warps = {}
game_started = false

local sha2 = require("sha2");

ffi = require("ffi")
ffi.cdef [[
    typedef void http_response;
    http_response *http_post(const char *url, const char *json);
]]
http_client = ffi.load("hrl_api")


function SendTime(URL, json)
    http_client.http_post(URL, json)
end


function OnScriptLoad()

	if (halo_type == "PC") then
        gametype_base = 0x671340
    else
        gametype_base = 0x5F5498
    end
	register_callback(cb['EVENT_GAME_START'], "OnGameStart")
	register_callback(cb['EVENT_GAME_END'], "OnGameEnd")
	register_callback(cb['EVENT_JOIN'], "OnPlayerJoin")
	register_callback(cb['EVENT_DIE'], "OnPlayerDeath")
	register_callback(cb['EVENT_WARP'],"OnWarp")

	CheckMapAndGametype(true)

	for i = 1,16 do--	Reset personal stats
		player_warps[i] = 0
	end
end


function OnPlayerScore(playerIndex)

	-- Skip if user is not driver
	local player_address = get_dynamic_player(playerIndex)
	local vehicle_objectid = read_dword(player_address + 0x11C)
	if(tonumber(vehicle_objectid) ~= 0xFFFFFFFF) then
		local vehicle = get_object_memory(tonumber(vehicle_objectid))
		local driver = read_dword(vehicle + 0x324)
		driver = get_object_memory(tonumber(driver))
		if(driver == player_address) then

			print("Record Lap")

			player = get_player(playerIndex)
			current_name = get_var(playerIndex, "$name")
			best_time = read_word(player + 0xC4)--	Player's current time
			best_time = best_time/30
			player_hash = get_var(playerIndex, "$hash")
			player_hash = sha2.sha256(player_hash) --encode it again for added security

			-- Need to find correct addresses for these!
			--server_port = read_word(0x625230)
			--map_slug = read_string(0x63BC78)
			--map_name = read_string(0x698F21)
			map_name = ""

			json = '{"port":"'..server_port..'", "player_hash": "'..player_hash..'", "player_name":"'..current_name..'", "map_name": "'..current_map..'", "map_label": "'..map_name..'", "race_type": "'..mode..'", "player_time":"'..best_time..'"}'

			URL = "http://haloraceleaderboard.effakt.info/api/newtime"

			SendTime(URL, json)

		end
	end

end

function OnWarp(PlayerIndex)
	player_warps[PlayerIndex] = 1
end

function OnPlayerDeath(PlayerIndex)
	player_warps[PlayerIndex] = 1
end

function OnPlayerJoin(playerIndex)--	Inform player about the best time!
	if(race == false) then
		CheckMapAndGametype(false)
	end
end

function CheckMapAndGametype(NewGame)
	if(get_var(1, "$gt") == "race") then--	Check if gametype is race
		current_map = get_var(1, "$map")--	Set current map
		if(NewGame == false and race == true) then
			return false
		end
		race = true
		register_callback(cb['EVENT_SCORE'], "OnPlayerScore")--  Triggers on player score, this way we don't spam the tick query.

		safe_read(true)--    Prevent server crash if no map
		if (halo_type == "PC") then
			mode = read_byte(gametype_base + 0x7C - 32)
		else
			mode = read_byte(gametype_base + 0x7C)
		end
		safe_read(false)

	else
		race = false
		unregister_callback(cb['EVENT_SCORE'])
	end
end

function OnGameStart()
	CheckMapAndGametype(true)
	game_started = true
end

function ResetGameStarted()
	game_started = false
end

function OnGameEnd()
	for i = 1,16 do
		player_warps[i] = 0
	end
	if(race == false or mode == 2) then
		return false
	end
end

function OnScriptUnload()
end
