pragma Singleton

import QtQuick
import QtMultimedia

// Owns the bongo-hit playback. Living in a singleton means there is exactly one
// set of SoundEffect objects per Quickshell process, no matter how many bar
// widget instances exist. On a multi-monitor setup each instance reads input
// independently and calls play() for the same keypress within the same event
// loop tick, so play() de-duplicates those near-simultaneous calls — otherwise
// the click would sound once per monitor (a doubled / flanged hit).
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

    function play(isBigHit) {
        const now = Date.now();
        if (now - _lastPlayMs < _dedupMs)
            return;
        _lastPlayMs = now;
        if (isBigHit) {
            _sfxBig.play();
        } else {
            // Alternate the two near-identical clicks so repeats aren't robotic.
            _alt = !_alt;
            (_alt ? _sfxKey1 : _sfxKey2).play();
        }
    }

    property SoundEffect _sfxKey1: SoundEffect {
        source: Qt.resolvedUrl("../assets/sounds/key.wav")
        volume: svc.volume
        onStatusChanged: if (status === SoundEffect.Error) console.warn("[BongoCat] failed to load key.wav")
    }
    property SoundEffect _sfxKey2: SoundEffect {
        source: Qt.resolvedUrl("../assets/sounds/key_alt.wav")
        volume: svc.volume
        onStatusChanged: if (status === SoundEffect.Error) console.warn("[BongoCat] failed to load key_alt.wav")
    }
    property SoundEffect _sfxBig: SoundEffect {
        source: Qt.resolvedUrl("../assets/sounds/space.wav")
        volume: svc.volume
        onStatusChanged: if (status === SoundEffect.Error) console.warn("[BongoCat] failed to load space.wav")
    }
}
