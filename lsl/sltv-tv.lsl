// SLTV v1 — TV prim script.
// State authority + HTTP-in bootstrap/long-poll server + media params + menus/ACL.
// Wire contract and design: docs/specs/2026-08-15-sltv-design.md

integer APP_CHANNEL  = -77720011;
integer DLG_CHANNEL  = -77720100;
string  CONFIG_NC    = "SLTV Config";
integer MAX_CHANNELS = 24;

// ---- config (from notecard) ----
string  gPageBase;             // e.g. https://darkjonuchiha-droid.github.io/SLTV/web
integer gFace = 2;             // default matches SLTV_Config.txt; notecard screen_face overrides
string  gScreenAxis = "";      // optional override; empty = auto-derive from screen_face (box prims)
vector  gScreenNorm;           // calibrated local screen normal (ZERO_VECTOR = not calibrated)
list    gChanNames;
list    gChanUrls;

// ---- paired remotes (from HUD discovery) ----
list    gHudWearers;           // avatar keys (as strings)
list    gHudKeys;              // parallel: their HUD prim keys

// ---- state ----
integer gSeq = 1;
integer gPower = TRUE;
integer gCh = 0;
integer gFs = FALSE;
integer gLock = TRUE;          // pointer shield up on all watchers' screens

// ---- infra ----
integer gReload;               // bumps ?r= to force a full reload for everyone
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

persist() {
    llLinksetDataWrite("sltv.state", llList2Json(JSON_OBJECT,
        ["power", gPower, "ch", gCh, "fs", gFs, "lock", gLock]));
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
        string lk = llJsonGetValue(s, ["lock"]);
        if (lk != JSON_INVALID) gLock = (integer)lk;
    }
    string a = llLinksetDataRead("sltv.acl");
    if (a != "") {
        gAclKeys  = llJson2List(llJsonGetValue(a, ["k"]));
        gAclNames = llJson2List(llJsonGetValue(a, ["n"]));
    }
}

// The whole TV state travels in the media URL's #fragment. The prim never
// serves any content (llSetContentType HTML is honored ONLY for the owner —
// other viewers get raw text/plain, confirmed in-world 2026-08-15).
string buildMediaUrl() {
    return gPageBase + "/index.html?r=" + (string)gReload
        + "#v=1&q=" + (string)gSeq
        + "&p=" + (string)gPower
        + "&f=" + (string)gFs
        + "&l=" + (string)gLock
        + "&n=" + llEscapeURL(llList2String(gChanNames, gCh))
        + "&u=" + llEscapeURL(llList2String(gChanUrls, gCh));
}

applyMedia() {
    if (!gConfigured) return;
    if (gFace >= llGetNumberOfSides()) {
        llOwnerSay("SLTV: screen_face " + (string)gFace + " does not exist on this prim ("
            + (string)llGetNumberOfSides() + " faces). Fix the notecard.");
        return;
    }
    string url = buildMediaUrl();
    if (llStringLength(url) > 1020) {
        llOwnerSay("SLTV: channel '" + llList2String(gChanNames, gCh)
            + "' makes the media URL too long — shorten the room URL or name.");
        return;
    }
    // llSetLinkMedia: same params as llSetPrimMediaParams but no forced sleep
    llSetLinkMedia(LINK_THIS, gFace, [
        PRIM_MEDIA_AUTO_PLAY, TRUE,
        PRIM_MEDIA_AUTO_SCALE, TRUE, // else the page sits unscaled in a power-of-2 texture (partial-face rendering)
        PRIM_MEDIA_AUTO_ZOOM, TRUE,  // native "Zoom into Media": clicking the screen frames the viewer's camera on it
        PRIM_MEDIA_FIRST_CLICK_INTERACT, TRUE,
        PRIM_MEDIA_CURRENT_URL, url,
        PRIM_MEDIA_HOME_URL, url,
        PRIM_MEDIA_PERMS_INTERACT, PRIM_MEDIA_PERM_ANYONE,
        PRIM_MEDIA_PERMS_CONTROL, PRIM_MEDIA_PERM_NONE, // no floating SL media bar for anyone
        PRIM_MEDIA_WIDTH_PIXELS, 1280,
        PRIM_MEDIA_HEIGHT_PIXELS, 720]);
}

