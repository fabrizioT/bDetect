// ------------------------------------
// bDetect | bullet detection framework
// ------------------------------------
// Version: 0.67
// Date: 05/07/2012
// Author: Fabrizio_T 
// Additional code: TPW 
// File Name: bdetect.sqf
// License: Free for all
// ------------------------------------

// BEGINNING OF FRAMEWORK CODE
// -----------------------------
// Constants
// -----------------------------

bdetect_name = "bDetect | Bullet Detection Framework"; 
bdetect_short_name = "bDetect"; 
bdetect_version = "0.67";
bdetect_init_done = false;
	
// -----------------------------
// Functions
// -----------------------------

bdetect_fnc_init = 
{
	private [ "_msg" ];

	if( bdetect_debug_enable ) then {
		_msg = format["%1 v%2 is starting ...", bdetect_short_name, bdetect_version];
		[ _msg, 0 ] call bdetect_fnc_debug;
	};

	// You should set these variables elsewhere, don't edit them here since they're default. 
	// See bottom of this file for framework initialization example.
	if(isNil "bdetect_enable") then { bdetect_enable = true; }; // (Boolean, Default true) Toggle to Enable / Disable bdetect altogether.
	if(isNil "bdetect_startup_hint") then { bdetect_startup_hint = true; }; // (Boolean, Default true) Toggle to Enable / Disable bDetect startup Hint.
	
	if(isNil "bdetect_debug_enable") then { bdetect_debug_enable = false; }; // (Boolean, Default false) Toggle to Enable / Disable debug messages.
	if(isNil "bdetect_debug_chat") then { bdetect_debug_chat = false; }; // (Boolean, Default false) Show debug messages also in globalChat.
	if(isNil "bdetect_debug_levels") then { bdetect_debug_levels = [0,1,2,3,4,5,6,7,8,9]; }; // (Array, Default [0,1,2,3,4,5,6,7,8,9]) Filter debug messages by included levels. 

	if(isNil "bdetect_callback") then { bdetect_callback = "bdetect_fnc_callback"; }; // (String, Default "bdetect_fnc_callback") Name for your own callback function
	if(isNil "bdetect_callback_mode") then { bdetect_callback_mode = "spawn"; }; // (String, Default "spawn") Allowed values: "call" or "spawn"

	if(isNil "bdetect_fps_adaptation") then { bdetect_fps_adaptation = true; }; // (Boolean, Default true) Whether bDetect should try to keep over "bdetect_fps_min" FPS while degrading quality of detection
	if(isNil "bdetect_fps_min") then { bdetect_fps_min = 20; }; // (Number, Default 20) The minimum FPS you wish to keep
	if(isNil "bdetect_fps_calc_each_x_frames") then { bdetect_fps_calc_each_x_frames = 16; }; // (Number, Default 16) FPS check is done each "bdetect_fps_min" frames. 1 means each frame.

	if(isNil "bdetect_eh_assign_cycle_wait") then { bdetect_eh_assign_cycle_wait = 10; }; // (Seconds, Default 10). Wait duration foreach cyclic execution of bdetect_fnc_eh_loop()

	if(isNil "bdetect_bullet_min_delay") then { bdetect_bullet_min_delay = 0.1; }; // (Seconds, Default 0.1) Minimum time between 2 consecutive shots fired by an unit for the last bullet to be tracked. Very low values may cause lag.
	if(isNil "bdetect_bullet_max_delay") then { bdetect_bullet_max_delay = 1.5; }; // (Seconds, Default 2)
	if(isNil "bdetect_bullet_initial_min_speed") then { bdetect_bullet_initial_min_speed = 360; }; // (Meters/Second, Default 360) Bullets slower than this are ignored.
	if(isNil "bdetect_bullet_max_proximity") then { bdetect_bullet_max_proximity = 10; }; // (Meters, Default 10) Maximum proximity to unit for triggering detection
	if(isNil "bdetect_bullet_min_distance") then { bdetect_bullet_min_distance = 25; }; // (Meters, Default 25) Bullets having travelled less than this distance are ignored
	if(isNil "bdetect_bullet_max_distance") then { bdetect_bullet_max_distance = 400; }; // (Meters, Default 400) Bullets havin travelled more than distance are ignored
	if(isNil "bdetect_bullet_max_lifespan") then { bdetect_bullet_max_lifespan = 0.5; }; // (Seconds, Default 0.5) Bullets living more than these seconds are ignored
	if(isNil "bdetect_bullet_max_height") then { bdetect_bullet_max_height = 6; }; // (Meters, Default 6)  Bullets going higher than this -and- diverging from ground are ignored
	if(isNil "bdetect_bullet_skip_mags") then { bdetect_bullet_skip_mags = []; }; // (Array) Skip these bullet types altogether. Example: ["30rnd_9x19_MP5", "30rnd_9x19_MP5SD", "15Rnd_9x19_M9"]
		 
	// NEVER edit the variables below, please.
	if(isNil "bdetect_fired_bullets") then { bdetect_fired_bullets = []; };
	if(isNil "bdetect_fired_bullets_count") then { bdetect_fired_bullets_count = 0; };
	if(isNil "bdetect_fired_bullets_count_tracked") then { bdetect_fired_bullets_count_tracked = 0; };
	if(isNil "bdetect_fired_bullets_count_detected") then { bdetect_fired_bullets_count_detected = 0; };
	if(isNil "bdetect_fired_bullets_count_blacklisted") then { bdetect_fired_bullets_count_blacklisted = 0; };	
	if(isNil "bdetect_units_count") then { bdetect_units_count = 0; };
	if(isNil "bdetect_units_count_killed") then { bdetect_units_count_killed = 0; };
	if(isNil "bdetect_fps") then { bdetect_fps = bdetect_fps_min; };
	if(isNil "bdetect_bullet_delay") then { bdetect_bullet_delay = bdetect_bullet_min_delay; };
	if(isNil "bdetect_frame_tstamp") then { bdetect_frame_tstamp = 0; };
	if(isNil "bdetect_frame_min_duration") then { bdetect_frame_min_duration = (bdetect_bullet_max_proximity * 2 * .66 / 600) max .01; };

	// bullet speed converted to kmh
	bdetect_bullet_initial_min_speed = bdetect_bullet_initial_min_speed * 3.6;
	
	// compile callback name into function
	bdetect_callback_compiled = call compile format["%1", bdetect_callback];

	// Add per-frame execution of time-critical function
	[bdetect_fnc_detect,0] call cba_fnc_addPerFrameHandler;   
	
	// Assign event handlers to any units (eve spawned ones)
	bdetect_spawned_loop_handler = [] spawn bdetect_fnc_eh_loop;   
};


