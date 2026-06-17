pragma Singleton

import QtQuick

// Owns the bongo-hit playback. Living in a singleton means there is exactly one
// set of SoundEffect objects per Quickshell process, no matter how many bar
// widget instances exist. On a multi-monitor setup each instance reads input
// independently and calls play() for the same keypress within the same event
// loop tick, so play() de-duplicates those near-simultaneous calls — otherwise
// the click would sound once per monitor (a doubled / flanged hit).
//
// QtMultimedia is loaded dynamically (not a static import) so the plugin still
// loads on systems without it — DMS treats QtMultimedia the same way in
// AudioService. If it's missing, _available stays false and play() is a no-op.
QtObject {
    id: svc

    // Set by the widget before each play; identical across monitors (shared pluginData).
    property real volume: 0.6

    property double _lastPlayMs: 0
    // Calls within this window are treated as the same keypress arriving from
    // another monitor's widget instance and ignored. Well below the gap between
    // distinct keystrokes in real typing, well above same-tick scheduling jitter.
    readonly property int _dedupMs: 25
    property bool _alt: false

    property var _sfxKey1: null
    property var _sfxKey2: null
    property var _sfxBig: null
    property bool _available: false

    function _makeSfx(file) {
        return Qt.createQmlObject(
            'import QtMultimedia; SoundEffect {'
            + ' source: "' + Qt.resolvedUrl("../assets/sounds/" + file) + '";'
            + ' onStatusChanged: if (status === SoundEffect.Error)'
            + ' console.warn("[BongoCat] failed to load ' + file + '") }',
            svc);
    }

    Component.onCompleted: {
        try {
            _sfxKey1 = _makeSfx("key.wav");
            _sfxKey2 = _makeSfx("key_alt.wav");
            _sfxBig = _makeSfx("space.wav");
            _available = true;
        } catch (e) {
            console.warn("[BongoCat] QtMultimedia unavailable — key sounds disabled:", e);
        }
    }

    function play(isBigHit) {
        if (!_available)
            return;
        const now = Date.now();
        if (now - _lastPlayMs < _dedupMs)
            return;
        _lastPlayMs = now;
        // Alternate the two near-identical clicks so repeats aren't robotic.
        const sfx = isBigHit ? _sfxBig : ((_alt = !_alt) ? _sfxKey1 : _sfxKey2);
        sfx.volume = volume;
        sfx.play();
    }
}
