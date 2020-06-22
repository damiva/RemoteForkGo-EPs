srv, http, json = require("server"), require("http"), require("json")
local id = srv.path_info:sub(2)
if id:sub(1, 4) == "http" then id = id:match("^.-%?v=(.*)$") end
if not id or id == "" then id = srv.form("v") end
local r, e = http.get("http://youtube.com/get_video_info?video_id="..id)
if r == nil then srv.header(500) return end
if r.status_code ~= 200 then srv.header(r.status_code) return end
local fs = srv.decuri(r.body:match("^.-&player_response=(.-)&.*$")):match('^.-"formats":(%[%{.-%}%]).*$')
if not fs then srv.header(204) return end
local fi, e = json.decode(fs)
if e ~= nil then srv.header(500) return end
local fo = {}
for i, f in pairs(fi) do
    fo[f.qualityLabel:gsub("p","")] = {url = f.url, type = f.mimeType:match("^.-/(.-);.*$")}
end
srv.body(json.encode(fo))