// Keep searching units for newly spawned ones and assign fired EH to them
bdetect_fnc_eh_loop =
{
	private [ "_x", "_msg"];
	
	{ 
		[_x] call bdetect_fnc_eh_add;
		
	} foreach allUnits;
	
	if( !bdetect_init_done ) then 
	{ 
		bdetect_init_done = true; 
		
		if( bdetect_debug_enable ) then {
			_msg = format["%1 v%2 has started", bdetect_short_name, bdetect_version];
			[ _msg, 0 ] call bdetect_fnc_debug;
		};
		
		if( bdetect_startup_hint ) then {
			_msg = format["%1 v%2 has started", bdetect_short_name, bdetect_version];
			hint _msg;
		};
	};

	while { true } do
	{
		sleep bdetect_eh_assign_cycle_wait;
		{ 
			[_x] call bdetect_fnc_eh_add;
			
		} foreach allUnits;
	};
};

// Assign fired EH to a single unit
bdetect_fnc_eh_add =
{
	private ["_unit", "_msg", "_vehicle", "_e"];
	
	_unit = _this select 0;
	_vehicle = assignedVehicle _unit;
	
	if( isNull _vehicle && _unit != vehicle _unit ) then { _vehicle =  vehicle _unit };
	
	// handling units
	if( isNil { _unit getVariable "bdetect_fired_eh" } ) then
	{
		_e = _unit addEventHandler ["Fired", bdetect_fnc_fired];
		_unit setVariable ["bdetect_fired_eh", _e]; 
		
		_e =_unit addEventHandler ["Killed", bdetect_fnc_killed];
		_unit setVariable ["bdetect_killed_eh", _e]; 
		
		bdetect_units_count = bdetect_units_count + 1;
		
		if( bdetect_debug_enable ) then {
			_msg = format["[%1] was assigned 'Fired' EH", _unit];
			[ _msg, 3 ] call bdetect_fnc_debug;	
		};
	}
	else
	{
		if( bdetect_debug_enable ) then {
			_msg = format["[%1] already had an assigned 'Fired' EH", _unit];
			[ _msg, 3 ] call bdetect_fnc_debug;
		};
	};
	
	// handling vehicles
	if( !( isNull _vehicle ) ) then
	{
		if ( isNil { _vehicle getVariable "bdetect_fired_eh" } && ( assignedVehicleRole _unit) select 0 == "Turret"  ) then   
		{		
			_vehicle addeventhandler ["Fired", bdetect_fnc_fired];  
			_vehicle setVariable ["bdetect_fired_eh", _e]; 
			
			_vehicle addEventHandler ["Killed", bdetect_fnc_killed];		
			_vehicle setVariable ["bdetect_killed_eh", _e]; 	
			
			bdetect_units_count = bdetect_units_count + 1;			
			
			if( bdetect_debug_enable ) then {
				_msg = format["[%1] was assigned 'Fired' EH", _vehicle];
				[ _msg, 3 ] call bdetect_fnc_debug;	
			};
		}
		else
		{
			if( bdetect_debug_enable ) then {
				_msg = format["[%1] already had an assigned 'Fired' EH", _unit];
				[ _msg, 3 ] call bdetect_fnc_debug;
			};
		};
	};
};

