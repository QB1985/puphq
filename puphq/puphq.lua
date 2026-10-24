addon.name      = 'PUPHQ';
addon.author    = 'KS1985';
addon.version   = '2.10';
addon.desc      = 'Puppetmaster control panel. Based on Puphelper by GetAwayCoxn, restyled after YunaUI (dark violet panel, pill choices, glowing bars).';
addon.link      = 'https://github.com/QB1985/puphq';

require('common');
local imgui    = require('imgui');
local settings = require('settings');
local chat     = require('chat');
local ffi      = require('ffi');
local ok_d3d, d3d = pcall(require, 'd3d8');

----------------------------------------------------------------------------------------------------
-- Data
----------------------------------------------------------------------------------------------------
local Towns = T{'Tavnazian Safehold','Al Zahbi','Aht Urhgan Whitegate','Nashmau','Southern San d\'Oria [S]','Bastok Markets [S]','Windurst Waters [S]','San d\'Oria-Jeuno Airship','Bastok-Jeuno Airship','Windurst-Jeuno Airship','Kazham-Jeuno Airship','Southern San d\'Oria','Northern San d\'Oria','Port San d\'Oria','Chateau d\'Oraguille','Bastok Mines','Bastok Markets','Port Bastok','Metalworks','Windurst Waters','Windurst Walls','Port Windurst','Windurst Woods','Heavens Tower','Ru\'Lude Gardens','Upper Jeuno','Lower Jeuno','Port Jeuno','Rabao','Selbina','Mhaura','Kazham','Norg','Mog Garden','Celennia Memorial Library','Western Adoulin','Eastern Adoulin',
};

-- 0..7 are the elements (the combo order of the old addon: None, Dark, Light, ...); -1 is None
local ELEMENTS  = { 'Dark', 'Light', 'Earth', 'Wind', 'Fire', 'Ice', 'Thunder', 'Water' };
local OILS       = { 'Automaton Oil +3', 'Automaton Oil +2', 'Automaton Oil +1', 'Automaton Oil' };   -- best first
local OIL_FALLBACK = { ['Automaton Oil +3'] = 19185, ['Automaton Oil +2'] = 18733, ['Automaton Oil +1'] = 18732, ['Automaton Oil'] = 18731 };                -- (used only if the name lookup finds nothing)
local PUP_JOB   = 18;
local CMD_GAP   = 1.0;                                               -- seconds between two commands sent by the addon

-- Buffs that stop job abilities (the addon waits while one is on you)
local BLOCKING  = { Sleep = 'asleep', Petrification = 'petrified', Terror = 'terrified', Stun = 'stunned', Amnesia = 'amnesia' };

-- Attachment data. The element order is the game's: 1 Fire, 2 Ice, 3 Wind, 4 Earth, 5 Thunder, 6 Water, 7 Light, 8 Dark.
-- AEL[n] = { name, colour key } (the colour key is the one the maneuver dots use, see EL_COL).
local AEL = {
    { 'Fire', 4 }, { 'Ice', 5 }, { 'Wind', 3 }, { 'Earth', 2 }, { 'Thunder', 6 }, { 'Water', 7 }, { 'Light', 1 }, { 'Dark', 0 },
};
-- Capacity of the heads (1-6) and frames (32-35) in that order. Only a fallback: the client's own text is read first.
local HF_CAPS = {
    [1] = { 2, 2, 2, 2, 2, 2, 0, 0 },   -- harlequin_head
    [2] = { 3, 0, 2, 3, 2, 0, 2, 0 },   -- valoredge_x-900_head
    [3] = { 3, 0, 3, 0, 2, 2, 2, 0 },   -- sharpshot_z-500_head
    [4] = { 0, 3, 2, 2, 0, 3, 0, 2 },   -- stormwaker_y-700_head
    [5] = { 0, 3, 2, 2, 0, 3, 3, 0 },   -- soulsoother_c-1000_head
    [6] = { 0, 3, 2, 2, 0, 3, 0, 3 },   -- spiritreaver_m-400_head
    [32] = { 3, 3, 3, 3, 3, 3, 3, 3 },   -- harlequin_frame
    [33] = { 4, 2, 3, 4, 3, 3, 3, 2 },   -- valoredge_x-900_frame
    [34] = { 3, 2, 4, 3, 4, 3, 3, 2 },   -- sharpshot_z-500_frame
    [35] = { 2, 4, 2, 3, 3, 3, 3, 4 },   -- stormwaker_y-700_frame
};
-- Attachment costs: [attachment id] = { element, cost } (ids are the low byte of the item id, 0x2100 + id).
local ATT_COST = {
    [1]={1,1}, [2]={1,1}, [3]={1,1}, [4]={1,2}, [5]={1,2}, [6]={1,1}, [7]={1,1}, [8]={1,1},
    [9]={1,2}, [10]={1,3}, [11]={1,2}, [12]={1,4}, [13]={1,2}, [14]={1,1}, [15]={1,2}, [16]={1,5},
    [17]={1,1}, [18]={1,2}, [33]={2,2}, [34]={2,1}, [35]={2,1}, [36]={2,2}, [37]={2,1}, [38]={2,1},
    [39]={2,1}, [40]={2,2}, [41]={2,3}, [42]={2,2}, [43]={2,2}, [44]={2,4}, [45]={2,3}, [46]={2,3},
    [47]={2,5}, [48]={2,4}, [49]={2,1}, [50]={2,2}, [65]={3,2}, [66]={3,1}, [67]={3,1}, [68]={3,3},
    [69]={3,2}, [70]={3,2}, [71]={3,1}, [72]={3,2}, [73]={3,3}, [74]={3,4}, [75]={3,2}, [76]={3,2},
    [77]={3,5}, [78]={3,3}, [79]={3,4}, [80]={3,1}, [97]={4,1}, [98]={4,2}, [99]={4,1}, [100]={4,3},
    [101]={4,2}, [102]={4,1}, [103]={4,1}, [104]={4,2}, [105]={4,2}, [106]={4,4}, [107]={4,1}, [108]={4,5},
    [109]={4,3}, [129]={5,1}, [130]={5,1}, [131]={5,1}, [132]={5,2}, [133]={5,2}, [134]={5,2}, [135]={5,2},
    [136]={5,2}, [137]={5,3}, [138]={5,3}, [139]={5,3}, [140]={5,4}, [141]={5,4}, [142]={5,5}, [161]={6,2},
    [162]={6,1}, [163]={6,1}, [164]={6,3}, [165]={6,2}, [166]={6,1}, [167]={6,1}, [168]={6,1}, [169]={6,4},
    [170]={6,2}, [171]={6,1}, [172]={6,2}, [173]={6,5}, [174]={6,3}, [193]={7,2}, [194]={7,2}, [195]={7,1},
    [196]={7,3}, [197]={7,2}, [198]={7,1}, [200]={7,2}, [201]={7,3}, [202]={7,4}, [203]={7,1}, [204]={7,2},
    [205]={7,5}, [206]={7,2}, [207]={7,2}, [225]={8,2}, [226]={8,2}, [227]={8,1}, [228]={8,3}, [229]={8,2},
    [230]={8,1}, [232]={8,2}, [233]={8,4}, [234]={8,3}, [235]={8,5},
};


----------------------------------------------------------------------------------------------------
-- Settings
----------------------------------------------------------------------------------------------------
local defaults = T{
    win_x = 200, win_y = 200,
    m1 = -1, m2 = -1, m3 = -1,                                       -- the three maneuver choices of the ACTIVE set
    set = 1,                                                         -- the active maneuver set (1 to 3)
    sets = { { -1, -1, -1 }, { -1, -1, -1 }, { -1, -1, -1 } },       -- all three sets (kept in step with m1..m3 on every save)
    repair = 0,                                                      -- pet HP% to Repair at (0 = off)
    light_lo = 0, light_hi = 90,                                     -- force Light on slot 1 below lo%, back to normal at hi%
    deploy = false,
    minimized = true, mini_scale = 1.0, mini_alpha = 1.0,
    main_h = 0,
    mini_x = -1, mini_y = -1,                                        -- where the minimized bar sits (-1 = not placed yet)                              -- the minimized bar's size: 1x (smallest) to 3x
    cmds_open = false,
    oil_off = {},                                                    -- oil kinds ticked off (Auto Repair ignores them)
    att_open = false, att_sum_h = 130, att_sum_open = false, aset = 1,
    asets = { {head=0,frame=0,att={}}, {head=0,frame=0,att={}}, {head=0,frame=0,att={}}, {head=0,frame=0,att={}}, {head=0,frame=0,att={}}, {head=0,frame=0,att={}} },                                               -- the command list under the button
};
local cfg = settings.load(defaults);
settings.register('settings', 'puphq_settings', function(s) if s ~= nil then cfg = s; end end);
local NSETS = 3;
local function sync_sets()                                           -- what is on screen (m1..m3) belongs to the active set
    if type(cfg.sets) ~= 'table' then cfg.sets = {}; end
    local n = tonumber(cfg.set) or 1;
    if n < 1 or n > NSETS then n = 1; end
    cfg.set = n;
    cfg.sets[n] = { cfg.m1, cfg.m2, cfg.m3 };
end
local function save() sync_sets(); settings.save(); end

local function set_names(slots)
    local out = {};
    for i = 1, 3 do
        local el = slots and slots[i];
        out[i] = (el ~= nil and el >= 0 and el <= 7) and ELEMENTS[el + 1] or 'None';
    end
    return table.concat(out, ', ');
end
local function set_summary(n)
    if n == cfg.set then return set_names({ cfg.m1, cfg.m2, cfg.m3 }); end
    return set_names(type(cfg.sets) == 'table' and cfg.sets[n] or nil);
end

-- Make set n (wraps around) the active one: m1..m3 take its maneuvers
local function switch_set(n)
    sync_sets();                                                     -- keep what the current set holds
    n = ((math.floor(n) - 1) % NSETS) + 1;
    cfg.set = n;
    local sl = cfg.sets[n];
    if type(sl) ~= 'table' then sl = { -1, -1, -1 }; end
    cfg.m1, cfg.m2, cfg.m3 = sl[1] or -1, sl[2] or -1, sl[3] or -1;
    sync_sets();
    settings.save();
end

local st = {                                                         -- runtime state (not saved)
    open = false, enabled = false,
    oils = 0, oil_best = nil, oil_n = 0, oils_at = 0,
    last_cmd = 0, light_on = false,
    pet = nil, paused = nil, failed = false,
};

----------------------------------------------------------------------------------------------------
-- Game helpers
----------------------------------------------------------------------------------------------------
local oil_ids = nil;
local function find_oil_ids()                                         -- item ids by name, looked up once
    oil_ids = {};
    local res = AshitaCore:GetResourceManager();
    for _, name in ipairs(OILS) do
        local id = nil;
        pcall(function() local it = res:GetItemByName(name, 0); id = it and it.Id; end);
        oil_ids[name] = id or OIL_FALLBACK[name];
    end
end

-- Counts your oils (inventory only): the total, and the best tier you have with how many of it
local function count_oils()
    if oil_ids == nil then find_oil_ids(); end
    local by_id = {};
    for _, name in ipairs(OILS) do if oil_ids[name] then by_id[oil_ids[name]] = name; end end
    local counts = {};
    local inv = AshitaCore:GetMemoryManager():GetInventory();
    for i = 0, 80 do                                                 -- 0 = the real inventory only
        local item = inv:GetContainerItem(0, i);
        if item ~= nil and by_id[item.Id] then counts[by_id[item.Id]] = (counts[by_id[item.Id]] or 0) + item.Count; end
    end
    local total, best, best_n = 0, nil, 0;
    for _, name in ipairs(OILS) do
        local n = counts[name] or 0;
        total = total + n;
        if best == nil and n > 0 then best, best_n = name, n; end
    end
    return total, best, best_n, counts;
end

-- How many oils of the kinds that are ticked on you carry
local function oils_usable()
    local n = 0;
    for _, name in ipairs(OILS) do
        if not (type(cfg.oil_off) == 'table' and cfg.oil_off[name]) then n = n + ((st.oil_counts or {})[name] or 0); end
    end
    return n;
end

-- Every ability recast in one pass: { [ability name] = timer }. Maneuvers share one timer that the resource lookup
-- always names 'Fire Maneuver', so that name is what stands for all of them.
local function recast_map()
    local out = {};
    local rc  = AshitaCore:GetMemoryManager():GetRecast();
    local res = AshitaCore:GetResourceManager();
    for x = 0, 31 do
        local id    = rc:GetAbilityTimerId(x);
        local timer = rc:GetAbilityTimer(x);
        if (id ~= 0 or x == 0) and timer > 0 then
            local ability = res:GetAbilityByTimerId(id);
            if ability ~= nil and ability.Name[1] ~= 'Unknown' then out[ability.Name[1]] = timer; end
        end
    end
    return out;
end

local buff_names = {};
local function buff_name(id)
    local n = buff_names[id];
    if n == nil then
        n = AshitaCore:GetResourceManager():GetString('buffs.names', id) or false;
        buff_names[id] = n;
    end
    return n or nil;
end

