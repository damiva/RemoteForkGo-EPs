--bencode.lua, thanks to Phil Hagelberg--
local function decode_list(str, t, total_len)
    -- print("list", str, lume.serialize(t))
    if(str:sub(1,1) == "e") then return t, total_len + 1 end
    local value, v_len = decode(str)
    table.insert(t, value)
    total_len = total_len + v_len
    return decode_list(str:sub(v_len + 1), t, total_len)
end
local function decode_table(str, t, total_len)
    -- print("table", str, lume.serialize(t))
    if(str:sub(1,1) == "e") then return t, total_len + 1 end
    local key, k_len = decode(str)
    local value, v_len = decode(str:sub(k_len+1))
    local end_pos = 1 + k_len + v_len
    t[key] = value
    total_len = total_len + k_len + v_len
    return decode_table(str:sub(end_pos), t, total_len)
end
function decode(str)
    -- print("decoding", str)
    if(str:sub(1,1) == "l") then
       return decode_list(str:sub(2), {}, 1)
    elseif(str:sub(1,1) == "d") then
       return decode_table(str:sub(2), {}, 1)
    elseif(str:sub(1,1) == "i") then
       return(tonumber(str:sub(2, str:find("e") - 1))), str:find("e")
    elseif(str:match("[0-9]+")) then
       local num_str = str:match("[0-9]+")
       local beginning_of_string = #num_str + 2
       local str_len = tonumber(num_str)
       local total_len = beginning_of_string + str_len - 1
       return str:sub(beginning_of_string, total_len), total_len
    else
       return nil
    end
end
-------------------------------------
local srv, http, json = require("server"), require("http"), require("json")
local function gettrn(url)
    local r, e = http.get(url)
    assert(e == nil, e)
    assert(r.status_code == 200, "URL returned: "..r.status_code)
    local i = decode(r.body)
    assert(i ~= nil, "Parse torrent file error")
    if i.info.files then
        return i.info.files
    else
        return {{length = i.info.length, path = {i.info.name}}}
    end
end
local function checktrn(aip, tip)
    local isa, ist = false, false
    if aip ~= "" and aip ~= "127.0.0.1" then
        local r, e = http.get("http://"..aip..":6878/webui/api/service?method=get_version&format=json")
        if e == nil and r and r.status_code == 200 then
            isa = true
        end
    end
    if tip ~= "" and tip ~= "127.0.0.1" then
        local r, e = http.get("http://"..tip..":8090/echo")
        if e == nil and r and r.status_code == 200 then
            ist = true
        end
    end
    return isa, ist
end

local usage = {
    {"Torrserve", ":8090/torrent/play?link=", "&file="},
    {"AceStream / TS", ":6878/ace/getstream?url=", "&_idx="},
    {"AceStream / HLS", ":6878/ace/manifest.m3u8?url=", "&_idx="},
    {"AceStream / HLS + AAC",  ":6878/ace/manifest.m3u8?transcode_audio=1&url=", "&_idx="}
}
local aip, tip, url, lng, use, usi = srv.form("aip"), srv.form("tip"), srv.form("url"), srv.form("w_lang"), srv.form("use"), 1
if use ~= "" then 
    srv.memory("use", use)
    srv.body(json.encode({cmd = "reload(0.1);"}))
    return
else
    use = srv.memory("use")
    if use then usi = tonumber(use) end
    if not usi or usi < 1 or usi > 4 then usi = 1 end
end
assert(url ~= "", "Wrong request!")
local fls = gettrn(url)
if aip == "" and tip == "" then
    srv.body(json.encode(fls))
else
    local pl = {cacheinfo = "nocache", channels = {}}
    local isa, ist = checktrn(aip, tip)
    if isa then
        pl.menu = {{logo_30x30 = srv.url_root.."/sub.svg", playlist_url = "submenu", submenu = {}, title = lng == "ru" and "Использовать: " or "Use: "}}
        for i, u in pairs(usage) do
            if i > 1 or ist then pl.menu[1].submenu[#pl.menu[1].submenu + 1] = {logo_30x30 = "", title = u[1], playlist_url = srv.url_root.."/torrent?use="..i} end
        end
        if usi == 1 and not ist then usi = 2 end
        pl.menu[1].title = pl.menu[1].title .. usage[usi][1]
    elseif ist then
        usi = 1
    else
        assert(isa or ist, "You have no AceStream or Torrserve!")
    end
    for i = 1, #fls do fls[i].idx = i - 1 end
    if #fls > 1 then table.sort(fls, function(a, b) return table.concat(a.path) < table.concat(b.path) end) end
    local lpth = ""
    for i, f in pairs(fls) do
        local cpth = #f.path > 1 and table.concat(f.path, " / ", 1, #f.path - 1) or ""
        pl.channels[i] = {
            title = f.path[#f.path],
            logo_30x30 = srv.url_root.."/vid.svg",
            stream_url = "http://"..(usi == 1 and tip or aip)..usage[usi][2]..srv.encuri(url)..usage[usi][3]..(usi == 1 and (i-1) or f.idx),
            description = (cpth == "" and "" or "<b style='color:yellow'>"..cpth.." /</b> ") .. f.path[#f.path]
                .."<hr>"..(lng == "ru" and "Размер: " or "Size: ")..math.floor((f.length / 1024 / 1024))..(lng == "ru" and " МБ" or " MB")
        }
        if cpth ~= lpth then
            lpth = cpth
            pl.channels[i].before = "<div style='text-align:left;font-size:smaller;color:yellow'><img src='"..srv.url_root.."/fld.svg' style='height:1em'>&nbsp;"..cpth.."</div>"
        end
    end
    srv.body(json.encode(pl))
end
