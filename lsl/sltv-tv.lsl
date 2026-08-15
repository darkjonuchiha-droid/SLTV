// SLTV v1 — TV prim script.
// State authority + HTTP-in bootstrap/long-poll server + media params + menus/ACL.
// Wire contract and design: docs/specs/2026-08-15-sltv-design.md

integer APP_CHANNEL  = -77720011;
integer DLG_CHANNEL  = -77720100;
string  CONFIG_NC    = "SLTV Config";
integer POLL_MAX_AGE = 15;     // seconds before a pending poll gets a heartbeat
integer MAX_CHANNELS = 24;

// ---- config (from notecard) ----
string  gPageBase;             // e.g. https://darkjonuchiha-droid.github.io/SLTV/web
integer gFace = 4;
list    gChanNames;
list    gChanUrls;

// ---- state ----
integer gSeq = 1;
integer gPower = TRUE;
integer gCh = 0;
integer gFs = FALSE;

// ---- infra ----
string  gCapUrl;
integer gReload;               // bumps ?r= to force a reload for everyone
list    gPolls;                // strided: [key id, integer since, integer unixtime]
list    gAclKeys;              // authorized guest avatar keys (as strings)
list    gAclNames;             // parallel: names at grant time
integer gNcLine;
key     gNcQuery;
integer gConfigured;

// ---- menus ----
integer gDlgListen;
key     gDlgAvatar;            // avatar the current dialog belongs to
string  gDlgCtx;               // "main" | "channels" | "guests" | "addguest" | "revoke"
list    gSensorKeys;
list    gSensorNames;

integer isAuthorized(key av) {
    if (av == llGetOwner()) return TRUE;
    return llListFindList(gAclKeys, [(string)av]) != -1;
}

string stateJson() {
    list chans = [];
    integer n = llGetListLength(gChanNames);
    integer i;
    for (i = 0; i < n; ++i) {
        chans += llList2Json(JSON_OBJECT,
            ["n", llList2String(gChanNames, i), "u", llList2String(gChanUrls, i)]);
    }
    return llList2Json(JSON_OBJECT, [
        "seq", gSeq, "power", gPower, "ch", gCh, "fs", gFs,
        "channels", llList2Json(JSON_ARRAY, chans)]);
}

persist() {
    llLinksetDataWrite("sltv.state", llList2Json(JSON_OBJECT,
        ["power", gPower, "ch", gCh, "fs", gFs]));
    llLinksetDataWrite("sltv.acl", llList2Json(JSON_OBJECT,
        ["k", llList2Json(JSON_ARRAY, gAclKeys),
         "n", llList2Json(JSON_ARRAY, gAclNames)]));
}

restore() {
    string s = llLinksetDataRead("sltv.state");
    if (s != "") {
        gPower = (integer)llJsonGetValue(s, ["power"]);
        gCh    = (integer)llJsonGetValue(s, ["ch"]);
        gFs    = (integer)llJsonGetValue(s, ["fs"]);
    }
    string a = llLinksetDataRead("sltv.acl");
    if (a != "") {
        gAclKeys  = llJson2List(llJsonGetValue(a, ["k"]));
        gAclNames = llJson2List(llJsonGetValue(a, ["n"]));
    }
}

string bootstrapHtml() {
    return "<!DOCTYPE html><html><head><meta charset=\"utf-8\">"
        + "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
        + "<link rel=\"stylesheet\" href=\"" + gPageBase + "/css/tv.css\"></head>"
        + "<body><script type=\"module\" src=\"" + gPageBase + "/js/main.js\"></script>"
        + "</body></html>";
}

string qsVal(string qs, string name) {
    list parts = llParseString2List(qs, ["&"], []);
    integer i;
    integer n = llGetListLength(parts);
    for (i = 0; i < n; ++i) {
        list kv = llParseString2List(llList2String(parts, i), ["="], []);
        if (llList2String(kv, 0) == name) return llList2String(kv, 1);
    }
    return "";
}

