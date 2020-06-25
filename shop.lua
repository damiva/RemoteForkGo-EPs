msg = {
    {ind = "Installed", new = "New", ins = "Install", upd = "Update", del = "Delete"},
    {ind = "Установленные", new = "Новые", ins = "Установить", upd = "Обновить", del = "Удалить"}
}
srv, http, json, pl = require("server"), require("http"), require("json"), {cacheinfo = "nocache", channels = {}}
function get_url(url)
    local r, e = http.get(url)
    if e == nil then
        if r.status_code == 200 then
            return json.decode(r.body), nil
        else
            return nil, "Returned code: "..r.status_code
        end
    else
        return nil, e
    end
end
function get_pln(name)
    local f, e = srv.file(name.."/manifest.json")
    if f ~= nil then return json.decode(f) else return nil end
end
if srv.form("w_lang") == "ru" then msg = msg[2] else msg = msg[1] end
local rul = "http://"..srv.host
local pln, rpo, rpn = srv.path_info:match("^/(.-)/(.-)/(.*)$")
if pln and rpo and rpn then
    local dsc = ""
    local inf, e = get_url("https://api.github.com/repos/"..rpo.."/"..rpn.."/releases/latest")
    if inf then
        dsc = inf.body:match("^.-<main>(.-)</main>.*$")
        if dsc == nil then dsc = "" end
    else
        pl.notify = e
    end
    local pll = get_pln(pln)
    if pll then 
        if inf and inf.tag_name and (not pll.Git or inf.tag_name ~= pll.Git.Tag) then
            pl.channels[1] = {title = msg.upd, logo_30x30 = rul.."/upd.svg", playlist_url = rul.."/install/"..pln.."/"..rpo.."/"..rpn.."/"..inf.tag_name, description = dsc, infolink = pln}
        end
        pl.channels[#pl.channels + 1] = {title = msg.del, logo_30x30 = rul.."/del.svg", playlist_url = rul.."/install/"..pln, description = dsc, infolink = pln}
    elseif inf then
        pl.channels[1] = {title = msg.ins, logo_30x30 = rul.."/oki.svg", playlist_url = rul.."/install/"..pln.."/"..rpo.."/"..rpn.."/"..inf.tag_name, description = dsc, infolink = pln}
    else
        pl.cmd = "stop();"
    end
else
    pl.typeList = "start"
    local plcn = {}
    local ps, e = get_url("http://rfgo.pont.ml/api.php?av=" .. srv.version_core)
    assert(ps ~= nil, e)
    assert(ps.Error == "", ps.Error)
    for pn, pv in pairs(ps.Plugs) do 
        if get_pln(pn) ~= nil then
            pl.channels[#pl.channels + 1] = {title = pv.ttl, logo_30x30 = pv.icn, description = pn, playlist_url = rul.."/shop/"..pn.."/"..pv.rpo.."/"..pv.rpn}
            if #pl.channels == 1 then pl.channels[1].before = "<div>"..msg.ind.."</div>" end
            ps[pn] = nil
        else
            plcn[#plcn + 1] = {title = pv.ttl, logo_30x30 = pv.icn, description = pn, playlist_url = rul.."/shop/"..pn.."/"..pv.rpo.."/"..pv.rpn}
            if #plcn == 1 then plcn[1].before = "<div>"..msg.new.."</div>" end
        end
    end
    for i, pv in pairs(plcn) do pl.channels[#pl.channels + 1] = pv end
end
srv.body(json.encode(pl))