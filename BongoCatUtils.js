.pragma library

var glyphMap = ["bc", "dc", "ba", "da"];
var blinkGlyph = "gh";
var sleepGlyph = "ef";

function catGlyph(catState, isWaiting, isBlinking, forceSleep) {
    if (forceSleep) return sleepGlyph;
    if (isWaiting) return sleepGlyph;
    if (isBlinking && catState === 0) return blinkGlyph;
    return glyphMap[catState] || glyphMap[0];
}

function catStateName(catState, isWaiting, isBlinking, forceSleep) {
    if (forceSleep) return "sleep";
    if (isWaiting) return "sleep";
    if (isBlinking && catState === 0) return "blink";
    return ["idle", "left", "right", "both"][catState] || "idle";
}

var colorModeOptions = ["Classic B/W", "Theme Primary", "Custom"];

function resolvedCatColor(catColorMode, catCustomColor, classicIdle, isWaiting, themeSurfaceText, themePrimary) {
    if (classicIdle && isWaiting) return themeSurfaceText;
    if (catColorMode === "primary") return themePrimary;
    if (catColorMode === "custom") return catCustomColor === "primary" ? themePrimary : Qt.color(catCustomColor);
    return themeSurfaceText;
}

function colorModeToLabel(m) {
    if (m === "primary") return "Theme Primary";
    if (m === "custom") return "Custom";
    return "Classic B/W";
}

function labelToColorMode(l) {
    if (l === "Theme Primary") return "primary";
    if (l === "Custom") return "custom";
    return "classic";
}