----------------------------------------------------------------------------------------------------
-- Attachment sets: the game side
-- The memory lookups and the equip calls below come from the pupsets addon (pup.lua, GPLv3, based on atom0s' blusets):
-- the client keeps the automaton's loadout, and what the character has learned, in one buffer; changes are sent with
-- the game's own extended-equip function.
----------------------------------------------------------------------------------------------------
pcall(ffi.cdef, [[
    typedef uint8_t (__cdecl *ph_equipex_t)(uint8_t isSubJob, uint16_t jobType, uint16_t index, uint8_t id);
]]);

local PUPMEM = { ok = false };
pcall(function ()
    local a = ashita.memory.find('FFXiMain.dll', 0, 'C1E1032BC8B0018D????????????B9????????F3A55F5E5B', 10, 0);
    local b = ashita.memory.find('FFXiMain.dll', 0, '8B0D????????81EC9C00000085C95356570F??????????8B', 0, 0);
    if a ~= nil and a ~= 0 and b ~= nil and b ~= 0 then
        PUPMEM.offset  = ffi.cast('uint32_t*', a);
        PUPMEM.equipex = ffi.cast('ph_equipex_t', b);
        PUPMEM.ok = true;
    end
end);

local NASETS    = 6;                                                 -- attachment set slots
local ATT_SLOTS = 12;                                                -- attachments an automaton can carry

local function is_pup_main() return AshitaCore:GetMemoryManager():GetPlayer():GetMainJob() == PUP_JOB; end
local function is_pup_sub()  return AshitaCore:GetMemoryManager():GetPlayer():GetSubJob() == PUP_JOB; end

-- Where the client keeps the PUP buffer (0 when it can't be found)
local function pup_buffer()
    if not PUPMEM.ok then return 0; end
    local ok, ptr = pcall(function ()
        local p = ashita.memory.read_uint32(AshitaCore:GetPointerManager():Get('inventory'));
        if p == 0 then return 0; end
        p = ashita.memory.read_uint32(p);
        if p == 0 then return 0; end
        return p + PUPMEM.offset[0] + (is_pup_main() and 0x00 or 0x9C);
    end);
    return ok and ptr or 0;
end

local function u32le(b, o) return b[o + 1] + b[o + 2] * 256 + b[o + 3] * 65536 + b[o + 4] * 16777216; end

-- What the client says about the automaton, read twice a second:
--   head / frame / cur  the loadout now (cur: attachment ids)       heads / frames / att   the learned bits
--   bonus               the elemental capacity added by gifts
local PB = { at = -10, ok = false, learned = false, head = 0, frame = 0, cur = {}, heads = 0, frames = 0, att = {}, bonus = 0,
             heads_list = {}, frames_list = {}, att_list = {} };

local ITEMS = {};
local function clean_text(s)
    s = tostring(s or ''):gsub('[\r\n]+', ' '):gsub('[^\32-\126]', ''):gsub('%s+', ' ');
    return (s:gsub('^%s+', ''):gsub('%s+$', ''));
end
-- { id, name, raw, desc } for an item id, nil when the client has nothing there
local function item_info(itemid)
    local c = ITEMS[itemid];
    if c ~= nil then return c or nil; end
    ITEMS[itemid] = false;
    pcall(function ()
        local it = AshitaCore:GetResourceManager():GetItemById(itemid);
        if it == nil then return; end
        local name = it.Name[1];
        if name == nil or name == '' or name == '.' then return; end
        local raw = it.Description[1] or '';
        ITEMS[itemid] = { id = itemid, name = name, raw = raw, desc = clean_text(raw) };
    end);
    return ITEMS[itemid] or nil;
end

-- Head / frame capacity per element: the client writes it into the description as element marks (0xEF, 0x1F to 0x26,
-- then the number), in the same order as AEL. The table is only used if that text isn't there.
local CAPS = {};
local function item_caps(byteid)                                     -- head 1 to 7, frame 32 to 39
    local c = CAPS[byteid];
    if c then return c; end
    local caps, n = { 0, 0, 0, 0, 0, 0, 0, 0 }, 0;
    local info = item_info(0x2000 + byteid);
    if info then
        for g, d in info.raw:gmatch('\239([\31-\38])(%d)') do
            caps[g:byte() - 30] = tonumber(d);
            n = n + 1;
        end
    end
    if n < 8 and HF_CAPS[byteid] then caps = HF_CAPS[byteid]; end
    CAPS[byteid] = caps;
    return caps;
end
local function caps_text(byteid)
    local c, t = item_caps(byteid), {};
    for e = 1, 8 do if c[e] > 0 then t[#t + 1] = AEL[e][1] .. ' ' .. c[e]; end end
    return (#t > 0) and table.concat(t, '   ') or 'No capacity';
end

local function bit_set(v, n) return bit.band(bit.rshift(v, n), 1) == 1; end

local function read_pup(force)
    local now = os.clock();
    if not force and now - PB.at < 0.5 then return PB; end
    PB.at, PB.ok = now, false;

    local ok_job = is_pup_main() or is_pup_sub();
    local b = nil;
    if ok_job then
        local base = pup_buffer();
        if base ~= 0 then
            local ok, arr = pcall(ashita.memory.read_array, base, 0x9C);
            if ok and type(arr) == 'table' and #arr >= 0x9C then b = arr; end
        end
    end

    if b then
        PB.head, PB.frame = b[5], b[6];
        PB.cur = {};
        for i = 0, ATT_SLOTS - 1 do
            local v = b[7 + i];
            if v and v ~= 0 then PB.cur[#PB.cur + 1] = v; end
        end
        PB.heads, PB.frames = u32le(b, 0x14), u32le(b, 0x18);
        PB.att = {};
        local any = (PB.heads ~= 0) or (PB.frames ~= 0);
        for i = 0, 31 do
            PB.att[i] = b[0x35 + i];
            if PB.att[i] ~= 0 then any = true; end
        end
        PB.bonus   = b[0x99] or 0;
        PB.learned = any;
        PB.ok      = true;
    else
        PB.learned, PB.bonus, PB.cur = false, 0, {};
    end

    -- The lists the tab shows: what the character has learned (everything the client knows, if that can't be read)
    PB.heads_list, PB.frames_list, PB.att_list = {}, {}, {};
    for id = 1, 7 do
        if item_info(0x2000 + id) and (not PB.learned or bit_set(PB.heads, id)) then PB.heads_list[#PB.heads_list + 1] = id; end
    end
    for id = 32, 39 do
        if item_info(0x2000 + id) and (not PB.learned or bit_set(PB.frames, id - 32)) then PB.frames_list[#PB.frames_list + 1] = id; end
    end
    for id = 1, 254 do
        if ATT_COST[id] and item_info(0x2100 + id) then
            local has = true;
            if PB.learned then has = bit.band(bit.rshift(PB.att[math.floor(id / 8)] or 0, id % 8), 1) == 1; end
            if has then PB.att_list[#PB.att_list + 1] = id; end
        end
    end
    return PB;
end

-- Icons: the client keeps one for every item, made here at exactly the size it is drawn
local ICONS = {};
local function item_icon(itemid, px)
    local key = itemid .. '@' .. px;
    local c = ICONS[key];
    if c ~= nil then return c or nil; end
    ICONS[key] = false;
    pcall(function ()
        local it = AshitaCore:GetResourceManager():GetItemById(itemid);
        if it == nil or it.Bitmap == nil or (tonumber(it.ImageSize) or 0) == 0 then return; end
        local ptr = ffi.new('IDirect3DTexture8*[1]');
        if ffi.C.D3DXCreateTextureFromFileInMemoryEx(d3d.get_device(), it.Bitmap, it.ImageSize, px, px, 1, 0,
                ffi.C.D3DFMT_A8R8G8B8, ffi.C.D3DPOOL_MANAGED, 4, ffi.C.D3DX_DEFAULT, 0xFF000000, nil, nil, ptr) == ffi.C.S_OK then
            local t = d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', ptr[0]));
            ICONS[key] = { tex = t, ptr = tonumber(ffi.cast('uint32_t', t)) };
        end
    end);
    return ICONS[key] or nil;
end

-- The six sets: { head = id, frame = id, att = { ids } }, 0 / empty for none
local function aset(n)
    if type(cfg.asets) ~= 'table' then cfg.asets = {}; end
    local s = cfg.asets[n];
    if type(s) ~= 'table' then s = {}; cfg.asets[n] = s; end
    s.head, s.frame = tonumber(s.head) or 0, tonumber(s.frame) or 0;
    if type(s.att) ~= 'table' then s.att = {}; end
    if type(s.name) ~= 'string' then s.name = ''; end
    return s;
end
local function list_index(t, v)
    for i, x in ipairs(t) do if x == v then return i; end end
    return nil;
end
local function aset_summary(n)
    local s = aset(n);
    local h = (s.head ~= 0) and item_info(0x2000 + s.head) or nil;
    local f = (s.frame ~= 0) and item_info(0x2000 + s.frame) or nil;
    local nm = (s.name ~= '') and (' "' .. s.name .. '"') or '';
    return string.format('Set %d%s: %s / %s / %d attachment%s', n, nm, h and h.name or 'no head', f and f.name or 'no frame', #s.att, #s.att == 1 and '' or 's');
end

-- Capacity (cap) and what the set uses (used), per element in AEL order
local function totals(s)
    local cap, used = { 0, 0, 0, 0, 0, 0, 0, 0 }, { 0, 0, 0, 0, 0, 0, 0, 0 };
    for _, id in ipairs({ s.head or 0, s.frame or 0 }) do
        if id ~= 0 then
            local c = item_caps(id);
            for e = 1, 8 do cap[e] = cap[e] + c[e]; end
        end
    end
    if (s.head or 0) ~= 0 or (s.frame or 0) ~= 0 then
        local bonus = tonumber(PB.bonus) or 0;
        if bonus > 0 then for e = 1, 8 do cap[e] = cap[e] + bonus; end end
    end
    for _, id in ipairs(s.att) do
        local c = ATT_COST[id];
        if c then used[c[1]] = used[c[1]] + c[2]; end
    end
    return used, cap;
end

-- Copy the loadout the automaton has now into the active set
local function use_current()
    read_pup(true);
    if not PB.ok then return false, 'Can not read your automaton: PUP has to be your main or sub job.'; end
    local s = aset(cfg.aset);
    s.head  = (PB.head  >= 1  and PB.head  <= 7)  and PB.head  or 0;
    s.frame = (PB.frame >= 32 and PB.frame <= 39) and PB.frame or 0;
    s.att = {};
    for _, id in ipairs(PB.cur) do
        if ATT_COST[id] and not list_index(s.att, id) then s.att[#s.att + 1] = id; end
    end
    save();
    return true, string.format('Copied your current loadout into set %d.', cfg.aset);
end

----------------------------------------------------------------------------------------------------
-- "Equip now": Deactivate, change the loadout, Activate (or Deus Ex Automata)
-- One step a second, like pupsets' safe mode. Everything the automation does waits until it is over.
----------------------------------------------------------------------------------------------------
local EQ = { active = false, status = '' };
local EQ_GAP = 1.3;

local function eq_send(cmd) AshitaCore:GetChatManager():QueueCommand(1, cmd); end
local function eq_done(ok, msg)
    EQ.active, EQ.status = false, msg;
    st.busy = false;
    st.att_msg, st.att_ok, st.att_at = msg, ok, os.clock();
    print(chat.header(addon.name):append(ok and chat.message(msg) or chat.error(msg)));
end

local function eq_start()
    if EQ.active then return false, 'Already changing attachments.'; end
    if not PUPMEM.ok then return false, 'The game functions were not found (signature scan failed), so sets can not be applied.'; end
    if not (is_pup_main() or is_pup_sub()) then return false, 'PUP has to be your main or sub job.'; end
    local s = aset(cfg.aset);
    if s.head == 0 or s.frame == 0 then return false, 'Pick a head and a frame first.'; end
    read_pup(true);
    local used, cap = totals(s);
    for e = 1, 8 do
        if used[e] > cap[e] then return false, string.format('%s is over capacity (%d/%d).', AEL[e][1], used[e], cap[e]); end
    end
    if PB.learned then
        if not bit_set(PB.heads, s.head) or not bit_set(PB.frames, s.frame - 32) then
            return false, 'The head or frame in this set is not unlocked on this character.';
        end
        for _, id in ipairs(s.att) do
            if bit.band(bit.rshift(PB.att[math.floor(id / 8)] or 0, id % 8), 1) ~= 1 then
                local info = item_info(0x2100 + id);
                return false, (info and info.name or 'An attachment') .. ' is not unlocked on this character.';
            end
        end
    end
    local atts = {};
    for _, id in ipairs(s.att) do atts[#atts + 1] = id; end
    EQ = { active = true, phase = 'deactivate', set = cfg.aset, head = s.head, frame = s.frame, att = atts, wait = 0, status = 'Starting...' };
    st.busy = true;
    st.att_msg, st.att_ok = nil, nil;
    return true;
end

local function eq_tick()
    if not EQ.active then return; end
    local now = os.clock();
    if AshitaCore:GetMemoryManager():GetPlayer():GetIsZoning() ~= 0 then eq_done(false, 'Cancelled: you zoned.'); return; end
    if now < (EQ.wait or 0) then return; end

    local ph = EQ.phase;
    if ph == 'deactivate' then
        if st.pet then
            eq_send('/ja "Deactivate" <me>');
            EQ.deadline, EQ.phase, EQ.status = now + 8, 'gone', 'Deactivating...';
        else
            EQ.phase = 'queue';
        end

    elseif ph == 'gone' then
        if st.pet == nil then
            EQ.wait, EQ.phase = now + 1.5, 'queue';
        elseif now > EQ.deadline then
            eq_done(false, 'The automaton did not deactivate.');
        end

    elseif ph == 'queue' then
        local q = { { 'reset' }, { 'set', 1, EQ.head }, { 'set', 2, EQ.frame } };
        for i, id in ipairs(EQ.att) do q[#q + 1] = { 'set', 2 + i, id }; end
        EQ.q, EQ.n, EQ.i, EQ.phase = q, #q, 0, 'apply';

    elseif ph == 'apply' then
        EQ.i = EQ.i + 1;
        local op = EQ.q[EQ.i];
        if op == nil then EQ.phase = 'activate'; return; end
        local ok, err = pcall(function ()
            if op[1] == 'reset' then
                AshitaCore:GetPacketManager():QueuePacket(0x102, 0xA4, 0x00, 0x00, 0x00, function (ptr)
                    local p = ffi.cast('uint8_t*', ptr);
                    ffi.fill(p + 0x04, 0xA0);
                    ffi.copy(p + 0x08, ffi.cast('uint8_t*', pup_buffer()), 0x9C);
                    ffi.fill(p + 0x0C, 0x2);                         -- head and frame to none
                end);
            else
                PUPMEM.equipex(is_pup_main() and 0 or 1, 0x1200, op[2] - 1, op[3]);
            end
        end);
        if not ok then eq_done(false, 'Changing the attachments failed: ' .. tostring(err)); return; end
        EQ.wait, EQ.status = now + EQ_GAP, string.format('Equipping %d/%d...', EQ.i, EQ.n);

    elseif ph == 'activate' then
        local rc = recast_map();
        if (rc['Activate'] or 0) == 0 then
            eq_send('/ja "Activate" <me>');
            EQ.tried = 'Activate';
        elseif (rc['Deus Ex Automata'] or 0) == 0 then
            eq_send('/ja "Deus Ex Automata" <me>');
            EQ.tried = 'Deus Ex Automata';
        else
            eq_done(false, 'The attachments are set, but Activate and Deus Ex Automata are both recharging.');
            return;
        end
        EQ.deadline, EQ.phase, EQ.status = now + 4, 'pet', 'Activating (' .. EQ.tried .. ')...';

    elseif ph == 'pet' then
        if st.pet then
            eq_done(true, string.format('Attachment set %d equipped (%s).', EQ.set, EQ.tried));
        elseif now > EQ.deadline then
            if EQ.tried == 'Activate' and (recast_map()['Deus Ex Automata'] or 0) == 0 then
                eq_send('/ja "Deus Ex Automata" <me>');
                EQ.tried, EQ.deadline, EQ.status = 'Deus Ex Automata', now + 4, 'Activating (Deus Ex Automata)...';
            else
                eq_done(false, 'The attachments are set, but the automaton did not come out.');
            end
        end
    end
end


----------------------------------------------------------------------------------------------------
-- The work (every frame, before and apart from the window)
-- Returns false while zooming (the window hides then)
----------------------------------------------------------------------------------------------------
local function tick()
    local mm = AshitaCore:GetMemoryManager();
    local party, player, ent = mm:GetParty(), mm:GetPlayer(), mm:GetEntity();
    local now = os.clock();

    st.pet, st.paused, st.resting = nil, nil, false;
    if player:GetIsZoning() ~= 0 then st.enabled = false; return false; end

    local me   = party:GetMemberTargetIndex(0);
    local pet  = ent:GetPetTargetIndex(me) or 0;
    st.resting = (ent:GetStatus(me) == 33);                          -- 33 = Healing (resting)
    local zone = AshitaCore:GetResourceManager():GetString('zones.names', party:GetMemberZone(0));
    if pet ~= 0 then
        st.pet = { idx = pet, name = ent:GetName(pet) or '', hp = (ent:GetHPPercent(pet) or 0) / 100, mp = (player:GetPetMPPercent() or 0) / 100, tp = (player:GetPetTP() or 0) };
    end

    -- Oils change slowly: count them once a second
    if now - st.oils_at > 1 then st.oils, st.oil_best, st.oil_n, st.oil_counts = count_oils(); st.oils_at = now; end

    if st.busy then return true; end                                 -- (the attachment change is in charge)

    -- Stays Disabled in a town, off PUP, with no puppet out, or when dead
    if zone == nil or Towns:contains(zone) or st.pet == nil or player:GetMainJob() ~= PUP_JOB or party:GetMemberHPPercent(0) < 1 then
        st.enabled = false;
    end

    -- Auto Light: no change to your choices, the override just comes and goes with the pet's HP
    if st.pet and (tonumber(cfg.light_lo) or 0) > 0 then
        local php = st.pet.hp * 100;
        if php < cfg.light_lo then st.light_on = true;
        elseif php >= cfg.light_hi then st.light_on = false; end
    else
        st.light_on = false;
    end

    if not st.enabled then return true; end

    -- What is on you: maneuver counts, and anything that stops abilities
    local counts = {};
    for _, id in pairs(player:GetBuffs()) do
        if id ~= nil and id > 0 and id ~= 255 then
            local name = buff_name(id);
            if name ~= nil then
                counts[name] = (counts[name] or 0) + 1;
                if name == 'Mounted' then st.enabled = false; return true; end
                if BLOCKING[name] then st.paused = BLOCKING[name]; end
            end
        end
    end
    if st.paused then return true; end
    if now - st.last_cmd < CMD_GAP then return true; end

    local rc = recast_map();
    local function send(cmd)
        AshitaCore:GetChatManager():QueueCommand(1, cmd);
        st.last_cmd = now;
    end

    -- 1) Repair (the game uses the best oil you carry; the addon only needs one; not while resting)
    if (tonumber(cfg.repair) or 0) > 0 and not st.resting and (rc['Repair'] or 0) == 0 and oils_usable() > 0 and st.pet.hp * 100 < cfg.repair then
        local dist = math.sqrt(tonumber(ent:GetDistance(st.pet.idx)) or 0);      -- (GetDistance is squared)
        if dist < 20 then send('/ja "Repair" <me>'); return true; end
    end

    -- 2) Deploy: you are fighting, the puppet is idle, and the mob isn't about to die
    local target = mm:GetTarget():GetTargetIndex(0);
    if cfg.deploy and target ~= nil and target ~= 0 and ent:GetStatus(me) == 1 and ent:GetStatus(st.pet.idx) == 0
       and (ent:GetHPPercent(target) or 0) > 10 then
        send('/ja "Deploy" <t>'); return true;
    end

    -- 3) Maneuvers: the first slot (in order) that has fewer of its maneuver up than the slots ask for
    -- (not while resting: a job ability would stand you up)
    if (rc['Fire Maneuver'] or 0) == 0 and (counts['Overload'] or 0) == 0 and not st.resting then
        local slots = { cfg.m1, cfg.m2, cfg.m3 };
        if st.light_on then slots[1] = 1; end                        -- (1 = Light)
        local need = {};
        for _, el in ipairs(slots) do
            if el ~= nil and el >= 0 and el <= 7 then
                local name = ELEMENTS[el + 1] .. ' Maneuver';
                need[name] = (need[name] or 0) + 1;
                if (counts[name] or 0) < need[name] then
                    send('/ja "' .. name .. '" <me>'); return true;
                end
            end
        end
    end
    return true;
end

----------------------------------------------------------------------------------------------------
-- Look: YunaUI's palette and controls
----------------------------------------------------------------------------------------------------
local C = {
    text  = { 0.910, 0.922, 0.957, 1.00 },
    muted = { 0.545, 0.576, 0.667, 1.00 },
    acc   = { 0.74, 0.66, 0.95, 1.00 },                              -- soft lavender
    pbg   = { 0.068, 0.066, 0.088 },                                 -- near-black with a hint of violet
    pframe= { 0.165, 0.158, 0.205 },
    hp    = { 1.000, 0.36, 0.62 }, hp2 = { 0.86, 0.24, 0.86 },       -- pink to magenta
    mp    = { 0.40, 0.55, 1.00 },  mp2 = { 0.62, 0.40, 1.00 },       -- blue to violet
    gold  = { 1.00, 0.90, 0.58 },
    rall  = ImDrawFlags_RoundCornersAll or ImDrawCornerFlags_All or 15,
};
local NEON  = { 0.86, 0.24, 0.86 };
local NEON2 = { 1.00, 0.42, 0.72 };
local ROW_W = 340;
local OUTLINE = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } };

-- The element colours (the minimized bar's dots); grey for no maneuver
local EL_COL = {
    [0] = { 0.34, 0.26, 0.62 },                                      -- Dark
    [1] = { 1.00, 0.98, 0.84 },                                      -- Light
    [2] = { 0.82, 0.64, 0.28 },                                      -- Earth
    [3] = { 0.45, 0.90, 0.55 },                                      -- Wind
    [4] = { 1.00, 0.34, 0.26 },                                      -- Fire
    [5] = { 0.55, 0.88, 1.00 },                                      -- Ice
    [6] = { 0.80, 0.50, 1.00 },                                      -- Thunder
    [7] = { 0.35, 0.55, 1.00 },                                      -- Water
};
local NONE_COL = { 0.36, 0.35, 0.42 };

local function u32(c) return imgui.GetColorU32(c); end
local function frac(v) return v - math.floor(v); end

local function outlined(dl, x, y, s, col)
    local oc = u32({ 0, 0, 0, 0.9 * (col[4] or 1) });
    for _, o in ipairs(OUTLINE) do dl:AddText({ x + o[1], y + o[2] }, oc, s); end
    dl:AddText({ x, y }, u32(col), s);
end

-- Tooltips: a dark violet card with a thin violet edge and a pink-to-violet line along the top
local function tip(t)
    t = tostring(t or '');
    if not (imgui.BeginTooltip and imgui.EndTooltip) then imgui.SetTooltip(t); return; end
    imgui.PushStyleVar(ImGuiStyleVar_Alpha, 1);                       -- (a faded bar's tooltip stays readable)
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 6);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 7, 3 });
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 1);
    imgui.PushStyleColor(ImGuiCol_PopupBg, { 0.045, 0.040, 0.065, 0.96 });
    imgui.PushStyleColor(ImGuiCol_Border, { 0.62, 0.40, 1.00, 0.55 });
    imgui.PushStyleColor(ImGuiCol_Text, { 0.93, 0.92, 0.98, 1 });
    if imgui.BeginTooltip() ~= false then
        imgui.Text(t);
        pcall(function()
            local dl = imgui.GetWindowDrawList();
            local wx, wy = imgui.GetWindowPos();
            local ww = imgui.GetWindowSize();
            if type(wx) == 'table' then wx, wy = wx.x or wx[1], wx.y or wx[2]; end
            if type(ww) == 'table' then ww = ww.x or ww[1]; end
            local p1, p2 = u32({ 1.0, 0.36, 0.62, 0.9 }), u32({ 0.62, 0.40, 1.0, 0.9 });
            dl:AddRectFilledMultiColor({ wx + 6, wy + 1 }, { wx + ww - 6, wy + 2 }, p1, p2, p2, p1);
        end);
        imgui.EndTooltip();
    end
    imgui.PopStyleColor(3);
    imgui.PopStyleVar(4);
end

local function push_theme()
    local cols = {
        { ImGuiCol_WindowBg, { C.pbg[1], C.pbg[2], C.pbg[3], 0.92 } }, { ImGuiCol_ChildBg, { 0, 0, 0, 0 } }, { ImGuiCol_PopupBg, { C.pbg[1], C.pbg[2], C.pbg[3], 0.98 } },
        { ImGuiCol_Border, { 1, 1, 1, 0.08 } }, { ImGuiCol_Text, C.text }, { ImGuiCol_TextDisabled, C.muted },
        { ImGuiCol_FrameBg, { C.pframe[1], C.pframe[2], C.pframe[3], 0.70 } }, { ImGuiCol_FrameBgHovered, { 0.22, 0.21, 0.27, 1 } }, { ImGuiCol_FrameBgActive, { 0.22, 0.21, 0.27, 1 } },
        { ImGuiCol_Button, { 1, 1, 1, 0.035 } }, { ImGuiCol_ButtonHovered, { 1, 1, 1, 0.08 } }, { ImGuiCol_ButtonActive, { 1, 1, 1, 0.12 } },
        { ImGuiCol_Separator, { 1, 1, 1, 0.07 } },
    };
    local nc, nv = 0, 0;                                             -- (any name this ImGui doesn't have is skipped)
    for _, c in ipairs(cols) do if c[1] ~= nil then imgui.PushStyleColor(c[1], c[2]); nc = nc + 1; end end
    local vars = {
        { ImGuiStyleVar_WindowRounding, 12 }, { ImGuiStyleVar_FrameRounding, 8 },
        { ImGuiStyleVar_WindowPadding, { 20, 16 } }, { ImGuiStyleVar_FramePadding, { 10, 6 } },
        { ImGuiStyleVar_ItemSpacing, { 8, 8 } }, { ImGuiStyleVar_WindowBorderSize, 1 }, { ImGuiStyleVar_FrameBorderSize, 0 },
    };
    for _, v in ipairs(vars) do if v[1] ~= nil then imgui.PushStyleVar(v[1], v[2]); nv = nv + 1; end end
    return nc, nv;
end

-- Text with letter spacing (section names, buttons)
local function spaced(dl, x, y, str, col, gap)
    local cx = x;
    for i = 1, #str do
        local ch = str:sub(i, i);
        dl:AddText({ cx, y }, col, ch);
        cx = cx + imgui.CalcTextSize(ch) + gap;
    end
    return cx - x - gap;
end
local function spaced_w(str, gap)
    local w = 0;
    for i = 1, #str do w = w + imgui.CalcTextSize(str:sub(i, i)) + gap; end
    return w - gap;
end

-- A thin living bar: glowing edge, colours flowing along inside it, a sheen that sweeps along now and then
local function glow_bar(dl, x, y, w, h, v, c1, c2, seed)
    v = math.max(0, math.min(1, v or 0));
    seed = seed or 0;
    local now = os.clock();
    dl:AddRectFilled({ x, y }, { x + w, y + h }, u32({ 0.05, 0.04, 0.07, 0.70 }), h / 2);
    if v <= 0 then return; end
    local fw = w * v;
    local pulse = 0.5 + 0.5 * math.sin(now * 2.2 + seed);
    for k = 1, 4 do
        dl:AddRectFilled({ x - k, y - k }, { x + fw + k, y + h + k }, u32({ c2[1], c2[2], c2[3], (0.11 - k * 0.022) * (0.75 + 0.5 * pulse) }), h / 2 + k);
    end
    dl:AddRectFilled({ x - 1, y - 1 }, { x + fw + 1, y + h + 1 }, u32({ c2[1], c2[2], c2[3], 0.85 }), h / 2 + 1);
    local ph = now * 0.35 + seed * 0.21;
    local r_ = math.min(h / 2, fw / 2);
    local function colx(px)
        local f = (px - x) / w;
        local u = 0.5 + 0.5 * math.sin((f * 1.6 - ph) * math.pi * 2);
        return u32({ c1[1] + (c2[1] - c1[1]) * u, c1[2] + (c2[2] - c1[2]) * u, c1[3] + (c2[3] - c1[3]) * u, 1 });
    end
    dl:AddRectFilled({ x, y }, { x + math.min(fw, h), y + h }, colx(x), r_);
    dl:AddRectFilled({ x + fw - math.min(fw, h), y }, { x + fw, y + h }, colx(x + fw), r_);
    local segs = math.max(4, math.floor(w / 40));
    for k = 0, segs - 1 do
        local x1, x2 = math.max(x + r_, x + w * k / segs), math.min(x + fw - r_, x + w * (k + 1) / segs);
        if x2 > x1 then
            local a, b = colx(x1), colx(x2);
            pcall(function() dl:AddRectFilledMultiColor({ x1, y }, { x2, y + h }, a, b, b, a); end);
        end
    end
    local sp = frac(now * 0.32 + seed * 0.137);
    local hx, hw = x - 40 + sp * (fw + 80), 40;
    local function band(x1, x2, a1, a2)
        local cx1, cx2 = math.max(x + r_, x1), math.min(x + fw - r_, x2);
        if cx2 <= cx1 then return; end
        local f1, f2 = (cx1 - x1) / (x2 - x1), (cx2 - x1) / (x2 - x1);
        local b1, b2 = a1 + (a2 - a1) * f1, a1 + (a2 - a1) * f2;
        pcall(function() dl:AddRectFilledMultiColor({ cx1, y }, { cx2, y + h }, u32({ 1, 1, 1, b1 }), u32({ 1, 1, 1, b2 }), u32({ 1, 1, 1, b2 }), u32({ 1, 1, 1, b1 })); end);
    end
    band(hx - hw, hx, 0, 0.55);
    band(hx, hx + hw, 0.55, 0);
end

-- The pill switch
local function switch(id, on)
    local x, y = imgui.GetCursorScreenPos();
    local w, h = 52, 26;
    local clicked = imgui.InvisibleButton(id, { w, h });
    local hov = imgui.IsItemHovered();
    local dl = imgui.GetWindowDrawList();
    dl:AddRectFilled({ x, y }, { x + w, y + h }, u32(on and { NEON[1] * 0.42, NEON[2] * 0.42, NEON[3] * 0.42, 1 } or (hov and { 0.14, 0.13, 0.18, 1 } or { 0.10, 0.095, 0.13, 1 })), h / 2);
    dl:AddCircleFilled({ on and (x + w - h / 2) or (x + h / 2), y + h / 2 }, h / 2 - 4, u32(on and { 1, 1, 1, 1 } or { 0.55, 0.53, 0.62, 1 }), 24);
    return clicked;
end

local function row_switch(id, label, key, hint)
    local x0 = imgui.GetCursorPosX();
    imgui.AlignTextToFramePadding();
    imgui.TextColored(C.text, label);
    if hint and imgui.IsItemHovered() then tip(hint); end
    imgui.SameLine(x0 + ROW_W - 52);
    if switch(id, cfg[key] == true) then
        cfg[key] = not (cfg[key] == true);
        save();
    end
end

-- A slider on one line: the name, a violet track, the value at the end. Double click puts it back to normal.
local function row_slider(id, label, key, lo, hi, step, fmt, hint)
    local function show(v) if type(fmt) == 'function' then return fmt(v); end return string.format(fmt, v); end
    local v = tonumber(cfg[key]) or lo;
    local x0 = imgui.GetCursorPosX();
    imgui.AlignTextToFramePadding();
    imgui.TextColored(C.text, label);
    if hint and imgui.IsItemHovered() then tip(hint); end
    local lw = imgui.CalcTextSize(label);
    local text = show(v);
    local vw = imgui.CalcTextSize(text);
    local tl = math.max(lw + 24, ROW_W * 0.34);
    local tr = ROW_W - math.max(vw, 44) - 22;
    imgui.SameLine(x0 + tl);
    local x, y = imgui.GetCursorScreenPos();
    local w, h = math.max(40, tr - tl), imgui.GetFrameHeight();
    imgui.InvisibleButton(id, { w, h });
    local act, hov = imgui.IsItemActive(), imgui.IsItemHovered();
    if act then
        local mx = imgui.GetMousePos();
        local f = math.max(0, math.min(1, (mx - x) / w));
        local nv = lo + math.floor((f * (hi - lo)) / step + 0.5) * step;
        if math.abs(nv - v) > step * 0.01 then cfg[key] = nv; v = nv; text = show(v); end
    end
    if imgui.IsItemDeactivated() then save(); end
    if hov and imgui.IsMouseDoubleClicked(0) then cfg[key] = defaults[key]; v = defaults[key]; text = show(v); save(); end
    local dl = imgui.GetWindowDrawList();
    local f = math.max(0, math.min(1, (v - lo) / (hi - lo)));
    local cy = y + h / 2;
    local th = 6;
    dl:AddRectFilled({ x, cy - th / 2 }, { x + w, cy + th / 2 }, u32({ 0.20, 0.19, 0.25, 1 }), th / 2);
    local ok_ = pcall(function()
        dl:AddRectFilledMultiColor({ x, cy - th / 2 }, { x + w * f, cy + th / 2 }, u32(NEON), u32(NEON2), u32(NEON2), u32(NEON));
    end);
    if not ok_ then dl:AddRectFilled({ x, cy - th / 2 }, { x + w * f, cy + th / 2 }, u32(NEON), th / 2); end
    dl:AddCircleFilled({ x + w * f, cy }, (act or hov) and 13 or 11, u32({ NEON[1], NEON[2], NEON[3], 0.30 }), 24);
    dl:AddCircleFilled({ x + w * f, cy }, 8, u32({ 1, 1, 1, 1 }), 24);
    imgui.SameLine(x0 + ROW_W - vw);
    imgui.TextColored(C.text, text);
end

-- A choice: the name on the left, a dark pill on the right with the current one and a small arrow
local function row_pick(id, label, key, opts, hint)
    local x0 = imgui.GetCursorPosX();
    imgui.AlignTextToFramePadding();
    imgui.TextColored(C.text, label);
    if hint and imgui.IsItemHovered() then tip(hint); end
    local cur = 1;
    for k, o in ipairs(opts) do if o[1] == cfg[key] then cur = k; end end
    local bw, bh = math.floor(ROW_W * 0.55), imgui.GetFrameHeight();
    imgui.SameLine(x0 + ROW_W - bw);
    local bx, by = imgui.GetCursorScreenPos();
    local clicked = imgui.InvisibleButton(id, { bw, bh });
    local hov = imgui.IsItemHovered();
    local dl = imgui.GetWindowDrawList();
    dl:AddRectFilled({ bx, by }, { bx + bw, by + bh }, u32(hov and { 0.15, 0.14, 0.19, 1 } or { 0.10, 0.09, 0.13, 1 }), bh / 2);
    dl:AddRect({ bx, by }, { bx + bw, by + bh }, u32(hov and { NEON2[1], NEON2[2], NEON2[3], 0.45 } or { 1, 1, 1, 0.10 }), bh / 2, C.rall, 1);
    local name = opts[cur][2];
    local lw, lh = imgui.CalcTextSize(name);
    dl:AddText({ bx + (bw - lw) / 2, by + (bh - lh) / 2 }, u32({ 0.93, 0.92, 0.98, 1 }), name);
    local ax, ay, r = bx + bw - 22, by + bh / 2, 4.5;
    local ac = u32({ 0.85, 0.83, 0.95, hov and 1 or 0.75 });
    dl:AddLine({ ax - r, ay - r * 0.5 }, { ax, ay + r * 0.5 }, ac, 1.5);
    dl:AddLine({ ax, ay + r * 0.5 }, { ax + r, ay - r * 0.5 }, ac, 1.5);
    if clicked then imgui.OpenPopup(id .. '_list'); end
    local pv = 0;
    for _, v in ipairs({ { ImGuiStyleVar_WindowPadding, { 12, 10 } }, { ImGuiStyleVar_ItemSpacing, { 6, 6 } },
                         { ImGuiStyleVar_PopupRounding, 8 }, { ImGuiStyleVar_PopupBorderSize, 1 } }) do
        if v[1] ~= nil then imgui.PushStyleVar(v[1], v[2]); pv = pv + 1; end
    end
    imgui.PushStyleColor(ImGuiCol_PopupBg, { 0.055, 0.050, 0.075, 0.98 });
    imgui.PushStyleColor(ImGuiCol_Border, { 1, 1, 1, 0.10 });
    imgui.PushStyleColor(ImGuiCol_Header, { 1, 1, 1, 0.12 });
    imgui.PushStyleColor(ImGuiCol_HeaderHovered, { 1, 1, 1, 0.08 });
    imgui.PushStyleColor(ImGuiCol_HeaderActive, { 1, 1, 1, 0.16 });
    if imgui.BeginPopup(id .. '_list') then
        for k, o in ipairs(opts) do
            if imgui.Selectable('  ' .. o[2] .. '##' .. id .. k, k == cur, 0, { bw, 0 }) then
                cfg[key] = o[1];
                save();
            end
        end
        imgui.EndPopup();
    end
    imgui.PopStyleColor(5);
    imgui.PopStyleVar(pv);
end

-- A section's name: spaced capitals, a faint line on to the edge
local function section(label, right_w)
    imgui.Spacing(); imgui.Spacing();
    local dl = imgui.GetWindowDrawList();
    local x0, y0 = imgui.GetCursorScreenPos();
    local lh = imgui.GetTextLineHeight();
    local tw = spaced(dl, x0, y0, label:upper(), u32({ 0.93, 0.90, 1.00, 1 }), 2.5);
    local xe = x0 + ROW_W - ((right_w or 0) > 0 and (right_w + 10) or 0);
    if xe > x0 + tw + 18 then dl:AddLine({ x0 + tw + 18, y0 + lh / 2 }, { xe, y0 + lh / 2 }, u32({ 1, 1, 1, 0.08 }), 1); end
    imgui.Dummy({ ROW_W, lh + 2 });
    return x0, y0, lh;
end

-- A rounded button: violet-edged (the main one) or dark (quiet), its name in spaced capitals
local function accent_button(label, quiet, wid)
    local w = wid or ROW_W;
    local h = math.floor(imgui.GetFrameHeight() * 1.25);
    local x, y = imgui.GetCursorScreenPos();
    local clicked = imgui.InvisibleButton(label, { w, h });
    local hov, act = imgui.IsItemHovered(), imgui.IsItemActive();
    local dl = imgui.GetWindowDrawList();
    local rr = math.min(h * 0.45, 14);
    local fill = { 0.10, 0.09, 0.13, 1 };
    if hov or act then fill = act and { 0.18, 0.17, 0.23, 1 } or { 0.15, 0.14, 0.19, 1 }; end
    dl:AddRectFilled({ x, y }, { x + w, y + h }, u32(fill), rr);
    local ec = u32(quiet and { 1, 1, 1, hov and 0.25 or 0.14 } or { NEON2[1], NEON2[2], NEON2[3], hov and 1 or 0.8 });
    dl:AddRect({ x, y }, { x + w, y + h }, ec, rr, C.rall, quiet and 1 or 1.6);
    local name = label:gsub('##.*$', ''):upper();
    local lw = spaced_w(name, 3);
    local lh = imgui.GetTextLineHeight();
    spaced(dl, x + (w - lw) / 2, y + (h - lh) / 2, name, u32({ 0.93, 0.91, 0.98, 1 }), 3);
    return clicked;
end

-- A small round button at the top right: kind 'min' (a dash) or 'close' (a cross)
local function icon_button(id, x, y, kind)
    local d = 18;
    imgui.SetCursorScreenPos({ x, y });
    local clicked = imgui.InvisibleButton(id, { d, d });
    local hov = imgui.IsItemHovered();
    local dl = imgui.GetWindowDrawList();
    local cx, cy = x + d / 2, y + d / 2;
    dl:AddCircleFilled({ cx, cy }, d / 2, u32(hov and { 0.15, 0.14, 0.19, 1 } or { 0.10, 0.09, 0.13, 1 }), 24);
    dl:AddCircle({ cx, cy }, d / 2, u32(hov and { NEON2[1], NEON2[2], NEON2[3], 0.8 } or { 1, 1, 1, 0.12 }), 24, 1);
    local ic = u32({ 0.93, 0.91, 0.98, hov and 1 or 0.75 });
    if kind == 'min' then
        dl:AddLine({ cx - 4, cy }, { cx + 4, cy }, ic, 1.6);
    else
        dl:AddLine({ cx - 3.5, cy - 3.5 }, { cx + 3.5, cy + 3.5 }, ic, 1.6);
        dl:AddLine({ cx - 3.5, cy + 3.5 }, { cx + 3.5, cy - 3.5 }, ic, 1.6);
    end
    return clicked, hov;
end

-- The title: PUP in white, the rest flowing between pink and violet; the oils count and the minimize / close buttons
-- at the right edge. Returns what was clicked: 'min', 'close' or nil.
local function header(dl)
    local full = 'PUPHQ';
    imgui.SetWindowFontScale(1.3);
    local t = os.clock();
    local x0, y0 = imgui.GetCursorScreenPos();
    local tw, lh = imgui.CalcTextSize(full);
    for i = 1, #full do
        local ch = full:sub(i, i);
        local cx = x0 + imgui.CalcTextSize(full:sub(1, i - 1));
        local col = C.text;
        if i > 3 then
            local u = 0.5 + 0.5 * math.sin(t * 1.2 - i * 0.45);
            col = { C.hp[1] + (C.mp2[1] - C.hp[1]) * u, C.hp[2] + (C.mp2[2] - C.hp[2]) * u, C.hp[3] + (C.mp2[3] - C.hp[3]) * u, 1 };
        end
        dl:AddText({ cx, y0 }, u32(col), ch);
    end
    imgui.Dummy({ tw, lh });
    imgui.SetWindowFontScale(1);
    local sx, sy = imgui.GetCursorScreenPos();                       -- (where the layout goes on from)

    local d, gap = 18, 6;
    local by = y0 + (lh - d) / 2;
    local clicked = nil;
    local c_close, h_close = icon_button('##ph_close', x0 + ROW_W - d, by, 'close');
    local c_min, h_min     = icon_button('##ph_min', x0 + ROW_W - 2 * d - gap, by, 'min');
    if h_close then tip('Hide the window (/puphq config brings it back)'); elseif h_min then tip('Minimize to a small bar'); end
    if c_close then clicked = 'close'; elseif c_min then clicked = 'min'; end
    imgui.SetCursorScreenPos({ sx, sy });

    return clicked;
end

-- The puppet: its name and HP%, an HP and an MP bar like YunaUI's pet bar
local function pet_block(dl)
    local x, y = imgui.GetCursorScreenPos();
    local p = st.pet;
    if p == nil then
        dl:AddText({ x, y }, u32(C.muted), 'No puppet out');
        imgui.Dummy({ ROW_W, imgui.GetTextLineHeight() + 4 });
        return;
    end
    local nw, nh = imgui.CalcTextSize(p.name);
    outlined(dl, x, y, p.name, { 1, 1, 1, 1 });
    local parts = {
        { string.format('HP %d%%', math.floor(p.hp * 100 + 0.5)), { 1, 0.85, 0.92, 1 } },
        { string.format('MP %d%%', math.floor(p.mp * 100 + 0.5)), { 0.75, 0.88, 1, 1 } },
        { string.format('TP %d', p.tp or 0), { C.gold[1], C.gold[2], C.gold[3], 1 } },
    };
    local px = x + ROW_W;
    for i = #parts, 1, -1 do
        px = px - imgui.CalcTextSize(parts[i][1]);
        outlined(dl, px, y, parts[i][1], parts[i][2]);
        px = px - 10;
    end
    local cy = y + nh + 5;
    glow_bar(dl, x, cy, ROW_W, 4, p.hp, C.hp, C.hp2, 6.1);
    cy = cy + 4 + 5;
    glow_bar(dl, x, cy, ROW_W, 3, p.mp, C.mp, C.mp2, 6.7);
    cy = cy + 3 + 4;
    imgui.Dummy({ ROW_W, cy - y + 2 });
end

-- The maneuver set buttons (1 2 3) at the right of the MANEUVERS header
local SET_BTN_W, SET_BTN_GAP = 24, 4;
local function set_buttons(x, y, lh)
    local ax, ay = imgui.GetCursorScreenPos();                       -- (where the layout goes on from)
    local h = lh + 1;
    local dl = imgui.GetWindowDrawList();
    for i = 1, NSETS do
        imgui.SetCursorScreenPos({ x + (i - 1) * (SET_BTN_W + SET_BTN_GAP), y });
        local clicked = imgui.InvisibleButton('##ph_set' .. i, { SET_BTN_W, h });
        local hov = imgui.IsItemHovered();
        local on = (cfg.set == i);
        local bx, by = x + (i - 1) * (SET_BTN_W + SET_BTN_GAP), y;
        dl:AddRectFilled({ bx, by }, { bx + SET_BTN_W, by + h }, u32(on and { NEON[1] * 0.42, NEON[2] * 0.42, NEON[3] * 0.42, 1 } or (hov and { 0.15, 0.14, 0.19, 1 } or { 0.10, 0.09, 0.13, 1 })), h / 2);
        dl:AddRect({ bx, by }, { bx + SET_BTN_W, by + h }, u32(on and { NEON2[1], NEON2[2], NEON2[3], 0.9 } or { 1, 1, 1, hov and 0.25 or 0.12 }), h / 2, C.rall, 1);
        local label = tostring(i);
        local tw, th = imgui.CalcTextSize(label);
        dl:AddText({ bx + (SET_BTN_W - tw) / 2, by + (h - th) / 2 }, u32(on and { 1, 1, 1, 1 } or { 0.75, 0.73, 0.85, 1 }), label);
        if hov then tip('Maneuver set ' .. i .. ': ' .. set_summary(i)); end
        if clicked then switch_set(i); end
    end
    imgui.SetCursorScreenPos({ ax, ay });
end

-- The "Preview" checkbox at the right of the MINIMIZED header: shows the bar while this panel is open
local function preview_check(x, y, lh)
    local ax, ay = imgui.GetCursorScreenPos();                       -- (where the layout goes on from)
    local box = 14;
    local tw, th = imgui.CalcTextSize('Preview');
    local rh = lh + 2;
    imgui.SetCursorScreenPos({ x, y });
    local clicked = imgui.InvisibleButton('##ph_preview', { box + 6 + tw, rh });
    local hov = imgui.IsItemHovered();
    local on = (st.preview == true);
    local dl = imgui.GetWindowDrawList();
    local by = y + (rh - box) / 2;
    dl:AddRectFilled({ x, by }, { x + box, by + box }, u32(on and { NEON[1] * 0.42, NEON[2] * 0.42, NEON[3] * 0.42, 1 } or (hov and { 0.15, 0.14, 0.19, 1 } or { 0.10, 0.09, 0.13, 1 })), 4);
    dl:AddRect({ x, by }, { x + box, by + box }, u32(on and { NEON2[1], NEON2[2], NEON2[3], 0.9 } or { 1, 1, 1, hov and 0.25 or 0.14 }), 4, C.rall, 1);
    if on then
        local ck = u32({ 1, 1, 1, 1 });
        dl:AddLine({ x + 3.5, by + 7.5 }, { x + 6, by + 10 }, ck, 1.8);
        dl:AddLine({ x + 6, by + 10 }, { x + 10.5, by + 4.5 }, ck, 1.8);
    end
    dl:AddText({ x + box + 6, y + (rh - th) / 2 }, u32(on and { 0.93, 0.92, 0.98, 1 } or { 0.75, 0.73, 0.85, 1 }), 'Preview');
    if hov then tip('Show the minimized bar while this panel is open, to size and place it.'); end
    if clicked then st.preview = not on; end
    imgui.SetCursorScreenPos({ ax, ay });
end

-- "Show commands": a collapsible list, one command per line, left aligned
local COMMANDS = {
    { '/puphq config',         'open or close the config panel (any job)' },
    { '/puphq ad toggle',     'toggle auto deploy' },
    { '/puphq toggle',         'enable or disable' },
    { '/puphq manset next',    'next maneuver set' },
    { '/puphq manset prev',    'previous maneuver set' },
    { '/puphq manset 1|2|3',   'pick a maneuver set' },
};
local function commands_block()
    local x, y = imgui.GetCursorScreenPos();
    local h = imgui.GetTextLineHeight() + 4;
    local clicked = imgui.InvisibleButton('##ph_cmds', { ROW_W, h });
    local hov = imgui.IsItemHovered();
    local open = cfg.cmds_open == true;
    local dl = imgui.GetWindowDrawList();
    local cx, cy, r = x + 7, y + h / 2, 4;
    local ac = u32({ 0.85, 0.83, 0.95, hov and 1 or 0.7 });
    if open then
        dl:AddLine({ cx - r, cy - r * 0.5 }, { cx, cy + r * 0.5 }, ac, 1.5);
        dl:AddLine({ cx, cy + r * 0.5 }, { cx + r, cy - r * 0.5 }, ac, 1.5);
    else
        dl:AddLine({ cx - r * 0.5, cy - r }, { cx + r * 0.5, cy }, ac, 1.5);
        dl:AddLine({ cx + r * 0.5, cy }, { cx - r * 0.5, cy + r }, ac, 1.5);
    end
    dl:AddText({ x + 20, y + 2 }, ac, open and 'Hide commands' or 'Show commands');
    if clicked then cfg.cmds_open = not open; save(); end
    if not open then return; end

    local pushed = 0;
    if ImGuiStyleVar_ItemSpacing ~= nil then imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 8, 3 }); pushed = 1; end
    local x0 = imgui.GetCursorPosX();
    for _, c in ipairs(COMMANDS) do
        imgui.TextColored(C.acc, c[1]);
        imgui.SameLine(x0 + 205);
        imgui.TextColored(C.muted, c[2]);
    end
    if pushed > 0 then imgui.PopStyleVar(pushed); end
end

----------------------------------------------------------------------------------------------------
-- The window
----------------------------------------------------------------------------------------------------
local MAN_OPTS = { { -1, 'None' } };
for i, el in ipairs(ELEMENTS) do MAN_OPTS[#MAN_OPTS + 1] = { i - 1, el }; end

local WIN_FLAGS = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_AlwaysAutoResize,
    ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_NoFocusOnAppearing,
    ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoSavedSettings);

-- remember where the window was dragged to (kx / ky: the settings that hold its position)
local function remember_pos(kx, ky)
    kx, ky = kx or 'win_x', ky or 'win_y';
    local wx, wy = imgui.GetWindowPos();
    if type(wx) == 'number' and (math.abs(wx - (tonumber(cfg[kx]) or 0)) > 0.5 or math.abs(wy - (tonumber(cfg[ky]) or 0)) > 0.5) then
        cfg[kx], cfg[ky] = wx, wy;
        if not imgui.IsMouseDown(0) then save(); end
    end
end

-- The oils in your inventory: a ticked box for each kind you carry, and how many, with the total underneath
local function oil_block()
    local counts = st.oil_counts or {};
    local dl = imgui.GetWindowDrawList();
    local lh = imgui.GetTextLineHeight();
    for _, name in ipairs(OILS) do
        local n = counts[name] or 0;
        local x, y = imgui.GetCursorScreenPos();
        local h = lh + 4;
        local clicked = imgui.InvisibleButton('##ph_oil_' .. name, { ROW_W, h });
        local hov = imgui.IsItemHovered();
        if type(cfg.oil_off) ~= 'table' then cfg.oil_off = {}; end
        if clicked then cfg.oil_off[name] = (not cfg.oil_off[name]) or nil; save(); end
        if hov then tip('Tick = Auto Repair may count on this oil. If none of the ticked kinds are in your inventory, it will not fire. (The game decides which oil a Repair actually uses.)'); end
        local on = not cfg.oil_off[name];
        local cx, cy, half = x + 11, y + h / 2, 6;
        dl:AddRectFilled({ cx - half, cy - half }, { cx + half, cy + half }, u32(on and { NEON[1] * 0.42, NEON[2] * 0.42, NEON[3] * 0.42, 1 } or (hov and { 0.15, 0.14, 0.19, 1 } or { 0.10, 0.09, 0.13, 1 })), 4);
        dl:AddRect({ cx - half, cy - half }, { cx + half, cy + half }, u32(on and { NEON2[1], NEON2[2], NEON2[3], 0.9 } or { 1, 1, 1, hov and 0.3 or 0.14 }), 4, C.rall, 1);
        if on then
            local ck = u32({ 1, 1, 1, 1 });
            dl:AddLine({ cx - 3, cy + 0.2 }, { cx - 0.8, cy + 2.6 }, ck, 1.7);
            dl:AddLine({ cx - 0.8, cy + 2.6 }, { cx + 3.3, cy - 2.6 }, ck, 1.7);
        end
        dl:AddText({ x + 26, y + 2 }, u32((on and n > 0) and C.text or C.muted), name);
        local ns = tostring(n);
        local nw = imgui.CalcTextSize(ns);
        dl:AddText({ x + ROW_W - nw - 2, y + 2 }, u32(n > 0 and { C.gold[1], C.gold[2], C.gold[3], 1 } or C.muted), ns);
    end
    local x, y = imgui.GetCursorScreenPos();
    imgui.Dummy({ ROW_W, lh + 4 });
    dl:AddLine({ x, y + 1 }, { x + ROW_W, y + 1 }, u32({ 1, 1, 1, 0.08 }), 1);
    local total = tostring(st.oils or 0);
    local tw = imgui.CalcTextSize(total);
    dl:AddText({ x + 26, y + 3 }, u32(C.text), 'Total in inventory');
    dl:AddText({ x + ROW_W - tw - 2, y + 3 }, u32((st.oils or 0) > 0 and { C.gold[1], C.gold[2], C.gold[3], 1 } or { 1, 0.55, 0.65, 1 }), total);
end

local function draw_ui()
    imgui.SetNextWindowPos({ tonumber(cfg.win_x) or 200, tonumber(cfg.win_y) or 200 }, ImGuiCond_FirstUseEver);
    local nc, nv = push_theme();
    if imgui.Begin('PUPHQ##puphq_win', { true }, WIN_FLAGS) then
        local dl = imgui.GetWindowDrawList();

        local hit = header(dl);
        imgui.Spacing();
        pet_block(dl);

        local sets_w = NSETS * SET_BTN_W + (NSETS - 1) * SET_BTN_GAP;
        local hx, hy, hlh = section('Maneuvers', sets_w);
        set_buttons(hx + ROW_W - sets_w, hy, hlh);
        row_pick('##ph_m1', 'Maneuver 1', 'm1', MAN_OPTS, 'The first one. Auto Light below takes this slot over when your puppet is hurt.');
        row_pick('##ph_m2', 'Maneuver 2', 'm2', MAN_OPTS);
        row_pick('##ph_m3', 'Maneuver 3', 'm3', MAN_OPTS, 'Pick the same one twice (or three times) to keep two (or three) of it up.');

        section('Automation');
        row_slider('##ph_rep', 'Auto Repair', 'repair', 0, 100, 1,
            function(v) return (v <= 0) and 'OFF' or string.format('%d%%', v); end,
            'The pet HP% to use Repair at. 0 turns it off.');
        oil_block();
        row_slider('##ph_llo', 'Light below', 'light_lo', 0, 100, 1,
            function(v) return (v <= 0) and 'OFF' or string.format('%d%%', v); end,
            'When your pet\'s HP falls under this, Maneuver 1 becomes Light. 0 turns it off.');
        row_slider('##ph_lhi', 'Back above', 'light_hi', 0, 100, 1, '%d%%',
            'At this pet HP% Maneuver 1 goes back to what you picked.');
        if cfg.light_hi < cfg.light_lo then cfg.light_hi = cfg.light_lo; end
        row_switch('##ph_dep', 'Auto Deploy', 'deploy', 'Deploy your puppet when you are fighting and it is idle.');

        local pv_w = 14 + 6 + imgui.CalcTextSize('Preview');
        local mx, my, mlh = section('Minimized', pv_w);
        preview_check(mx + ROW_W - pv_w, my, mlh);
        row_slider('##ph_mscale', 'Bar size', 'mini_scale', 1.0, 3.0, 0.1, '%.1fx',
            'How big the minimized bar is: 1x is the smallest, 3x the largest.');
        row_slider('##ph_malpha', 'Opacity', 'mini_alpha', 0.2, 1.0, 0.05,
            function(v) return string.format('%d%%', math.floor(v * 100 + 0.5)); end,
            'How see-through the minimized bar is.');

        imgui.Spacing();
        if accent_button(st.enabled and 'Enabled##ph_en' or 'Disabled##ph_en', not st.enabled) then
            st.enabled = not st.enabled;
        end
        if imgui.IsItemHovered() then tip('Stays Disabled in a town, off PUP, or with no puppet out.'); end
        if st.paused then imgui.TextColored(C.muted, 'Paused: ' .. st.paused);
        elseif st.enabled and st.resting then imgui.TextColored(C.muted, 'Maneuvers and Repair paused: resting'); end
        commands_block();

        remember_pos();
        do local wx, wy = imgui.GetWindowPos(); local ww, wh = imgui.GetWindowSize(); st.main = { wx, wy, ww, wh }; if math.abs(wh - (tonumber(cfg.main_h) or 0)) > 0.5 then cfg.main_h = wh; end end
        if hit == 'close' then st.open = false; st.preview = false;
        elseif hit == 'min' then cfg.minimized = true; st.preview = false; save(); end
    end
    imgui.End();
    imgui.PopStyleColor(nc);
    imgui.PopStyleVar(nv);
end

----------------------------------------------------------------------------------------------------
-- The attachment sets tab: a window attached to the right of the panel (a thin tab when folded away), and the
-- affinity panel attached to its right
----------------------------------------------------------------------------------------------------
local ATT_LIST_H = 230;                                              -- the attachments list's height (it scrolls)
local ATT_SUM_H  = 130;                                              -- the effects summary's height (it scrolls)
local AFF_W      = 104;
local FX         = { rej = {}, el = {}, desc = {} };                 -- a refused tick (when), the element that was full, open descriptions
local ATT_FLAGS  = bit.bor(WIN_FLAGS, ImGuiWindowFlags_NoMove);

-- Two quick red flashes, and a wiggle, for the first 0.6 seconds after t0
local function flash_amt(t0)
    if t0 == nil then return 0; end
    local t = os.clock() - t0;
    if t < 0 or t > 0.6 then return 0; end
    return math.sin(((t % 0.3) / 0.3) * math.pi);
end
local function wiggle_amt(t0)
    if t0 == nil then return 0; end
    local t = os.clock() - t0;
    if t < 0 or t > 0.6 then return 0; end
    return math.sin(t * 52) * 3.2 * (1 - t / 0.6);
end

-- The effects list's height: the saved one, kept between a little and what lets this window grow to the config window's height
local function att_lh()
    local h = tonumber(cfg.att_sum_h) or ATT_SUM_H;
    local top = (st.main and st.att_fixed) and (st.main[4] - st.att_fixed) or h;
    return math.max(40, math.min(h, math.max(40, top)));
end
st.att_lh = ATT_SUM_H;

local function line_h() return math.floor(imgui.GetTextLineHeight() + 0.5); end

-- The element circle (the same as the maneuver dots)
local function el_dot(dl, cx, cy, key, r, alpha)
    local c = EL_COL[key] or NONE_COL;
    alpha = alpha or 1;
    dl:AddCircleFilled({ cx, cy }, r + 1.5, u32({ c[1], c[2], c[3], 0.22 * alpha }), 16);
    dl:AddCircleFilled({ cx, cy }, r, u32({ c[1], c[2], c[3], alpha }), 16);
    dl:AddCircle({ cx, cy }, r, u32({ 1, 1, 1, 0.22 * alpha }), 16, 1);
end

-- The item's own icon, as tall as the text (a plain square in the element's colour if the client has no picture)
local function draw_icon(dl, itemid, x, y, px, key)
    local t = item_icon(itemid, px);
    if t then
        local ok = pcall(function () dl:AddImage(t.ptr, { x, y }, { x + px, y + px }, { 0, 0 }, { 1, 1 }, u32({ 1, 1, 1, 1 })); end);
        if ok then return; end
    end
    local c = EL_COL[key] or NONE_COL;
    dl:AddRectFilled({ x, y }, { x + px, y + px }, u32({ c[1], c[2], c[3], 0.5 }), 3);
end

local function safe(fn, ...)                                         -- a draw error is told once, and doesn't take the window with it
    local ok, err = pcall(fn, ...);
    if not ok and not st.att_err then
        st.att_err = true;
        print(chat.header(addon.name):append(chat.error('Attachment tab error: ' .. tostring(err))));
    end
    return ok;
end

-- A small round < button (collapse the tab)
local function chev_button(id, x, y, dir)
    local d = 18;
    imgui.SetCursorScreenPos({ x, y });
    local clicked = imgui.InvisibleButton(id, { d, d });
    local hov = imgui.IsItemHovered();
    local dl = imgui.GetWindowDrawList();
    local cx, cy = x + d / 2, y + d / 2;
    dl:AddCircleFilled({ cx, cy }, d / 2, u32(hov and { 0.15, 0.14, 0.19, 1 } or { 0.10, 0.09, 0.13, 1 }), 24);
    dl:AddCircle({ cx, cy }, d / 2, u32(hov and { NEON2[1], NEON2[2], NEON2[3], 0.8 } or { 1, 1, 1, 0.12 }), 24, 1);
    local ic = u32({ 0.93, 0.91, 0.98, hov and 1 or 0.75 });
    if dir < 0 then
        dl:AddLine({ cx + 1.8, cy - 3.8 }, { cx - 1.8, cy }, ic, 1.6);
        dl:AddLine({ cx - 1.8, cy }, { cx + 1.8, cy + 3.8 }, ic, 1.6);
    else
        dl:AddLine({ cx - 1.8, cy - 3.8 }, { cx + 1.8, cy }, ic, 1.6);
        dl:AddLine({ cx + 1.8, cy }, { cx - 1.8, cy + 3.8 }, ic, 1.6);
    end
    return clicked, hov;
end

-- The six set buttons across the top
local function aset_buttons()
    local n, gap = NASETS, 6;
    local w = math.floor((ROW_W - gap * (n - 1)) / n);
    local h = imgui.GetFrameHeight();
    local x0, y0 = imgui.GetCursorScreenPos();
    local dl = imgui.GetWindowDrawList();
    for i = 1, n do
        local bx = x0 + (i - 1) * (w + gap);
        imgui.SetCursorScreenPos({ bx, y0 });
        local clicked = imgui.InvisibleButton('##ph_aset' .. i, { w, h });
        local hov = imgui.IsItemHovered();
        local on = (cfg.aset == i);
        dl:AddRectFilled({ bx, y0 }, { bx + w, y0 + h }, u32(on and { NEON[1] * 0.42, NEON[2] * 0.42, NEON[3] * 0.42, 1 } or (hov and { 0.15, 0.14, 0.19, 1 } or { 0.10, 0.09, 0.13, 1 })), h / 2);
        dl:AddRect({ bx, y0 }, { bx + w, y0 + h }, u32(on and { NEON2[1], NEON2[2], NEON2[3], 0.9 } or { 1, 1, 1, hov and 0.25 or 0.12 }), h / 2, C.rall, 1);
        local label = tostring(i);
        local tw, th = imgui.CalcTextSize(label);
        dl:AddText({ bx + (w - tw) / 2, y0 + (h - th) / 2 }, u32(on and { 1, 1, 1, 1 } or { 0.75, 0.73, 0.85, 1 }), label);
        if hov then tip(aset_summary(i)); end
        if clicked then cfg.aset = i; save(); end
    end
    imgui.SetCursorScreenPos({ x0, y0 });
    imgui.Dummy({ ROW_W, h });
end

-- The head / frame selection box: the current one with its icon, and a list of the ones this character has learned
local function hf_pick(id, label, kind)
    local s = aset(cfg.aset);
    local cur = (kind == 'head') and s.head or s.frame;
    local list = (kind == 'head') and PB.heads_list or PB.frames_list;
    local lh = line_h();
    local x0 = imgui.GetCursorPosX();
    imgui.AlignTextToFramePadding();
    imgui.TextColored(C.text, label);
    local bw, bh = ROW_W - 70, imgui.GetFrameHeight();
    imgui.SameLine(x0 + ROW_W - bw);
    local bx, by = imgui.GetCursorScreenPos();
    local clicked = imgui.InvisibleButton(id, { bw, bh });
    local hov = imgui.IsItemHovered();
    local dl = imgui.GetWindowDrawList();
    dl:AddRectFilled({ bx, by }, { bx + bw, by + bh }, u32(hov and { 0.15, 0.14, 0.19, 1 } or { 0.10, 0.09, 0.13, 1 }), bh / 2);
    dl:AddRect({ bx, by }, { bx + bw, by + bh }, u32(hov and { NEON2[1], NEON2[2], NEON2[3], 0.45 } or { 1, 1, 1, 0.10 }), bh / 2, C.rall, 1);
    local info = (cur ~= 0) and item_info(0x2000 + cur) or nil;
    local ty = by + (bh - lh) / 2;
    if info then
        draw_icon(dl, 0x2000 + cur, bx + 12, ty, lh, nil);
        dl:AddText({ bx + 12 + lh + 6, ty }, u32({ 0.93, 0.92, 0.98, 1 }), info.name);
    else
        dl:AddText({ bx + 12 + lh + 6, ty }, u32(C.muted), 'None');
    end
    local ax, ay, r = bx + bw - 22, by + bh / 2, 4.5;
    local ac = u32({ 0.85, 0.83, 0.95, hov and 1 or 0.75 });
    dl:AddLine({ ax - r, ay - r * 0.5 }, { ax, ay + r * 0.5 }, ac, 1.5);
    dl:AddLine({ ax, ay + r * 0.5 }, { ax + r, ay - r * 0.5 }, ac, 1.5);
    if hov and info then tip(caps_text(cur)); end
    if clicked then imgui.OpenPopup(id .. '_list'); end

    local pv = 0;
    for _, v in ipairs({ { ImGuiStyleVar_WindowPadding, { 8, 8 } }, { ImGuiStyleVar_ItemSpacing, { 4, 2 } },
                         { ImGuiStyleVar_PopupRounding, 8 }, { ImGuiStyleVar_PopupBorderSize, 1 } }) do
        if v[1] ~= nil then imgui.PushStyleVar(v[1], v[2]); pv = pv + 1; end
    end
    imgui.PushStyleColor(ImGuiCol_PopupBg, { 0.055, 0.050, 0.075, 0.98 });
    imgui.PushStyleColor(ImGuiCol_Border, { 1, 1, 1, 0.10 });
    if imgui.BeginPopup(id .. '_list') then
        safe(function ()
            local rowh = lh + 10;
            local pdl = imgui.GetWindowDrawList();
            local entries = { 0 };
            for _, e in ipairs(list) do entries[#entries + 1] = e; end
            for _, eid in ipairs(entries) do
                local rx, ry = imgui.GetCursorScreenPos();
                local pick = imgui.InvisibleButton(id .. '_r' .. eid, { bw - 6, rowh });
                local rhov = imgui.IsItemHovered();
                if eid == cur then pdl:AddRectFilled({ rx, ry }, { rx + bw - 6, ry + rowh }, u32({ 1, 1, 1, 0.12 }), 6);
                elseif rhov then pdl:AddRectFilled({ rx, ry }, { rx + bw - 6, ry + rowh }, u32({ 1, 1, 1, 0.08 }), 6); end
                local einfo = (eid ~= 0) and item_info(0x2000 + eid) or nil;
                local iy = ry + (rowh - lh) / 2;
                if einfo then
                    draw_icon(pdl, 0x2000 + eid, rx + 8, iy, lh, nil);
                    pdl:AddText({ rx + 8 + lh + 6, iy }, u32({ 0.93, 0.92, 0.98, 1 }), einfo.name);
                else
                    pdl:AddText({ rx + 8 + lh + 6, iy }, u32(C.muted), 'None');
                end
                if rhov and einfo then tip(caps_text(eid)); end
                if pick then
                    if kind == 'head' then s.head = eid; else s.frame = eid; end
                    save();
                    imgui.CloseCurrentPopup();
                end
            end
        end);
        imgui.EndPopup();
    end
    imgui.PopStyleColor(2);
    imgui.PopStyleVar(pv);
end

-- A refused tick: wiggle the box, flash it and the element's row in the affinity panel
local function refuse(id, e, why)
    FX.rej[id] = os.clock();
    FX.el[e] = os.clock();
    st.att_msg, st.att_ok, st.att_at = why, false, os.clock();
end

-- Tick / untick an attachment for the active set
local function toggle_attachment(s, id)
    local at = list_index(s.att, id);
    if at then
        table.remove(s.att, at);
        save();
        return;
    end
    local c = ATT_COST[id];
    if not c then return; end
    local used, cap = totals(s);
    if used[c[1]] + c[2] > cap[c[1]] then
        refuse(id, c[1], string.format('%s would go over: %d/%d.', AEL[c[1]][1], used[c[1]] + c[2], cap[c[1]]));
        return;
    end
    if #s.att >= ATT_SLOTS then
        refuse(id, c[1], 'An automaton only has 12 attachment slots.');
        return;
    end
    s.att[#s.att + 1] = id;
    st.att_msg = nil;
    save();
end

-- The scrollable attachments list
local function att_list(s)
    local lh = line_h();
    st.att_lh = att_lh();
    local dl0 = imgui.GetWindowDrawList();
    -- the title, with the EQUIP column's name at the right
    local x0, y0 = imgui.GetCursorScreenPos();
    imgui.Spacing(); imgui.Spacing();
    local hx, hy = imgui.GetCursorScreenPos();
    local tw = spaced(dl0, hx, hy, 'ATTACHMENTS', u32({ 0.93, 0.90, 1.00, 1 }), 2.5);
    local ew = spaced_w('EQUIP', 2);
    spaced(dl0, hx + ROW_W - ew - 12, hy + 1, 'EQUIP', u32(C.muted), 2);
    local cnt = string.format('%d/%d', #s.att, ATT_SLOTS);
    local cw = imgui.CalcTextSize(cnt);
    dl0:AddText({ hx + tw + 12, hy }, u32(#s.att >= ATT_SLOTS and { 1, 0.75, 0.4, 1 } or C.muted), cnt);
    tw = tw + 12 + cw;
    dl0:AddLine({ hx + tw + 14, hy + lh / 2 }, { hx + ROW_W - ew - 26, hy + lh / 2 }, u32({ 1, 1, 1, 0.08 }), 1);
    imgui.Dummy({ ROW_W, lh + 2 });

    local pv = 0;
    if ImGuiStyleVar_WindowPadding ~= nil then imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 0, 0 }); pv = 1; end
    local okc = imgui.BeginChild('##ph_att_list', { ROW_W, ATT_LIST_H }, false);
    imgui.PopStyleVar(pv);
    if okc then
        safe(function ()
            local dl = imgui.GetWindowDrawList();
            local list = PB.att_list;
            if #list == 0 then
                imgui.TextColored(C.muted, 'No attachments found.');
                return;
            end
            local rw, rh = ROW_W - 12, lh + 8;
            local maxw = 0;
            for _, id in ipairs(list) do
                local inf = item_info(0x2100 + id);
                if inf then maxw = math.max(maxw, (imgui.CalcTextSize(inf.name))); end
            end
            local name_x = 4 + lh + 6;
            local limit = rw - 52 - 40 - name_x;                     -- what is left for names once the affinity and the buttons have theirs
            local namew = math.min(maxw, limit);
            local aff_x = name_x + namew + 14;
            for _, id in ipairs(list) do
                local itemid = 0x2100 + id;
                local info = item_info(itemid);
                local cost = ATT_COST[id];
                if info and cost then
                    local key = AEL[cost[1]][2];
                    local rx, ry = imgui.GetCursorScreenPos();
                    local on = list_index(s.att, id) ~= nil;
                    local nclick = imgui.InvisibleButton('##ph_an' .. id, { rw - 34, rh });
                    local nhov = imgui.IsItemHovered();
                    imgui.SetCursorScreenPos({ rx + rw - 30, ry });
                    local eclick = imgui.InvisibleButton('##ph_ae' .. id, { 30, rh });
                    local ehov = imgui.IsItemHovered();
                    imgui.SetCursorScreenPos({ rx, ry + rh + 1 });

                    local open = FX.desc[id] == true;
                    if nhov or open then
                        dl:AddRectFilled({ rx, ry }, { rx + rw - 34, ry + rh }, u32({ 1, 1, 1, open and 0.07 or 0.05 }), 6);
                    end
                    local iy = ry + (rh - lh) / 2;
                    draw_icon(dl, itemid, rx + 4, iy, lh, key);
                    local shown = info.name;
                    if (imgui.CalcTextSize(shown)) > namew then
                        while #shown > 1 and (imgui.CalcTextSize(shown .. '...')) > namew do shown = shown:sub(1, -2); end
                        shown = shown .. '...';
                    end
                    dl:AddText({ rx + name_x, iy }, u32(on and { 1, 1, 1, 1 } or { 0.88, 0.87, 0.95, 1 }), shown);
                    if nhov and shown ~= info.name then tip(info.name); end
                    el_dot(dl, rx + aff_x, ry + rh / 2, key, 4);
                    dl:AddText({ rx + aff_x + 9, iy }, u32({ 0.93, 0.92, 0.98, 1 }), tostring(cost[2]));
                    -- a small arrow: down while the description is open
                    local ax, ay, r = rx + rw - 48, ry + rh / 2, 3;
                    local ac = u32({ 0.85, 0.83, 0.95, (nhov or open) and 0.9 or 0.45 });
                    if open then
                        dl:AddLine({ ax - r, ay - r * 0.5 }, { ax, ay + r * 0.5 }, ac, 1.4);
                        dl:AddLine({ ax, ay + r * 0.5 }, { ax + r, ay - r * 0.5 }, ac, 1.4);
                    else
                        dl:AddLine({ ax - r * 0.5, ay - r }, { ax + r * 0.5, ay }, ac, 1.4);
                        dl:AddLine({ ax + r * 0.5, ay }, { ax - r * 0.5, ay + r }, ac, 1.4);
                    end
                    -- the equip box, which wiggles and flashes red twice when it is refused
                    local fl = flash_amt(FX.rej[id]);
                    local cx, cy, half = rx + rw - 15 + wiggle_amt(FX.rej[id]), ry + rh / 2, 7;
                    local fill = on and { NEON[1] * 0.42, NEON[2] * 0.42, NEON[3] * 0.42, 1 } or (ehov and { 0.15, 0.14, 0.19, 1 } or { 0.10, 0.09, 0.13, 1 });
                    local edge = on and { NEON2[1], NEON2[2], NEON2[3], 0.9 } or { 1, 1, 1, ehov and 0.25 or 0.14 };
                    if fl > 0 then
                        fill = { fill[1] + (0.85 - fill[1]) * fl, fill[2] + (0.12 - fill[2]) * fl, fill[3] + (0.18 - fill[3]) * fl, 1 };
                        edge = { 1, 0.3, 0.35, 0.4 + 0.6 * fl };
                    end
                    dl:AddRectFilled({ cx - half, cy - half }, { cx + half, cy + half }, u32(fill), 4);
                    dl:AddRect({ cx - half, cy - half }, { cx + half, cy + half }, u32(edge), 4, C.rall, 1);
                    if on then
                        local ck = u32({ 1, 1, 1, 1 });
                        dl:AddLine({ cx - 3.5, cy + 0.2 }, { cx - 1, cy + 3 }, ck, 1.8);
                        dl:AddLine({ cx - 1, cy + 3 }, { cx + 3.8, cy - 3 }, ck, 1.8);
                    end

                    if nclick then FX.desc[id] = not open; end
                    if eclick then toggle_attachment(s, id); end

                    if open then                                     -- the description, under the attachment
                        imgui.SetCursorPosX(4 + lh + 6);
                        if imgui.PushTextWrapPos then imgui.PushTextWrapPos(rw - 4); end
                        imgui.TextColored(C.muted, info.desc ~= '' and info.desc or 'No description.');
                        if imgui.PopTextWrapPos then imgui.PopTextWrapPos(); end
                        imgui.Dummy({ 1, 3 });
                    end
                end
            end
        end);
    end
    imgui.EndChild();
end

-- A fold-away row (a chevron and a name), like the command list's
local function fold_row(id, open, label_open, label_closed)
    local x, y = imgui.GetCursorScreenPos();
    local h = imgui.GetTextLineHeight() + 4;
    local clicked = imgui.InvisibleButton(id, { ROW_W, h });
    local hov = imgui.IsItemHovered();
    local dl = imgui.GetWindowDrawList();
    local cx, cy, r = x + 7, y + h / 2, 4;
    local ac = u32({ 0.85, 0.83, 0.95, hov and 1 or 0.7 });
    if open then
        dl:AddLine({ cx - r, cy - r * 0.5 }, { cx, cy + r * 0.5 }, ac, 1.5);
        dl:AddLine({ cx, cy + r * 0.5 }, { cx + r, cy - r * 0.5 }, ac, 1.5);
    else
        dl:AddLine({ cx - r * 0.5, cy - r }, { cx + r * 0.5, cy }, ac, 1.5);
        dl:AddLine({ cx + r * 0.5, cy }, { cx - r * 0.5, cy + r }, ac, 1.5);
    end
    dl:AddText({ x + 20, y + 2 }, ac, open and label_open or label_closed);
    return clicked;
end

-- At the very bottom: what the set's attachments do, one bullet each
local function effects_block(s)
    local open = (cfg.att_sum_open == true);
    if fold_row('##ph_sum', open, 'Hide effects', 'Show effects') then
        cfg.att_sum_open = not open;
        save();
        open = not open;
    end
    if not open then return; end
    local pv = 0;
    if ImGuiStyleVar_WindowPadding ~= nil then imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 0, 0 }); pv = 1; end
    local okc = imgui.BeginChild('##ph_att_sum', { ROW_W, st.att_lh }, false);
    imgui.PopStyleVar(pv);
    if okc then
        safe(function ()
            local dl = imgui.GetWindowDrawList();
            local lh = line_h();
            if #s.att == 0 then
                imgui.TextColored(C.muted, 'No attachments in this set.');
                return;
            end
            for _, id in ipairs(s.att) do
                local info = item_info(0x2100 + id);
                if info then
                    local bx, by = imgui.GetCursorScreenPos();
                    dl:AddCircleFilled({ bx + 5, by + lh / 2 }, 2.4, u32({ C.acc[1], C.acc[2], C.acc[3], 0.9 }), 10);
                    imgui.SetCursorPosX(16);
                    if imgui.PushTextWrapPos then imgui.PushTextWrapPos(ROW_W - 12); end
                    imgui.TextColored(C.text, info.name .. ': ' .. (info.desc ~= '' and info.desc or 'no description'));
                    if imgui.PopTextWrapPos then imgui.PopTextWrapPos(); end
                end
            end
        end);
    end
    imgui.EndChild();
end

-- The affinity panel: what the set uses against what the head and frame give, per element
local function draw_aff(ax, ay, s)
    imgui.SetNextWindowPos({ ax, ay }, ImGuiCond_Always);
    local nc, nv = push_theme();
    if ImGuiStyleVar_WindowPadding ~= nil then imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 16, 16 }); nv = nv + 1; end
    if imgui.Begin('PUPHQ##puphq_aff', { true }, ATT_FLAGS) then
        safe(function ()
            local dl = imgui.GetWindowDrawList();
            local lh = line_h();
            local x0, y0 = imgui.GetCursorScreenPos();
            spaced(dl, x0, y0, 'AFFINITY', u32({ 0.93, 0.90, 1.00, 1 }), 2.5);
            imgui.Dummy({ AFF_W, lh + 8 });
            local used, cap = totals(s);
            local rh = lh + 8;
            for e = 1, 8 do
                local rx, ry = imgui.GetCursorScreenPos();
                imgui.Dummy({ AFF_W, rh });
                if imgui.IsItemHovered() then tip(AEL[e][1] .. ': ' .. used[e] .. ' used of ' .. cap[e]); end
                local fl = flash_amt(FX.el[e]);
                if fl > 0 then dl:AddRectFilled({ rx - 6, ry }, { rx + AFF_W, ry + rh }, u32({ 1, 0.25, 0.3, 0.35 * fl }), 6); end
                el_dot(dl, rx + 6, ry + rh / 2, AEL[e][2], 5);
                local col = C.text;
                if used[e] > cap[e] then col = { 1, 0.4, 0.45, 1 };
                elseif used[e] == 0 and cap[e] == 0 then col = C.muted; end
                dl:AddText({ rx + 22, ry + (rh - lh) / 2 }, u32(col), string.format('%d/%d', used[e], cap[e]));
            end
        end);
    end
    imgui.End();
    imgui.PopStyleColor(nc);
    imgui.PopStyleVar(nv);
end

-- The tab itself
local function draw_att()
    local m = st.main;
    if not m then return; end
    read_pup(false);
    imgui.SetNextWindowPos({ m[1] + m[3] + 6, m[2] }, ImGuiCond_Always);
    local nc, nv = push_theme();
    local function pv(var, val) if var ~= nil then imgui.PushStyleVar(var, val); nv = nv + 1; end end
    local function pc(col, val) if col ~= nil then imgui.PushStyleColor(col, val); nc = nc + 1; end end

    if not cfg.att_open then
        -- folded away: a thin tab with the name written down it
        pv(ImGuiStyleVar_WindowPadding, { 0, 0 });
        pv(ImGuiStyleVar_WindowRounding, 10);
        if imgui.Begin('PUPHQ##puphq_att', { true }, ATT_FLAGS) then
            safe(function ()
                local dl = imgui.GetWindowDrawList();
                local lh = line_h();
                local name = 'ATTACHMENT SETS';
                local step = lh - 1;
                local W, H = 30, 40 + #name * step;
                local x, y = imgui.GetCursorScreenPos();
                local clicked = imgui.InvisibleButton('##ph_att_tab', { W, H });
                local hov = imgui.IsItemHovered();
                if hov then
                    dl:AddRectFilled({ x, y }, { x + W, y + H }, u32({ 1, 1, 1, 0.05 }), 10);
                    tip('Attachment sets');
                end
                local cx = x + W / 2;
                local ac = u32({ 0.93, 0.91, 0.98, hov and 1 or 0.75 });
                dl:AddLine({ cx - 1.8, y + 12 }, { cx + 1.8, y + 16 }, ac, 1.6);
                dl:AddLine({ cx + 1.8, y + 16 }, { cx - 1.8, y + 20 }, ac, 1.6);
                local ty = y + 30;
                for i = 1, #name do
                    local ch = name:sub(i, i);
                    if ch ~= ' ' then
                        local cw = imgui.CalcTextSize(ch);
                        dl:AddText({ cx - cw / 2, ty }, u32({ 0.93, 0.90, 1.00, hov and 1 or 0.8 }), ch);
                        ty = ty + step;
                    else
                        ty = ty + step * 0.6;
                    end
                end
                if clicked then cfg.att_open = true; save(); end
            end);
        end
        imgui.End();
        imgui.PopStyleColor(nc);
        imgui.PopStyleVar(nv);
        return;
    end

    -- unfolded
    pv(ImGuiStyleVar_ScrollbarSize, 6);
    pv(ImGuiStyleVar_ScrollbarRounding, 3);
    pc(ImGuiCol_ScrollbarBg, { 0, 0, 0, 0 });
    pc(ImGuiCol_ScrollbarGrab, { C.acc[1], C.acc[2], C.acc[3], 0.30 });
    pc(ImGuiCol_ScrollbarGrabHovered, { C.acc[1], C.acc[2], C.acc[3], 0.50 });
    pc(ImGuiCol_ScrollbarGrabActive, { C.acc[1], C.acc[2], C.acc[3], 0.70 });
    local aff_at = nil;
    if imgui.Begin('PUPHQ##puphq_att', { true }, ATT_FLAGS) then
        safe(function ()
            local dl = imgui.GetWindowDrawList();
            local lh = line_h();
            if type(cfg.aset) ~= 'number' or cfg.aset < 1 or cfg.aset > NASETS then cfg.aset = 1; end
            local s = aset(cfg.aset);

            -- the title and the fold-away button
            local x0, y0 = imgui.GetCursorScreenPos();
            spaced(dl, x0, y0 + 1, 'ATTACHMENT SETS', u32({ 0.93, 0.90, 1.00, 1 }), 3);
            local folded, fhov = chev_button('##ph_att_fold', x0 + ROW_W - 18, y0 - 2, -1);
            if fhov then tip('Fold the tab away'); end
            imgui.SetCursorScreenPos({ x0, y0 });
            imgui.Dummy({ ROW_W, lh + 6 });
            imgui.Spacing();

            aset_buttons();
            imgui.Spacing();
            -- the set's name
            do
                st.name_bufs = st.name_bufs or {};
                local b = st.name_bufs[cfg.aset];
                if b == nil or (b.src ~= s.name and not b.editing) then b = { s.name, src = s.name }; st.name_bufs[cfg.aset] = b; end
                local pv, pc = 0, 0;
                if ImGuiStyleVar_FrameRounding ~= nil then imgui.PushStyleVar(ImGuiStyleVar_FrameRounding, imgui.GetFrameHeight() / 2); pv = pv + 1; end
                if ImGuiStyleVar_FramePadding ~= nil then imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 12, 3 }); pv = pv + 1; end
                imgui.PushStyleColor(ImGuiCol_FrameBg, { 0.10, 0.09, 0.13, 1 });
                imgui.PushStyleColor(ImGuiCol_FrameBgHovered, { 0.15, 0.14, 0.19, 1 });
                imgui.PushStyleColor(ImGuiCol_FrameBgActive, { 0.15, 0.14, 0.19, 1 });
                imgui.PushStyleColor(ImGuiCol_Text, C.text);
                pc = 4;
                imgui.PushItemWidth(ROW_W);
                imgui.InputText('##ph_aname', b, 32);
                imgui.PopItemWidth();
                imgui.PopStyleColor(pc);
                imgui.PopStyleVar(pv);
                b.editing = imgui.IsItemActive();
                if (b[1] or '') == '' and not b.editing then
                    local mx, my = imgui.GetItemRectMin();
                    imgui.GetWindowDrawList():AddText({ mx + 12, my + 3 }, u32({ 1, 1, 1, 0.30 }), 'Name set');
                end
                if tostring(b[1] or '') ~= s.name then s.name = tostring(b[1] or ''); b.src = s.name; st.name_dirty = true; end
                if imgui.IsItemDeactivated() and st.name_dirty then st.name_dirty = false; save(); end
            end
            imgui.Spacing();
            hf_pick('##ph_head', 'Head', 'head');
            hf_pick('##ph_frame', 'Frame', 'frame');
            if not PB.learned then
                if imgui.PushTextWrapPos then imgui.PushTextWrapPos(imgui.GetCursorPosX() + ROW_W); end
                imgui.TextColored(C.muted, 'What this character has learned can not be read (PUP has to be your main or sub job), so everything is listed.');
                if imgui.PopTextWrapPos then imgui.PopTextWrapPos(); end
            end

            att_list(s);

            -- the buttons
            imgui.Spacing();
            local bw = math.floor((ROW_W - 8) / 2);
            if accent_button('Use current##ph_usecur', true, bw) then
                local _, msg = use_current();
                st.att_msg, st.att_ok, st.att_at = msg, _, os.clock();
            end
            if imgui.IsItemHovered() then tip('Copy what your automaton wears now into this set.'); end
            imgui.SameLine(0, 8);
            if accent_button((EQ.active and 'Working...' or 'Equip now') .. '##ph_eqnow', EQ.active, bw) then
                local ok, msg = eq_start();
                if not ok then st.att_msg, st.att_ok, st.att_at = msg, false, os.clock(); end
            end
            if imgui.IsItemHovered() then tip('Deactivate the automaton, put this set on it and activate it again (Activate, or Deus Ex Automata if that is recharging).'); end
            if accent_button('Clear set##ph_clear', true, bw) then
                s.head, s.frame, s.att = 0, 0, {};
                save();
                st.att_msg, st.att_ok, st.att_at = 'Set ' .. cfg.aset .. ' cleared.', true, os.clock();
            end
            if imgui.IsItemHovered() then tip('Remove the head, the frame and every attachment from this set.'); end

            local msg, alpha = EQ.active and EQ.status or st.att_msg, 1;
            if not EQ.active and msg and msg ~= '' then               -- a result fades away after 2 seconds
                local age = os.clock() - (st.att_at or 0);
                if age > 2 then st.att_msg = nil; msg = nil; else alpha = math.min(1, (2 - age) / 0.5); end
            end
            if msg and msg ~= '' then
                if imgui.PushTextWrapPos then imgui.PushTextWrapPos(imgui.GetCursorPosX() + ROW_W); end
                local col = (EQ.active or st.att_ok ~= false) and C.acc or { 1, 0.5, 0.55, 1 };
                imgui.TextColored({ col[1], col[2], col[3], alpha }, msg);
                if imgui.PopTextWrapPos then imgui.PopTextWrapPos(); end
            end

            effects_block(s);

            -- What the window is made of apart from the effects list, measured from this frame's layout (not last frame's size)
            local _, wtop = imgui.GetWindowPos();
            local _, yend = imgui.GetCursorScreenPos();
            st.att_fixed = 2 * (y0 - wtop) + (yend - y0) - (cfg.att_sum_open and st.att_lh or 0);

            if folded then cfg.att_open = false; save(); end
        end);
        local wx, wy = imgui.GetWindowPos();
        local ww, wh = imgui.GetWindowSize();
        if type(wx) == 'number' and type(ww) == 'number' then
            -- the resize grip: a right triangle in the bottom right corner; drag it to change the window's height
            local g = 14;
            local gx, gy = wx + ww - g - 4, wy + wh - g - 4;
            local mx, my = imgui.GetMousePos();
            local over = imgui.IsWindowHovered() and mx >= gx and mx <= gx + g and my >= gy and my <= gy + g;
            if over and imgui.IsMouseClicked(0) then st.att_drag = { my, st.att_lh }; cfg.att_sum_open = true; end
            if st.att_drag then
                if imgui.IsMouseDown(0) then
                    local top = math.max(40, st.main[4] - st.att_fixed);
                    cfg.att_sum_h = math.max(40, math.min(st.att_drag[2] + (my - st.att_drag[1]), top));
                else
                    st.att_drag = nil;
                    save();
                end
            end
            local dl = imgui.GetWindowDrawList();
            local hot = over or st.att_drag ~= nil;
            dl:AddTriangleFilled({ gx + g, gy }, { gx + g, gy + g }, { gx, gy + g }, u32({ 0.85, 0.83, 0.95, hot and 0.9 or 0.4 }));
            if over then tip('Drag to resize'); end
        end
        if type(wx) == 'number' and type(ww) == 'number' then aff_at = { wx + ww + 6, wy, aset(cfg.aset) }; end
    end
    imgui.End();
    imgui.PopStyleColor(nc);
    imgui.PopStyleVar(nv);
    if aff_at then draw_aff(aff_at[1], aff_at[2], aff_at[3]); end