// Killed EH
bdetect_fnc_killed =
{
	private ["_unit", "_e"];
	
	_unit = _this select 0;
	
	_e = _unit getVariable "bdetect_fired_eh";
	_unit removeEventHandler ["fired", _e];
	
	_e = _unit getVariable "bdetect_killed_eh";
	_unit removeEventHandler ["killed", _e];
	
	_unit setVariable ["bdetect_fired_eh", nil];
	_unit setVariable ["bdetect_killed_eh", nil];
	
	bdetect_units_count_killed = bdetect_units_count_killed + 1;
};

// Fired EH
bdetect_fnc_fired =
{
 	private ["_unit", "_muzzle", "_magazine", "_bullet", "_speed", "_msg", "_time", "_dt"];

	if( bdetect_enable ) then
	{
		_unit = _this select 0;
		_muzzle = _this select 2;
		_magazine = _this select 5;
		_bullet = _this select 6;
		_speed = speed _bullet;
		_time = time; //diag_tickTime
		_dt = _time - ( _unit getVariable ["bdetect_fired_time", 0] );
		
		bdetect_fired_bullets_count = bdetect_fired_bullets_count + 1;
		
		if( _dt > bdetect_bullet_delay 
			&& !( _magazine in bdetect_bullet_skip_mags ) 
			&& _speed > bdetect_bullet_initial_min_speed 
		) then
		{
			_unit setVariable ["bdetect_fired_time", _time]; 
			
			// Append info to bullets array
			[ _bullet, _unit, _time ] call bdetect_fnc_bullet_add;
			
			bdetect_fired_bullets_count_tracked = bdetect_fired_bullets_count_tracked + 1;
			
			if( bdetect_debug_enable ) then {
				_msg = format["[%1] Tracking bullet: speed=%2, type=%3, Delay=%4", _unit, _speed, typeOf _bullet, _dt ];
				[ _msg, 2 ] call bdetect_fnc_debug;
			};
		}
		else
		{
			if( bdetect_debug_enable ) then {
				_msg = format["[%1] Skipping bullet: speed=%2, type=%3, Delay=%4 [%5 - %6]", _unit, _speed, typeOf _bullet, _dt,  _time , ( _unit getVariable ["bdetect_fired_time", 0] )];
				[ _msg, 2 ] call bdetect_fnc_debug;
			};
		};
	};
};

// Time-critical detection function, to be executed per-frame
bdetect_fnc_detect =         
{        
	private ["_tot", "_msg"];
	
	if( bdetect_enable ) then
	{
		private ["_t", "_dt"];
		
		_t = time; //diag_tickTime
		_dt = _t - bdetect_frame_tstamp;
		
		if( _dt >= bdetect_frame_min_duration ) then
		{
			bdetect_frame_tstamp = _t;
			
			if( bdetect_debug_enable ) then {
				_msg = format["Frame duration=%1, min duration:%2", _dt , bdetect_frame_min_duration ];
				[ _msg, 4 ] call bdetect_fnc_debug;
			};
			
			_tot = count bdetect_fired_bullets;

			if ( _tot > 0 ) then 
			{ 
				if( bdetect_fps_adaptation && diag_frameno % bdetect_fps_calc_each_x_frames == 0) then
				{
					call bdetect_fnc_diag_min_fps;
				};
				
				[ _tot, _t ] call bdetect_fnc_detect_sub;
			};
		};
		
		bdetect_fired_bullets = bdetect_fired_bullets - [-1];
	};
};

