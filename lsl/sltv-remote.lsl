// SLTV v1 — remote HUD. Wear, touch → the TV opens its control dialog for you.
// Pairs with the first responding SLTV in the region (owner's or one you're
// granted on). All authorization happens TV-side; this HUD is just a clicker.

integer APP_CHANNEL = -77720011;
key     gTv = NULL_KEY;
integer gWaiting;

discover() {
    gTv = NULL_KEY;
    gWaiting = TRUE;
    llSetTimerEvent(3.0);
    llRegionSay(APP_CHANNEL, llList2Json(JSON_OBJECT, ["cmd", "disc"]));
}

default
{
    state_entry() {
        llListen(APP_CHANNEL, "", NULL_KEY, "");
        if (llGetAttached()) discover();
    }

    attach(key av) {
        if (av != NULL_KEY) discover();
    }

    touch_start(integer n) {
        if (llDetectedKey(0) != llGetOwner()) return;
        if (gTv == NULL_KEY) discover();
        else llRegionSayTo(gTv, APP_CHANNEL, llList2Json(JSON_OBJECT, ["cmd", "menu"]));
    }

    listen(integer chan, string name, key id, string msg) {
        if (llJsonGetValue(msg, ["cmd"]) != "tv") return;
        if (gTv == NULL_KEY) { // first responder wins
            gTv = id;
            gWaiting = FALSE;
            llSetTimerEvent(0.0);
            llOwnerSay("SLTV remote: paired with \"" + llJsonGetValue(msg, ["name"]) + "\". Touch me for the menu.");
        }
    }

    timer() {
        llSetTimerEvent(0.0);
        if (gWaiting && gTv == NULL_KEY)
            llOwnerSay("SLTV remote: no TV answered. Are you on its control list and in the same region?");
        gWaiting = FALSE;
    }
}