applyMedia() {
    if (gCapUrl == "" || !gConfigured) return;
    if (gFace >= llGetNumberOfSides()) {
        llOwnerSay("SLTV: screen_face " + (string)gFace + " does not exist on this prim ("
            + (string)llGetNumberOfSides() + " faces). Fix the notecard.");
        return;
    }
    string url = gCapUrl;
    if (gReload > 0) url = gCapUrl + "?r=" + (string)gReload;
    llSetPrimMediaParams(gFace, [
        PRIM_MEDIA_AUTO_PLAY, TRUE,
        PRIM_MEDIA_FIRST_CLICK_INTERACT, TRUE,
        PRIM_MEDIA_CURRENT_URL, url,
        PRIM_MEDIA_HOME_URL, gCapUrl,
        PRIM_MEDIA_PERMS_INTERACT, PRIM_MEDIA_PERM_ANYONE,
        PRIM_MEDIA_PERMS_CONTROL, PRIM_MEDIA_PERM_OWNER,
        PRIM_MEDIA_WIDTH_PIXELS, 1280,
        PRIM_MEDIA_HEIGHT_PIXELS, 720]);
    llOwnerSay("SLTV: screen attached to " + url);
}

broadcast() {
    gSeq++;
    persist();
    string body = stateJson();
    integer i;
    integer n = llGetListLength(gPolls);
    for (i = 0; i < n; i += 3) {
        key id = llList2Key(gPolls, i);
        llSetContentType(id, CONTENT_TYPE_JSON);
        llHTTPResponse(id, 200, body);
    }
    gPolls = [];
}

doCmd(key av, string cmd) {
    if (!isAuthorized(av)) {
        llRegionSayTo(av, 0, "SLTV: you are not on this TV's control list.");
        return;
    }
    integer nCh = llGetListLength(gChanNames);
    if (cmd == "power")      gPower = !gPower;
    else if (cmd == "fs")    gFs = !gFs;
    else if (cmd == "chup")  gCh = (gCh + 1) % nCh;
    else if (cmd == "chdn")  gCh = (gCh + nCh - 1) % nCh;
    else if (llGetSubString(cmd, 0, 2) == "ch:") {
        integer want = (integer)llGetSubString(cmd, 3, -1);
        if (want >= 0 && want < nCh) gCh = want;
        else return;
    }
    else return;
    broadcast();
}

openDialog(key av, string ctx) {
    llListenRemove(gDlgListen);
    gDlgListen = llListen(DLG_CHANNEL, "", NULL_KEY, "");
    gDlgAvatar = av;
    gDlgCtx = ctx;
    if (ctx == "main") {
        list btns = ["Power", "Fullscrn", "Ch +", "Ch -", "Channels"];
        if (av == llGetOwner()) btns += ["Guests", "Reload"];
        llDialog(av, "SLTV — " + llList2String(gChanNames, gCh), btns, DLG_CHANNEL);
    } else if (ctx == "channels") {
        string legend = "Pick a channel:\n";
        list btns = [];
        integer n = llGetListLength(gChanNames);
        if (n > 12) n = 12; // v1: first 12 via dialog
        integer i;
        for (i = 0; i < n; ++i) {
            legend += (string)(i + 1) + "  " + llList2String(gChanNames, i) + "\n";
            btns += [(string)(i + 1)];
        }
        llDialog(av, legend, btns, DLG_CHANNEL);
    } else if (ctx == "guests") {
        llDialog(av, "Guest remotes — " + (string)llGetListLength(gAclKeys)
            + " granted", ["+ Add", "- Revoke", "Clear", "Back"], DLG_CHANNEL);
    } else if (ctx == "revoke") {
        integer n = llGetListLength(gAclNames);
        if (n == 0) { openDialog(av, "guests"); return; }
        string legend = "Revoke which guest?\n";
        list btns = [];
        if (n > 11) n = 11;
        integer i;
        for (i = 0; i < n; ++i) {
            legend += (string)(i + 1) + "  " + llList2String(gAclNames, i) + "\n";
            btns += [(string)(i + 1)];
        }
        btns += ["Back"];
        llDialog(av, legend, btns, DLG_CHANNEL);
    }
}