// Subroutine executed within bdetect_fnc_detect()
bdetect_fnc_detect_sub = 
{
	private ["_tot", "_t", "_n", "_bullet", "_data", "_shooter", "_pos", "_time", "_blacklist", "_update_blacklist", "_bpos", "_dist", "_units", "_x", "_data", "_nul"];
	
	_tot = _this select 0;
	_t = _this select 1;
	
	for "_n" from 0 to _tot - 1 step 2 do 
	{
		_bullet = bdetect_fired_bullets select _n;
		_data = bdetect_fired_bullets select (_n + 1);
		_shooter = _data select 0;
		_pos = _data select 1;
		_time = _data select 2;
		_blacklist = _data select 3;
		_update_blacklist = false;
		
		if( !( isnull _bullet ) ) then
		{
			_bpos = getPosATL _bullet;
			_dist = _bpos distance _pos;	

			if( bdetect_debug_enable ) then {
				_msg = format["Following bullet %1. Time: %2. Distance: %3 Speed: %4. Position: %5", _bullet, _t - _time, _dist, (speed _bullet / 3.6), getPosASL _bullet];
				[ _msg, 2 ] call bdetect_fnc_debug;
			};
		};

		if( isNull _bullet 
			|| !(alive _bullet) 
			|| _t - _time > bdetect_bullet_max_lifespan 
			|| _dist > bdetect_bullet_max_distance	
			|| speed _bullet < bdetect_bullet_initial_min_speed // funny rebounds handling
			|| ( ( _bpos select 2) > bdetect_bullet_max_height && ( ( vectordir _bullet ) select 2 ) > 0 ) 
			) then
		{
			[ _bullet ] call bdetect_fnc_bullet_tag_remove;
		}
		else
		{
			if( _dist > bdetect_bullet_min_distance	) then
			{
				_units = _bpos nearEntities [ ["MAN"] , bdetect_bullet_max_proximity];
	
				{
					if( _x != _shooter && !(_x in _blacklist) ) then
					{
						if( vehicle _x == _x && lifestate _x == "ALIVE") then
						{
							_blacklist set [ count _blacklist, _x];
							_update_blacklist = true;
							
							bdetect_fired_bullets_count_detected = bdetect_fired_bullets_count_detected + 1;
										
							if( bdetect_callback_mode == "spawn" ) then {
								_nul = [_x, _bullet, _x distance _bpos, _data] spawn bdetect_callback_compiled;
							} else {
								[_x, _bullet, _x distance _bpos, _data] call bdetect_callback_compiled;
							};
							
							if( bdetect_debug_enable ) then {
								_msg = format["[%1] Close to bullet %2 fired by %3, proximity=%4m, data=%5", _x, _bullet, _shooter, _x distance _bpos, _data];
								[ _msg, 9 ] call bdetect_fnc_debug;
							};
						};
					}
					else
					{
						bdetect_fired_bullets_count_blacklisted = bdetect_fired_bullets_count_blacklisted + 1;
						
						if( bdetect_debug_enable ) then {
							_msg = format["[%1] Blacklisted for bullet %2", _x, _bullet];
							[ _msg, 5 ] call bdetect_fnc_debug;
						};
					};
					
				} foreach _units;
					
				if(_update_blacklist) then
				{
					// Update blacklist
					bdetect_fired_bullets set[ _n + 1, [_shooter, _pos, _time, _blacklist] ];
				};
			};
		};
	};
};

