// Microphone for the listen modes, and lets the voice player start on its own for Autosmash.
const fs = require("fs");
const path = require("path");
const m = "src-tauri/gen/android/app/src/main/AndroidManifest.xml";
let s = fs.readFileSync(m, "utf8");
if (!s.includes("android.permission.RECORD_AUDIO")) {
  s = s.replace("<application",
    '<uses-permission android:name="android.permission.RECORD_AUDIO" />\n    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />\n    <application');
  fs.writeFileSync(m, s);
}
function find(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) { const r = find(p); if (r) return r; }
    else if (e.name === "MainActivity.kt") return p;
  }
  return null;
}
const act = find("src-tauri/gen/android/app/src/main");
if (act) {
  let k = fs.readFileSync(act, "utf8");
  if (!k.includes("mediaPlaybackRequiresUserGesture")) {
    const at = k.lastIndexOf("}");
    const fn = [
      "  override fun onWebViewCreate(webView: android.webkit.WebView) {",
      "    webView.settings.mediaPlaybackRequiresUserGesture = false",
      "    val root = findViewById<android.view.View>(android.R.id.content)",
      "    root.setBackgroundColor(android.graphics.Color.parseColor(\"#e9e6df\"))",
      "    androidx.core.view.ViewCompat.setOnApplyWindowInsetsListener(root) { v, insets ->",
      "      val b = insets.getInsets(androidx.core.view.WindowInsetsCompat.Type.systemBars() or androidx.core.view.WindowInsetsCompat.Type.displayCutout())",
      "      v.setPadding(b.left, b.top, b.right, b.bottom)",
      "      androidx.core.view.WindowInsetsCompat.CONSUMED",
      "    }",
      "    root.requestApplyInsets()",
      "    androidx.core.view.WindowCompat.getInsetsController(window, window.decorView).isAppearanceLightStatusBars = true",
      "  }",
      ""
    ].join("\n");
    k = k.slice(0, at) + fn + k.slice(at);
    fs.writeFileSync(act, k);
    console.log("Autoplay and status bar spacing set in " + act);
  }
}
console.log("Android manifest ready");