end


-- The minimized bar: 10 px high at 1x (Bar size, up to 3x): a red / green Enabled light, the Auto Deploy switch, three dots in the
-- colours of the chosen maneuvers (grey for None; click one to pick its element), < > to step through the maneuver sets and an
-- up arrow that opens the panel again.
-- The bar's edge glows pink while Enabled.
local function mini_switch(id, on, k)
    local x, y = imgui.GetCursorScreenPos();
    local w, h = 20 * k, 8 * k;
    local clicked = imgui.InvisibleButton(id, { w, h });
    local hov = imgui.IsItemHovered();
    local dl = imgui.GetWindowDrawList();
    dl:AddRectFilled({ x, y }, { x + w, y + h }, u32(on and { NEON[1] * 0.42, NEON[2] * 0.42, NEON[3] * 0.42, 1 } or (hov and { 0.14, 0.13, 0.18, 1 } or { 0.10, 0.095, 0.13, 1 })), h / 2);
    dl:AddCircleFilled({ on and (x + w - h / 2) or (x + h / 2), y + h / 2 }, h / 2 - k, u32(on and { 1, 1, 1, 1 } or { 0.55, 0.53, 0.62, 1 }), 16);
    return clicked, hov;
end

-- A small < or > button (dir -1 / 1) that steps through the maneuver sets
local function mini_chevron(id, dir, k)
    local x, y = imgui.GetCursorScreenPos();
    local w, h = 8 * k, 8 * k;
    local clicked = imgui.InvisibleButton(id, { w, h });
    local hov = imgui.IsItemHovered();
    local dl = imgui.GetWindowDrawList();
    local cx, cy = x + w / 2, y + h / 2;
    local col = u32({ 0.93, 0.91, 0.98, hov and 1 or 0.7 });
    local lw = math.max(1.2, 1.4 * k);
    local ox, oy = 1.3 * k, 2.2 * k;
    if dir < 0 then
        dl:AddLine({ cx + ox, cy - oy }, { cx - ox, cy }, col, lw);
        dl:AddLine({ cx - ox, cy }, { cx + ox, cy + oy }, col, lw);
    else
        dl:AddLine({ cx - ox, cy - oy }, { cx + ox, cy }, col, lw);
        dl:AddLine({ cx + ox, cy }, { cx - ox, cy + oy }, col, lw);
    end
    if hov and not st.mini_pick then
        local n = ((((tonumber(cfg.set) or 1) + dir) - 1) % NSETS) + 1;
        tip((dir < 0 and 'Previous set' or 'Next set') .. ' (' .. n .. '): ' .. set_summary(n));
    end
    return clicked;