// Adapt frequency of some bullet checking depending on minimum FPS
bdetect_fnc_diag_min_fps =
{
	private ["_fps", "_msg"];

	_fps = diag_fps;
	
	if( bdetect_debug_enable ) then {
		_msg = format["FPS=%1, Min.FPS=%2, Prev. FPS=%3, bdetect_bullet_delay=%4)", _fps, bdetect_fps_min, bdetect_fps, bdetect_bullet_delay ];
		[ _msg, 1 ] call bdetect_fnc_debug;
	};
	
	if( _fps < bdetect_fps_min * 1.1) then
	{
		if( bdetect_bullet_delay  < bdetect_bullet_max_delay ) then 
		{
			bdetect_bullet_delay = ( ( bdetect_bullet_delay + 0.2) min bdetect_bullet_max_delay );
		
			if( bdetect_debug_enable ) then {
				_msg = format["FPS down to %1. Augmenting bdetect_bullet_delay to %2", _fps, bdetect_bullet_delay];
				[ _msg, 1 ] call bdetect_fnc_debug;
			};
		};
	}
	else
	{
		if( bdetect_bullet_delay > bdetect_bullet_min_delay ) then
		{
			bdetect_bullet_delay = (bdetect_bullet_delay - 0.1) max bdetect_bullet_min_delay;
		
			if( bdetect_debug_enable ) then {
				_msg = format["FPS up to %1. Reducing bdetect_bullet_delay to %2", _fps, bdetect_bullet_delay];
				[ _msg, 1 ] call bdetect_fnc_debug;
			};
		};
	};
	
	bdetect_fps = _fps;
};

// Add a bullet to bdetect_fired_bullets 
bdetect_fnc_bullet_add = 
{
	private ["_bullet", "_shooter", "_pos", "_time",  "_msg", "_n"];
	
	_bullet = _this select 0; // bullet object
	_shooter = _this select 1;	// shooter
	_pos = getPosATL _bullet;	// bullet start position
	_time = _this select 2;	// bullet shoot time
	_n = count bdetect_fired_bullets;
	
	bdetect_fired_bullets set [ _n,  _bullet  ];
	bdetect_fired_bullets set [ _n + 1, [ _shooter, _pos, _time, [] ] ];
	
	if( bdetect_debug_enable ) then {
		_msg = format["bullet %1 added", _bullet, _n / 2];
		[ _msg, 2] call bdetect_fnc_debug;
	};
};

// Tag a bullet to be removed from bdetect_fired_bullets 
bdetect_fnc_bullet_tag_remove = 
{
	private ["_bullet", "_n", "_msg" ];

	_bullet = _this select 0;
	_n = bdetect_fired_bullets find _bullet;
	
	if( _n != -1 ) then
	{
		bdetect_fired_bullets set[ _n, -1 ];
		bdetect_fired_bullets set[ _n + 1, -1 ];

		if( bdetect_debug_enable ) then {
			_msg = format["null/expired bullet tag to be removed"];
			[ _msg, 2 ] call bdetect_fnc_debug;
		};
	};
};

// Prototype for callback function to be executed within bdetect_fnc_detect
bdetect_fnc_callback = 
{
	private [ "_unit", "_bullet", "_proximity", "_data", "_shooter", "_pos", "_time", "_msg" ];
	
	_unit = _this select 0;		// unit being under fire
	_bullet = _this select 1;	// bullet object
	_proximity = _this select 2;	// distance between _bullet and _unit
	_data = _this select 3;		// Array containing more data
	
	_shooter = _data select 0; // shooter
	_pos = _data select 1;	// starting position of bullet
	_time = _data select 2; // starting time of bullet

	if( bdetect_debug_enable ) then {
		_msg = format["[%1] close to bullet %2 fired by %3, proximity=%4m, data=%5", _unit, _bullet, _shooter, _proximity, _data];
		[ _msg, 9 ] call bdetect_fnc_debug;
	};
};

// function to display and log stuff (into .rpt file) level zero is intended only for builtin messages
bdetect_fnc_debug =
{
	private [ "_msg", "_level"];
	
	/*
	DEBUG LEVELS: 
	From 0-9 are reserved.
	
	0 = unclassified messages
	1 = FPS related messages
	2 = "bdetect_fired_bullets" related messages
	3 = EH related messages
	4 = Frame related messages
	5 = Unit blacklist messages
	...
	9 = Unit detection related messages
	*/
	
	_level = _this select 1;
	
	if( bdetect_debug_enable && _level in bdetect_debug_levels) then
	{
		_msg = _this select 0;
		diag_log format["%1 [%2 v%3] Frame:%4 L%5: %6", time, bdetect_short_name, bdetect_version, diag_frameno, _level, _msg ];
		
		if( bdetect_debug_chat ) then 
		{
			player globalchat format["%1 - %2", time, _msg ];
		};
	};
};

