local function parsecurl(qr)
    local hdr, chd, frd, pst, i = {}, false, true, "", 0
    if qr:sub(1, 4) == "curl" then
        qr, i = qr:gsub(" %-i", "")
        if i > 0 then chd = true end
        qr, i = qr:gsub(" %-L", "")
        if i == 0 then frd = false end
        qr = qr:gsub(' %-H "(.-): ?(.-)"', function(n, v) hdr[n] = {v} return "" end)
        qr = qr:gsub(' %-%-data "(.-)"', function(n) pst = v return "" end)
        if pst == "" then qr = qr:gsub(' %-d "(.-)"', function(v) pst = v return "" end) end
        qr = qr:match('^.-"(.-)".*$')
    end
    return qr, hdr, chd, frd, pst
end
local function curl(url, frd, hdr, pst)
    local http, r, e
    if frd then
        http = require("http")
    else
        http = require("http_nfr")
    end
    if pst == "" then
        r, e = http.get(url, {headers = hdr})
    else
        r, e = http.post(url, {headers = hdr, body = pst})
    end
    if r == nil then
        return nil, nil, nil, e
    else
        return r.body, r.status_code, r.headers
    end
end
srv = require("server")
local qr = srv.query_string
if srv.method == "POST" then
    qr = srv.body()
end
local qr, e = srv.decuri(qr)
if e ~= nil then srv.header(500) return end
if qr == "" then srv.header(400) return end
local qs = {}
for q in (qr.."|"):gmatch("(.-)|") do qs[#qs+1] = q end
if #qs < 1 then srv.header(400) return end
local ul, hd, ch, fr, pb = parsecurl(qs[1])
if ul == "" then srv.header(400) return end
local pb, st, hd, e = curl(ul, fr, hd, pb)
if e ~= nil then srv.header(500) return end
local leni = pb:len()
if pb ~= "" and #qs > 2 and qs[2] ~= "" and qs[3] ~= "" then
    if #qs == 2 then qs[#qs+1] = "" end
    if qs[2]:find(".*", 0, true) then
        pb = pb:match(qs[2].."(.-)"..qs[3])
    else
        pb = pb:match("^.-"..qs[2].."(.-)"..qs[3]..".*$")
    end
end
if pb ~= "" and #qs > 3 then
    if #qs == 4 then qs[#qs+1] = "" end
    pb = pb:gsub(qs[4], qs[5])
end
if ch then
    for n, v in pairs(hd) do
        for h in pairs(v) do
            if h == "Content-Length" then v = pb:len() end
            srv.header(n, h, true)
        end
    end
    srv.header(st)
end
srv.body(pb)
srv.log_inf("/parserlink body length: got "..leni..", put "..pb:len())