broadcast() {
    gSeq++;
    persist();
    applyMedia();
}

doCmd(key av, string cmd) {
    if (!isAuthorized(av)) {
        llRegionSayTo(av, 0, "SLTV: you are not on this TV's control list.");
        return;
    }
    integer nCh = llGetListLength(gChanNames);
    if (cmd == "power")      gPower = !gPower;
    else if (cmd == "fs")    gFs = !gFs;
    else if (cmd == "lockt") gLock = !gLock;
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

vector axisVec(string a) {
    if (a == "+x") return <1.0, 0.0, 0.0>;
    if (a == "-x") return <-1.0, 0.0, 0.0>;
    if (a == "-y") return <0.0, -1.0, 0.0>;
    if (a == "+z") return <0.0, 0.0, 1.0>;
    if (a == "-z") return <0.0, 0.0, -1.0>;
    return <0.0, 1.0, 0.0>; // +y
}

vector faceNormal() {
    if (gScreenNorm != ZERO_VECTOR) return gScreenNorm; // measured via Calibrate: always wins
    if (gScreenAxis != "") return axisVec(gScreenAxis); // explicit override next
    // standard box face -> outward local normal: 0 top, 1..4 sides, 5 bottom
    if (gFace == 0) return <0.0, 0.0, 1.0>;
    if (gFace == 1) return <0.0, -1.0, 0.0>;
    if (gFace == 2) return <1.0, 0.0, 0.0>;
    if (gFace == 3) return <0.0, 1.0, 0.0>;
    if (gFace == 4) return <-1.0, 0.0, 0.0>;
    return <0.0, 0.0, -1.0>; // 5 bottom
}

calibrateFromPosition(key av) {
    // A flat TV's screen faces along its thinnest local dimension; the owner
    // standing in front tells us which of the two sides. No clicks on the
    // media face needed (the viewer never reliably hands those to scripts).
    vector avPos = llList2Vector(llGetObjectDetails(av, [OBJECT_POS]), 0);
    vector dirL = llVecNorm((avPos - llGetPos()) / llGetRot());
    vector s = llGetScale();
    vector axis = <1.0, 0.0, 0.0>;
    float m = s.x;
    if (s.y < m) { m = s.y; axis = <0.0, 1.0, 0.0>; }
    if (s.z < m) { axis = <0.0, 0.0, 1.0>; }
    float d = dirL * axis;
    if (llFabs(d) < 0.3) {
        llRegionSayTo(av, 0, "SLTV: stand squarely in FRONT of the screen, then press Calibrate again.");
        return;
    }
    if (d < 0.0) axis = -axis;
    gScreenNorm = axis;
    llLinksetDataWrite("sltv.norm", llList2Json(JSON_OBJECT, ["f", gFace, "n", (string)axis]));
    llOwnerSay("SLTV: camera zoom calibrated — screen faces local " + (string)axis + ". Try the Zoom button.");
}

doZoomFor(key av) {
    integer i = llListFindList(gHudWearers, [(string)av]);
    if (i == -1) {
        llRegionSayTo(av, 0, "SLTV: wear the remote (touch it once to pair) to use camera zoom.");
        return;
    }
    vector dims = llGetScale();
    list sorted = llListSort([dims.x, dims.y, dims.z], 1, FALSE); // descending
    float h = llList2Float(sorted, 1);        // 2nd-largest dimension ≈ screen height
    float d = (h * 0.5) / 0.57735 * 1.25;     // tan(30°) half-FOV + 25% margin
    vector n = faceNormal() * llGetRot();
    llRegionSayTo(llList2Key(gHudKeys, i), APP_CHANNEL, llList2Json(JSON_OBJECT, [
        "cmd", "cam",
        "p", (string)(llGetPos() + n * d),
        "f", (string)llGetPos()]));
}

openDialog(key av, string ctx) {
    llListenRemove(gDlgListen);
    gDlgListen = llListen(DLG_CHANNEL, "", NULL_KEY, "");
    gDlgAvatar = av;
    gDlgCtx = ctx;
    if (ctx == "main") {
        list btns = ["Power", "Fullscrn", "Ch +", "Ch -", "Channels", "Zoom", "Open Web"];
        if (av == llGetOwner()) {
            string lockBtn = "Unlock";
            if (!gLock) lockBtn = "Lock";
            btns += ["Guests", "Reload", "Calibrate", lockBtn, "Add Ch"];
        }
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
                    else if (k == "screen_axis") gScreenAxis = v;
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
        // EOF — append runtime channels (added in-world, LinksetData) after
        // the notecard ones, still respecting MAX_CHANNELS
        string xc = llLinksetDataRead("sltv.xchan");
        if (xc != "") {
            integer xi = 0;
            string xo = llJsonGetValue(xc, [xi]);
            while (xo != JSON_INVALID && llGetListLength(gChanNames) < MAX_CHANNELS) {
                gChanNames += [llJsonGetValue(xo, ["n"])];
                gChanUrls  += [llJsonGetValue(xo, ["u"])];
                xi++;
                xo = llJsonGetValue(xc, [xi]);
            }
        }
        if (gPageBase == "" || llGetListLength(gChanNames) == 0) {
            llOwnerSay("SLTV: config incomplete — need page_base and at least one channel.");
            return;
        }
        if (gCh >= llGetListLength(gChanNames)) gCh = 0;
        gConfigured = TRUE;
        // restore measured screen normal, but only if it was measured for THIS face
        string nr = llLinksetDataRead("sltv.norm");
        if (nr != "") {
            if ((integer)llJsonGetValue(nr, ["f"]) == gFace)
                gScreenNorm = (vector)llJsonGetValue(nr, ["n"]);
            else llLinksetDataDelete("sltv.norm");
        }
        applyMedia();
        llOwnerSay("SLTV: screen attached — " + (string)llGetListLength(gChanNames)
            + " channel(s), state rides the media URL.");
        // TV (re)started: ask remotes in the region to re-pair
        llRegionSay(APP_CHANNEL, llList2Json(JSON_OBJECT, ["cmd", "tvup"]));
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
                if (isAuthorized(wearer)) {
                    integer w = llListFindList(gHudWearers, [(string)wearer]);
                    if (w == -1) { gHudWearers += [(string)wearer]; gHudKeys += [id]; }
                    else gHudKeys = llListReplaceList(gHudKeys, [id], w, w);
                    llRegionSayTo(id, APP_CHANNEL, llList2Json(JSON_OBJECT,
                        ["cmd", "tv", "name", llGetObjectName()]));
                }
                return;
            }
            if (cmd == "menu") {
                if (!gConfigured) return;
                if (isAuthorized(wearer)) openDialog(wearer, "main");
                else llRegionSayTo(wearer, 0, "SLTV: you are not on this TV's control list.");
                return;
            }
            if (cmd == "btn") { // direct button from the textured remote
                if (!gConfigured) return;
                if (!isAuthorized(wearer)) {
                    llRegionSayTo(wearer, 0, "SLTV: you are not on this TV's control list.");
                    return;
                }
                string b = llJsonGetValue(msg, ["b"]);
                if (b == "power" || b == "fs" || b == "chup" || b == "chdn") doCmd(wearer, b);
                else if (b == "lockt") {
                    if (wearer == llGetOwner()) {
                        doCmd(wearer, "lockt");
                        if (!gLock) llRegionSayTo(wearer, 0, "SLTV: screen unlocked — clicks reach Kosmi for everyone. Lock again after managing.");
                        else llRegionSayTo(wearer, 0, "SLTV: screen locked.");
                    } else llRegionSayTo(wearer, 0, "SLTV: only the owner can unlock the screen.");
                }
                else if (b == "zoom") doZoomFor(wearer);
                else if (b == "channels") openDialog(wearer, "channels");
                else if (b == "menu") openDialog(wearer, "main");
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
            else if (msg == "Zoom") doZoomFor(av);
            else if (msg == "Channels") { openDialog(av, "channels"); return; }
            else if (msg == "Guests" && av == llGetOwner()) { openDialog(av, "guests"); return; }
            else if (msg == "Reload" && av == llGetOwner()) { gReload++; broadcast(); } // ?r change = hard reload for all
            else if (msg == "Calibrate" && av == llGetOwner()) calibrateFromPosition(av);
            else if ((msg == "Unlock" || msg == "Lock") && av == llGetOwner()) {
                doCmd(av, "lockt");
                if (!gLock) llRegionSayTo(av, 0, "SLTV: screen unlocked — clicks now reach Kosmi on every watcher's screen. Lock it again after managing.");
                else llRegionSayTo(av, 0, "SLTV: screen locked.");
            }
            else if (msg == "Open Web") {
                llLoadURL(av, "Open this channel's Kosmi room in your own browser. Log in there for admin controls.",
                    llList2String(gChanUrls, gCh));
            }
            else if (msg == "Add Ch" && av == llGetOwner()) {
                gDlgCtx = "addchan";
                llListenRemove(gDlgListen);
                gDlgListen = llListen(DLG_CHANNEL, "", NULL_KEY, "");
                llTextBox(av, "Add a channel:\n  Name|https://app.kosmi.io/room/xxx\n\nRemove a runtime channel:\n  del Name", DLG_CHANNEL);
                return;
            }
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
        } else if (gDlgCtx == "addchan") {
            if (av != llGetOwner()) return;
            string xc = llLinksetDataRead("sltv.xchan");
            if (xc == "") xc = "[]";
            if (llGetSubString(msg, 0, 3) == "del ") {
                string dn = llStringTrim(llGetSubString(msg, 4, -1), STRING_TRIM);
                list keep = [];
                integer removed = FALSE;
                integer xi = 0;
                string xo = llJsonGetValue(xc, [xi]);
                while (xo != JSON_INVALID) {
                    if (llJsonGetValue(xo, ["n"]) == dn && !removed) removed = TRUE;
                    else keep += [xo];
                    xi++;
                    xo = llJsonGetValue(xc, [xi]);
                }
                if (removed) {
                    llLinksetDataWrite("sltv.xchan", llList2Json(JSON_ARRAY, keep));
                    llOwnerSay("SLTV: removed runtime channel '" + dn + "'. Restarting…");
                    llResetScript();
                } else llOwnerSay("SLTV: no runtime channel named '" + dn
                    + "' (notecard channels are managed by editing the notecard).");
                return;
            }
            integer bar = llSubStringIndex(msg, "|");
            if (bar > 0) {
                string nm = llStringTrim(llGetSubString(msg, 0, bar - 1), STRING_TRIM);
                string xurl = llStringTrim(llGetSubString(msg, bar + 1, -1), STRING_TRIM);
                if (nm != "" && llGetSubString(xurl, 0, 7) == "https://") {
                    xc = llJsonSetValue(xc, [JSON_APPEND], llList2Json(JSON_OBJECT, ["n", nm, "u", xurl]));
                    llLinksetDataWrite("sltv.xchan", xc);
                    llOwnerSay("SLTV: added channel '" + nm + "'. Restarting…");
                    llResetScript();
                } else llOwnerSay("SLTV: expected Name|https://url");
            } else llOwnerSay("SLTV: expected Name|https://url  (or: del Name)");
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
        // No region-restart handling needed: the media URL is object state and
        // stays valid — viewers simply reload it when the region returns.
        if (what & CHANGED_INVENTORY) llResetScript(); // notecard edited → full re-read
    }
}