default
{
    state_entry() {
        llListen(APP_CHANNEL, "", NULL_KEY, "");
        restore();
        gConfigured = FALSE;
        gChanNames = [];
        gChanUrls = [];
        gPolls = [];
        llSetTimerEvent(5.0);
        if (llGetInventoryType(CONFIG_NC) != INVENTORY_NOTECARD) {
            llOwnerSay("SLTV: missing notecard '" + CONFIG_NC + "'.");
            return;
        }
        gNcLine = 0;
        gNcQuery = llGetNotecardLine(CONFIG_NC, gNcLine);
    }

    on_rez(integer p) { llResetScript(); }

    dataserver(key q, string data) {
        if (q != gNcQuery) return;
        if (data != EOF) {
            data = llStringTrim(data, STRING_TRIM);
            if (data != "" && llGetSubString(data, 0, 0) != "#") {
                integer eq = llSubStringIndex(data, "=");
                if (eq > 0) {
                    string k = llStringTrim(llGetSubString(data, 0, eq - 1), STRING_TRIM);
                    string v = llStringTrim(llGetSubString(data, eq + 1, -1), STRING_TRIM);
                    if (k == "page_base") gPageBase = v;
                    else if (k == "screen_face") gFace = (integer)v;
                    else if (k == "channel") {
                        integer bar = llSubStringIndex(v, "|");
                        if (bar > 0 && llGetListLength(gChanNames) < MAX_CHANNELS) {
                            string url = llStringTrim(llGetSubString(v, bar + 1, -1), STRING_TRIM);
                            if (llGetSubString(url, 0, 7) == "https://") {
                                gChanNames += [llStringTrim(llGetSubString(v, 0, bar - 1), STRING_TRIM)];
                                gChanUrls  += [url];
                            } else llOwnerSay("SLTV: line " + (string)(gNcLine + 1) + ": channel URL must be https.");
                        } else if (bar <= 0) llOwnerSay("SLTV: line " + (string)(gNcLine + 1) + ": expected channel=Name|https://url");
                    }
                }
            }
            gNcLine++;
            gNcQuery = llGetNotecardLine(CONFIG_NC, gNcLine);
            return;
        }
        // EOF
        if (gPageBase == "" || llGetListLength(gChanNames) == 0) {
            llOwnerSay("SLTV: config incomplete — need page_base and at least one channel.");
            return;
        }
        if (gCh >= llGetListLength(gChanNames)) gCh = 0;
        gConfigured = TRUE;
        llRequestSecureURL();
    }

    http_request(key id, string method, string body) {
        if (method == URL_REQUEST_GRANTED) {
            gCapUrl = body;
            applyMedia();
            return;
        }
        if (method == URL_REQUEST_DENIED) {
            llOwnerSay("SLTV: no HTTP-in URL available (" + body + "); retrying in 60s.");
            gCapUrl = "";
            return; // timer retries
        }
        string qs = llGetHTTPHeader(id, "x-query-string");
        string op = qsVal(qs, "op");
        if (op == "") {
            llSetContentType(id, CONTENT_TYPE_HTML);
            llHTTPResponse(id, 200, bootstrapHtml());
            return;
        }
        if (op == "state") {
            llSetContentType(id, CONTENT_TYPE_JSON);
            llHTTPResponse(id, 200, stateJson());
            return;
        }
        if (op == "poll") {
            integer since = (integer)qsVal(qs, "since");
            if (since != gSeq) {
                llSetContentType(id, CONTENT_TYPE_JSON);
                llHTTPResponse(id, 200, stateJson());
            } else {
                gPolls += [id, since, llGetUnixTime()];
            }
            return;
        }
        llHTTPResponse(id, 400, "{}");
    }

    timer() {
        if (gCapUrl == "" && gConfigured) llRequestSecureURL();
        integer now = llGetUnixTime();
        integer i = llGetListLength(gPolls) - 3;
        for (; i >= 0; i -= 3) {
            if (now - llList2Integer(gPolls, i + 2) >= POLL_MAX_AGE) {
                key id = llList2Key(gPolls, i);
                llSetContentType(id, CONTENT_TYPE_JSON);
                llHTTPResponse(id, 200, llList2Json(JSON_OBJECT, ["seq", gSeq, "hb", 1]));
                gPolls = llDeleteSubList(gPolls, i, i + 2);
            }
        }
    }

    touch_start(integer n) {
        key av = llDetectedKey(0);
        if (!gConfigured) {
            if (av == llGetOwner()) llOwnerSay("SLTV: not configured — check the '" + CONFIG_NC + "' notecard.");
            return;
        }
        if (isAuthorized(av)) openDialog(av, "main");
        else llRegionSayTo(av, 0, "SLTV: enjoy the show! (Controls are owner/guest only.)");
    }

    listen(integer chan, string name, key id, string msg) {
        if (chan == APP_CHANNEL) {
            // HUD speaking: id is the HUD prim; trust anchor is the wearer.
            key wearer = llGetOwnerKey(id);
            string cmd = llJsonGetValue(msg, ["cmd"]);
            if (cmd == "disc") {
                if (isAuthorized(wearer))
                    llRegionSayTo(id, APP_CHANNEL, llList2Json(JSON_OBJECT,
                        ["cmd", "tv", "name", llGetObjectName()]));
                return;
            }
            if (cmd == "menu") {
                if (!gConfigured) return;
                if (isAuthorized(wearer)) openDialog(wearer, "main");
                else llRegionSayTo(wearer, 0, "SLTV: you are not on this TV's control list.");
            }
            return;
        }
        if (chan != DLG_CHANNEL || id != gDlgAvatar) return;
        key av = id;
        if (gDlgCtx == "main") {
            if (msg == "Power") doCmd(av, "power");
            else if (msg == "Fullscrn") doCmd(av, "fs");
            else if (msg == "Ch +") doCmd(av, "chup");
            else if (msg == "Ch -") doCmd(av, "chdn");
            else if (msg == "Channels") { openDialog(av, "channels"); return; }
            else if (msg == "Guests" && av == llGetOwner()) { openDialog(av, "guests"); return; }
            else if (msg == "Reload" && av == llGetOwner()) { gReload++; broadcast(); applyMedia(); }
        } else if (gDlgCtx == "channels") {
            doCmd(av, "ch:" + (string)((integer)msg - 1));
        } else if (gDlgCtx == "guests") {
            if (av != llGetOwner()) return;
            if (msg == "+ Add") {
                gDlgCtx = "addguest";
                llSensor("", NULL_KEY, AGENT, 20.0, PI);
                return;
            }
            if (msg == "- Revoke") { openDialog(av, "revoke"); return; }
            if (msg == "Clear") { gAclKeys = []; gAclNames = []; persist(); llOwnerSay("SLTV: guest list cleared."); }
            if (msg == "Back") { openDialog(av, "main"); return; }
        } else if (gDlgCtx == "addguest") {
            integer idx = (integer)msg - 1;
            if (idx >= 0 && idx < llGetListLength(gSensorKeys)) {
                string k = llList2String(gSensorKeys, idx);
                if (llListFindList(gAclKeys, [k]) == -1) {
                    gAclKeys += [k];
                    gAclNames += [llList2String(gSensorNames, idx)];
                    persist();
                    llRegionSayTo((key)k, 0, "SLTV: you can now control the TV — touch it or wear the remote.");
                    llOwnerSay("SLTV: granted " + llList2String(gSensorNames, idx) + ".");
                }
            }
        } else if (gDlgCtx == "revoke") {
            if (msg == "Back") { openDialog(av, "guests"); return; }
            integer idx = (integer)msg - 1;
            if (idx >= 0 && idx < llGetListLength(gAclKeys)) {
                llOwnerSay("SLTV: revoked " + llList2String(gAclNames, idx) + ".");
                gAclKeys = llDeleteSubList(gAclKeys, idx, idx);
                gAclNames = llDeleteSubList(gAclNames, idx, idx);
                persist();
            }
        }
    }

    sensor(integer n) {
        gSensorKeys = [];
        gSensorNames = [];
        string legend = "Grant control to:\n";
        list btns = [];
        if (n > 9) n = 9;
        integer i;
        for (i = 0; i < n; ++i) {
            gSensorKeys += [(string)llDetectedKey(i)];
            gSensorNames += [llDetectedName(i)];
            legend += (string)(i + 1) + "  " + llDetectedName(i) + "\n";
            btns += [(string)(i + 1)];
        }
        llListenRemove(gDlgListen);
        gDlgListen = llListen(DLG_CHANNEL, "", NULL_KEY, "");
        llDialog(gDlgAvatar, legend, btns, DLG_CHANNEL);
    }

    no_sensor() {
        llRegionSayTo(gDlgAvatar, 0, "SLTV: nobody within 20 m to add.");
    }

    changed(integer what) {
        if (what & CHANGED_REGION_START) {
            if (gCapUrl != "") llReleaseURL(gCapUrl);
            gCapUrl = "";
            if (gConfigured) llRequestSecureURL();
        }
        if (what & CHANGED_INVENTORY) llResetScript(); // notecard edited → full re-read
    }
}