end

-- The element picker under the dots: a row of little circles (None first); clicking one sets it for that slot
local function mini_picker(k)
    if st.mini_pick == nil then return; end
    local nv, nc = 0, 0;
    local function pvv(var, val) if var ~= nil then imgui.PushStyleVar(var, val); nv = nv + 1; end end
    pvv(ImGuiStyleVar_Alpha, 1);                                     -- (stays fully opaque on a faded bar)
    pvv(ImGuiStyleVar_WindowPadding, { 7, 6 });
    pvv(ImGuiStyleVar_ItemSpacing, { 5, 4 });
    pvv(ImGuiStyleVar_PopupRounding, 8);
    pvv(ImGuiStyleVar_PopupBorderSize, 1);
    imgui.PushStyleColor(ImGuiCol_PopupBg, { 0.055, 0.050, 0.075, 0.98 }); nc = nc + 1;
    imgui.PushStyleColor(ImGuiCol_Border, { 1, 1, 1, 0.12 }); nc = nc + 1;
    local pos = st.mini_pop or { 0, 0 };
    imgui.SetNextWindowPos({ pos[1], pos[2] });
    if imgui.BeginPopup('##ph_mini_pick') then
        local slot = st.mini_pick;
        local d = math.floor(14 * (0.6 + 0.4 * k));
        local r = d / 2 - 3;
        local pdl = imgui.GetWindowDrawList();
        for idx = -1, 7 do
            if idx > -1 then imgui.SameLine(); end
            local ox, oy = imgui.GetCursorScreenPos();
            local picked = imgui.InvisibleButton('##ph_pk' .. idx, { d, d });
            local hv = imgui.IsItemHovered();
            local col = EL_COL[idx] or NONE_COL;
            local cx, cy = ox + d / 2, oy + d / 2;
            if idx >= 0 then pdl:AddCircleFilled({ cx, cy }, r + 2.5, u32({ col[1], col[2], col[3], 0.22 }), 20); end
            pdl:AddCircleFilled({ cx, cy }, r, u32({ col[1], col[2], col[3], 1 }), 20);
            pdl:AddCircle({ cx, cy }, r, u32({ 1, 1, 1, 0.22 }), 20, 1);
            if idx == -1 then pdl:AddLine({ cx - r * 0.5, cy }, { cx + r * 0.5, cy }, u32({ 1, 1, 1, 0.55 }), 1.5); end
            if cfg['m' .. slot] == idx then pdl:AddCircle({ cx, cy }, r + 3, u32({ NEON2[1], NEON2[2], NEON2[3], 0.95 }), 20, 1.5); end
            if hv then
                pdl:AddCircle({ cx, cy }, r + 2, u32({ 1, 1, 1, 0.6 }), 20, 1);
                tip(idx == -1 and 'None' or ELEMENTS[idx + 1]);
            end
            if picked then
                cfg['m' .. slot] = idx;
                save();
                imgui.CloseCurrentPopup();
                st.mini_pick = nil;
            end
        end
        imgui.EndPopup();
    else
        st.mini_pick = nil;                                          -- closed by a click elsewhere
    end
    imgui.PopStyleColor(nc);
    imgui.PopStyleVar(nv);