bdetect_fnc_benchmark = 
{
	private ["_cnt"];
	
	if(isNil "bdetect_stats_max_bullets") then { bdetect_stats_max_bullets = 0; };
	if(isNil "bdetect_stats_min_fps") then { bdetect_stats_min_fps = 999; };
	if(isNil "bdetect_fired_bullets") then { bdetect_fired_bullets = []; };
	
	_nul = [] spawn 
	{
		while { true } do
		{
			_cnt = count ( bdetect_fired_bullets ) / 2;
			if( _cnt > bdetect_stats_max_bullets ) then { bdetect_stats_max_bullets = _cnt; };
			
			if( diag_fps < bdetect_stats_min_fps ) then { bdetect_stats_min_fps = diag_fps };
			hintsilent format["TIME: %1\nFPS: %2 (min: %3)\nBULLETS: %4 (max: %5)\nS.DELAY: %6 (Min FPS: %7)\nFIRED: %8\nTRACKED: %9\nDETECTED: %10\nBLACKLISTED: %11\nUNITS: %12\nKILLED: %13", 
				time, 
				diag_fps, 
				bdetect_stats_min_fps, 
				_cnt, 
				bdetect_stats_max_bullets, 
				bdetect_bullet_delay, 
				bdetect_fps_min,
				bdetect_fired_bullets_count,
				bdetect_fired_bullets_count_tracked,
				bdetect_fired_bullets_count_detected,
				bdetect_fired_bullets_count_blacklisted,
				bdetect_units_count,
				bdetect_units_count_killed
			];
			
			sleep .25;
		};
	};
};

// END OF FRAMEWORK CODE
// -------------------------------------------------------------------------------------------
// Example for running the framework
// -------------------------------------------------------------------------------------------
// The following commented code is not part of the framework, just an example of how to run it
// -------------------------------------------------------------------------------------------

/*
// Cut & paste the following code into your own sqf. file.
// Place "bdetect.sqf" into your own mission folder.

// First load the framework
call compile preprocessFileLineNumbers "bdetect.sqf";  // CAUTION: comment this line if you wish to execute the framework from -within- bdetect.sqf file

// Set any optional configuration variables whose value should be other than Default (see all the defined variables in bdetect.sqf, function bdetect_fnc_init() ). 
// Below some examples.
bdetect_debug_enable = true;		// Example only - Enable debug / logging in .rpt file. Beware, full levels logging may be massive.
bdetect_debug_levels = [0,9];		// Example only - Log only some basic messages (levels 0 and 9). Read comment about levels meanings into "bdetect.sqf, function bdetect_fnc_debug()
bdetect_debug_chat = true;			// Example only - log also into globalChat.

// Now name your own unit callback function (the one that will be triggered when a bullet is detected close to an unit)
bdetect_callback = "my_function";

// Define your own callback function and its contents, named as above. Here's a prototypical function: 
my_function = {
	private [ "_unit", "_bullet", "_proximity", "_data", "_shooter", "_pos", "_time", "_msg" ];
	
	_unit = _this select 0;			// unit whi detecting nearby bullet
	_bullet = _this select 1;		// bullet object
	_proximity = _this select 2;	// distance between bullet and unit
	_data = _this select 3;			// Container (array) of misc data, see below:
	
	_shooter = _data select 0; 		// enemy shooter
	_pos = _data select 1;			// starting position of bullet
	_time = _data select 2; 		// starting time of bullet

	_msg = format["my_function() - [%1] close to bullet %2 fired by %3, proximity=%4m, data=%5", _unit, _bullet, _shooter, _proximity, _data];
	[ _msg, 9 ] call bdetect_fnc_debug;
};

// Now initialize framework
sleep 5; // wait some seconds if you want to load other scripts
call bdetect_fnc_init;

// Wait for framework to be fully loaded
waitUntil { bdetect_init_done};

// You are done. Optional: care to activate display of some runtime stats ?
sleep 5;	// wait some more seconds for CPU load to normalize
call bdetect_fnc_benchmark; 

// All done, place your other fancy stuff below ...
*/