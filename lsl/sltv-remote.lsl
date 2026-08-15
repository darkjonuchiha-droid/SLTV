// SLTV v1 — remote HUD. Wear, touch → the TV opens its control dialog for you.
// Pairs with the first responding SLTV in the region (owner's or one you're
// granted on). All authorization happens TV-side; this HUD is just a clicker —
// plus the camera-zoom actuator: attachments get PERMISSION_CONTROL_CAMERA
// silently, so the TV's "Zoom" button locks the wearer's camera onto the screen.

integer APP_CHANNEL = -77720011;
key     gTv = NULL_KEY;
integer gWaiting;
integer gHasCamPerm;
integer gZoomed;
string  gCamPos;
string  gCamFocus;

discover() {
    gTv = NULL_KEY;
    gWaiting = TRUE;
    llSetTimerEvent(3.0);
    llRegionSay(APP_CHANNEL, llList2Json(JSON_OBJECT, ["cmd", "disc"]));
}

// Maps a touch position on the remote texture to a button.
// Rows must match tools/remote-texture.html (t runs bottom→top in LSL).
string buttonAt(float s, float t) {
    if (t > 0.82) return "power";
    if (t > 0.64) return "fs";
    if (t > 0.46) { if (s < 0.5) return "chdn"; return "chup"; }
    if (t > 0.28) { if (s < 0.5) return "zoom"; return "channels"; }
    if (t > 0.10) return "menu";
    return ""; // logo area
}

applyCam() {
    llSetCameraParams([
        CAMERA_ACTIVE, 1,
        CAMERA_POSITION, (vector)gCamPos,
        CAMERA_POSITION_LOCKED, TRUE,
        CAMERA_FOCUS, (vector)gCamFocus,
        CAMERA_FOCUS_LOCKED, TRUE]);
    gZoomed = TRUE;
    llOwnerSay("SLTV remote: camera locked on the TV — Zoom again to release (Esc also works).");
}

releaseCam() {
    llClearCameraParams();
    llSetCameraParams([CAMERA_ACTIVE, 0]);
    gZoomed = FALSE;
    llOwnerSay("SLTV remote: camera released.");
}

default
{
    state_entry() {
        llListen(APP_CHANNEL, "", NULL_KEY, "");
        if (llGetAttached()) {
            discover();
            llRequestPermissions(llGetOwner(), PERMISSION_CONTROL_CAMERA);
        }
    }

    attach(key av) {
        if (av != NULL_KEY) {
            gCamPos = "";   // never re-apply a previous session's zoom on wear
            gZoomed = FALSE;
            discover();
            llRequestPermissions(llGetOwner(), PERMISSION_CONTROL_CAMERA);
        } else if (gZoomed) {
            gZoomed = FALSE; // detached while zoomed: viewer restores its own camera
        }
    }

    run_time_permissions(integer perm) {
        if (perm & PERMISSION_CONTROL_CAMERA) {
            gHasCamPerm = TRUE;
            if (gCamPos != "" && !gZoomed) applyCam();
        }
    }

    touch_start(integer n) {
        if (llDetectedKey(0) != llGetOwner()) return;
        if (gTv == NULL_KEY) { discover(); return; }
        vector st = llDetectedTouchST(0);
        if (st.x < 0.0) { // TOUCH_INVALID_TEXCOORD: fall back to the dialog menu
            llRegionSayTo(gTv, APP_CHANNEL, llList2Json(JSON_OBJECT, ["cmd", "menu"]));
            return;
        }
        string b = buttonAt(st.x, st.y);
        if (b == "") return;
        llRegionSayTo(gTv, APP_CHANNEL, llList2Json(JSON_OBJECT, ["cmd", "btn", "b", b]));
    }

    listen(integer chan, string name, key id, string msg) {
        string cmd = llJsonGetValue(msg, ["cmd"]);
        if (cmd == "tv") {
            if (gTv == NULL_KEY) { // first responder wins
                gTv = id;
                gWaiting = FALSE;
                llSetTimerEvent(0.0);
                llOwnerSay("SLTV remote: paired with \"" + llJsonGetValue(msg, ["name"]) + "\". Touch me for the menu.");
            }
            return;
        }
        if (cmd == "tvup") { // TV (re)started: refresh pairing
            discover();
            return;
        }
        if (cmd == "cam") {
            if (id != gTv) return;      // only our paired TV may move the camera
            if (gZoomed) { releaseCam(); return; }
            gCamPos = llJsonGetValue(msg, ["p"]);
            gCamFocus = llJsonGetValue(msg, ["f"]);
            if (gHasCamPerm) applyCam();
            else llRequestPermissions(llGetOwner(), PERMISSION_CONTROL_CAMERA);
            return;
        }
    }

    timer() {
        llSetTimerEvent(0.0);
        if (gWaiting && gTv == NULL_KEY)
            llOwnerSay("SLTV remote: no TV answered. Are you on its control list and in the same region?");
        gWaiting = FALSE;
    }
}