end

local function draw_mini()
    -- Its own spot, apart from the panel. Not placed yet: where the panel is (just above it while previewing)
    local px, py = tonumber(cfg.mini_x) or -1, tonumber(cfg.mini_y) or -1;
    local unplaced = (px < 0 or py < 0);
    if unplaced then                                                 -- not placed yet: just under the config window
        local mh = st.main and st.main[4] or tonumber(cfg.main_h) or 560;
        px = tonumber(cfg.win_x) or 200;
        py = (tonumber(cfg.win_y) or 200) + mh + 6;
        local t = st.mini_auto;
        if t == nil or math.abs(t[1] - px) > 0.5 or math.abs(t[2] - py) > 0.5 then
            st.mini_auto = { px, py };
            imgui.SetNextWindowPos({ px, py }, ImGuiCond_Always);
        end
    else
        imgui.SetNextWindowPos({ px, py }, ImGuiCond_FirstUseEver);
    end
    local k = math.max(1, math.min(3, tonumber(cfg.mini_scale) or 1));
    local a = math.max(0.2, math.min(1, tonumber(cfg.mini_alpha) or 1));
    local nc, nv = push_theme();
    local function pv(var, val) if var ~= nil then imgui.PushStyleVar(var, val); nv = nv + 1; end end
    pv(ImGuiStyleVar_Alpha, a);                                      -- (the whole bar, its window and outline too)
    pv(ImGuiStyleVar_WindowPadding, { 7 * k, 1 * k });
    pv(ImGuiStyleVar_WindowRounding, 5 * k);
    pv(ImGuiStyleVar_WindowMinSize, { 1, 1 });                       -- (ImGui won't make a window smaller than 32 px otherwise)
    pv(ImGuiStyleVar_ItemSpacing, { 9 * k, 0 });
    imgui.PushStyleColor(ImGuiCol_Border, st.enabled and { NEON2[1], NEON2[2], NEON2[3], 0.75 } or { 1, 1, 1, 0.08 });
    nc = nc + 1;
    if imgui.Begin('PUPHQ##puphq_mini', { true }, WIN_FLAGS) then
        local dl = imgui.GetWindowDrawList();

        -- status light: green while Enabled, red while Disabled
        local lx, ly = imgui.GetCursorScreenPos();
        imgui.Dummy({ 8 * k, 8 * k });
        if imgui.IsItemHovered() then tip(st.enabled and 'Enabled' or 'Disabled'); end
        local lc = st.enabled and { 0.35, 0.92, 0.50 } or { 1.00, 0.30, 0.35 };
        local lcx, lcy = lx + 4 * k, ly + 4 * k;
        dl:AddCircleFilled({ lcx, lcy }, 4.5 * k, u32({ lc[1], lc[2], lc[3], 0.22 }), 16);
        dl:AddCircleFilled({ lcx, lcy }, 3 * k, u32({ lc[1], lc[2], lc[3], 1 }), 16);
        dl:AddCircle({ lcx, lcy }, 3 * k, u32({ 1, 1, 1, 0.22 }), 16, 1);
        imgui.SameLine();

        local sw_clicked, sw_hov = mini_switch('##ph_mini_dep', cfg.deploy == true, k);
        if sw_clicked then cfg.deploy = not (cfg.deploy == true); save(); end
        if sw_hov then tip('Auto Deploy'); end
        imgui.SameLine();

        -- < previous set, the three maneuver dots (click one to pick its element), > next set
        if mini_chevron('##ph_mini_prev', -1, k) then switch_set((tonumber(cfg.set) or 1) - 1); end
        imgui.SameLine(0, 2 * k);
        local slots = { cfg.m1, cfg.m2, cfg.m3 };
        local bw, bh = 10 * k, 8 * k;
        local first_x = nil;
        for i = 1, 3 do
            if i > 1 then imgui.SameLine(0, 0); end
            local bx, by = imgui.GetCursorScreenPos();
            first_x = first_x or bx;
            local clicked = imgui.InvisibleButton('##ph_mini_dot' .. i, { bw, bh });
            local hov = imgui.IsItemHovered();
            local picking = (st.mini_pick == i);
            local col = EL_COL[slots[i]] or NONE_COL;
            local cx, cy = bx + bw / 2, by + bh / 2;
            if EL_COL[slots[i]] then dl:AddCircleFilled({ cx, cy }, 4.5 * k, u32({ col[1], col[2], col[3], 0.22 }), 16); end
            dl:AddCircleFilled({ cx, cy }, 3 * k, u32({ col[1], col[2], col[3], 1 }), 16);
            dl:AddCircle({ cx, cy }, 3 * k, u32({ 1, 1, 1, 0.22 }), 16, 1);
            if hov or picking then dl:AddCircle({ cx, cy }, 4.3 * k, u32({ 1, 1, 1, 0.55 }), 16, 1); end
            if hov and not st.mini_pick then
                tip('Maneuver ' .. i .. ': ' .. (EL_COL[slots[i]] and ELEMENTS[slots[i] + 1] or 'None'));
            end
            if clicked then
                st.mini_pick = i;
                st.mini_pop = { first_x, by + bh + 3 };
                imgui.OpenPopup('##ph_mini_pick');
            end
        end

        imgui.SameLine(0, 2 * k);
        if mini_chevron('##ph_mini_next', 1, k) then switch_set((tonumber(cfg.set) or 1) + 1); end

        -- the up arrow at the right end: open the full panel again
        imgui.SameLine();
        local ax, ay = imgui.GetCursorScreenPos();
        local aw = 10 * k;
        local up = imgui.InvisibleButton('##ph_mini_up', { aw, bh });
        local uh = imgui.IsItemHovered();
        local acx, acy = ax + aw / 2, ay + bh / 2;
        local uc = u32({ 0.93, 0.91, 0.98, uh and 1 or 0.7 });
        local lw_ = math.max(1.2, 1.4 * k);
        dl:AddLine({ acx - 3 * k, acy + 1.5 * k }, { acx, acy - 1.5 * k }, uc, lw_);
        dl:AddLine({ acx, acy - 1.5 * k }, { acx + 3 * k, acy + 1.5 * k }, uc, lw_);
        if uh then tip('Open the panel'); end
        if up then cfg.minimized = false; save(); end

        mini_picker(k);
        local mwx, mwy = imgui.GetWindowPos();                        -- (an unplaced bar is only remembered once it is dragged)
        if not unplaced or (st.mini_auto and type(mwx) == 'number' and (math.abs(mwx - st.mini_auto[1]) > 2 or math.abs(mwy - st.mini_auto[2]) > 2)) then
            remember_pos('mini_x', 'mini_y');
        end
    end
    imgui.End();
    imgui.PopStyleColor(nc);
    imgui.PopStyleVar(nv);
end

ashita.events.register('d3d_present', 'puphq_present', function ()
    local ok, shown = pcall(tick);
    pcall(eq_tick);
    if not ok then
        if not st.failed then st.failed = true; print(chat.header(addon.name):append(chat.error('Error: ' .. tostring(shown)))); end
        return;
    end
    -- Off PUP the addon is fully hidden, unless /puphq config asked for the panel
    local is_pup = (AshitaCore:GetMemoryManager():GetPlayer():GetMainJob() == PUP_JOB);
    if not st.open or (cfg.minimized and not is_pup) then st.force_cfg = false; end
    if not is_pup and st.force_cfg then
        if shown then draw_ui(); draw_att(); end
        if not st.open then st.force_cfg = false; end
    elseif shown and st.open and is_pup then
        if cfg.minimized then
            draw_mini();
        else
            draw_ui();
            draw_att();
            if st.preview then draw_mini(); end                      -- (the bar too, so it can be sized and placed)
        end
    end
end);

ashita.events.register('load', 'puphq_load', function ()
    cfg.minimized = true;                                            -- every load starts as the small bar
    st.open = true;
    print(chat.header(addon.name):append(chat.message('Loaded. Click the up arrow on the bar for the full panel; /puphq config opens or closes the panel.')));
end);

ashita.events.register('command', 'puphq_command', function (e)
    local args = e.command:args();
    if #args == 0 then return; end
    local cmd = args[1]:lower();
    if cmd ~= '/puphq' then return; end
    e.blocked = true;

    local sub = (args[2] or ''):lower();
    if sub == 'config' then                                          -- opens / closes the full panel, on any job
        local is_pup = (AshitaCore:GetMemoryManager():GetPlayer():GetMainJob() == PUP_JOB);
        local showing = st.open and ((is_pup and not cfg.minimized) or (not is_pup and st.force_cfg));
        if showing then
            st.open, st.force_cfg, st.preview = false, false, false;
        else
            st.open, st.force_cfg, cfg.minimized, st.preview = true, true, false, false;
            save();
        end
    elseif sub == '' then
        -- (nothing: only /puphq config opens or closes the panel)
    elseif sub == 'ad' then                                          -- /puphq ad toggle | on | off
        local a = (args[3] or 'toggle'):lower();
        if a == 'on' then cfg.deploy = true;
        elseif a == 'off' then cfg.deploy = false;
        else cfg.deploy = not (cfg.deploy == true); end
        save();
        print(chat.header(addon.name):append(chat.message('Auto Deploy: ' .. (cfg.deploy and 'ON' or 'OFF'))));
    elseif sub == 'toggle' then
        st.enabled = not st.enabled;
    elseif sub == 'manset' then                                      -- /puphq manset next | prev | 1 | 2 | 3
        local a = (args[3] or ''):lower();
        local cur = tonumber(cfg.set) or 1;
        local target = nil;
        if a == 'next' then target = cur + 1;
        elseif a == 'prev' or a == 'previous' then target = cur - 1;
        elseif tonumber(a) ~= nil and tonumber(a) >= 1 and tonumber(a) <= NSETS then target = math.floor(tonumber(a)); end
        if target ~= nil then
            switch_set(target);
            print(chat.header(addon.name):append(chat.message(string.format('Maneuver set %d: %s', cfg.set, set_summary(cfg.set)))));
        else
            print(chat.header(addon.name):append(chat.error('Use /puphq manset next, prev, 1, 2 or 3')));
        end
    end
end);
