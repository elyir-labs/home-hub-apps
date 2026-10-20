// SPDX-License-Identifier: Apache-2.0
/*
 The app: one web view onto the Houses app, edge to edge on the panel's own night, with J over it until it is
 ready. Everything a house shows is the page's; this only keeps the page in the app, sends what should leave it to
 the system browser, and passes the page's asks for the camera, the microphone and a file to Android.
 */
package app.elyir.houses

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Message
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.WindowManager
import android.webkit.CookieManager
import android.webkit.PermissionRequest
import android.webkit.RenderProcessGoneDetail
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import kotlin.math.max

class Houses : Activity() {
    private companion object {
        const val SEEN = "startup.seen"
        const val RETRY = 4_000L
        const val STOREFRONT_WAIT = 1_500L
        const val ASK_DEVICES = 1
        const val PICK_FILES = 2
    }

    private val ui = Handler(Looper.getMainLooper())
    private val prefs by lazy { getSharedPreferences("houses", MODE_PRIVATE) }
    private val sequence by lazy { Sequence(assets.open("startup.json").bufferedReader().use { it.readText() }) }
    private lateinit var home: String
    private lateinit var page: FrameLayout
    private var web: WebView? = null
    private var startup: StartupView? = null
    private var start: String? = null
    private var shown = false
    private var failed = false
    private var asking: PermissionRequest? = null
    private var picking: ValueCallback<Array<Uri>>? = null
    private val again = Runnable { if (!shown) start?.let { web?.loadUrl(it) } }

    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        home = devHome() ?: Shell.HOUSES
        edgeToEdge()

        val root = FrameLayout(this).apply { setBackgroundColor(getColor(R.color.night)) }
        page = FrameLayout(this)
        root.addView(page, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
        // Android's web view has long told the page no safe area (109 on API 33 says 0), so the page sits inside the
        // bars and above the keyboard while J and the night run under them. Consuming the insets keeps a newer web
        // view, which does report them, from counting them twice.
        ViewCompat.setOnApplyWindowInsetsListener(root) { _, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars() or WindowInsetsCompat.Type.displayCutout())
            val keyboard = insets.getInsets(WindowInsetsCompat.Type.ime())
            page.setPadding(bars.left, bars.top, bars.right, max(bars.bottom, keyboard.bottom))
            WindowInsetsCompat.CONSUMED
        }
        startup = StartupView(this, sequence, full = !prefs.getBoolean(SEEN, false)) {
            root.removeView(startup)
            startup = null
            prefs.edit().putBoolean(SEEN, true).apply()
        }
        root.addView(startup, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
        setContentView(root)

        Storefront.ask(this, STOREFRONT_WAIT) { store ->
            if (isDestroyed) return@ask
            start = Shell.start(home, store)
            open()
        }
    }

    /**
     * A debug build can be pointed at a dev server, the way the iOS scheme's `-houses` argument does it:
     * `adb shell am start -n app.elyir.houses/.Houses -e houses http://10.0.2.2:5174/`. It is kept until
     * `-e houses ""` clears it. A release build always opens houses.elyir.app.
     */
    private fun devHome(): String? {
        if (!BuildConfig.DEBUG) return null
        val dev = getSharedPreferences("dev", MODE_PRIVATE)
        intent.getStringExtra("houses")?.let { dev.edit().putString("houses", it).apply() }
        return dev.getString("houses", null)?.takeIf { it.isNotBlank() }
    }

    private fun edgeToEdge() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowCompat.getInsetsController(window, window.decorView).apply {
            isAppearanceLightStatusBars = false
            isAppearanceLightNavigationBars = false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
            window.isStatusBarContrastEnforced = false
        }
    }

    private fun open(at: String? = start) {
        val view = makeWebView()
        web = view
        page.addView(view, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
        at?.let(view::loadUrl)
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun makeWebView() = WebView(this).apply {
        WebView.setWebContentsDebuggingEnabled(BuildConfig.DEBUG)
        CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)
        setBackgroundColor(getColor(R.color.night))
        overScrollMode = WebView.OVER_SCROLL_NEVER
        settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            mediaPlaybackRequiresUserGesture = false
            // The panel opens the payment page a beat after the tap, once the address is claimed (docs/apps.md).
            javaScriptCanOpenWindowsAutomatically = true
            setSupportMultipleWindows(true)
        }
        webViewClient = Client()
        webChromeClient = Chrome()
    }

    private inner class Client : WebViewClient() {
        override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
            val url = request.url.toString()
            if (!Shell.opensOutside(url, request.isForMainFrame, home)) return false
            openOutside(url)
            return true
        }

        override fun onPageStarted(view: WebView, url: String?, favicon: android.graphics.Bitmap?) { failed = false }

        override fun onPageFinished(view: WebView, url: String?) {
            if (shown || failed) return
            shown = true
            view.clearHistory()
            startup?.ready = true
        }

        /** Until the first page has drawn, a failed load is said under the house and tried again every few seconds. */
        override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
            if (!request.isForMainFrame || shown) return
            failed = true
            startup?.unreachable = true
            ui.removeCallbacks(again)
            ui.postDelayed(again, RETRY)
        }

        /** The system can end the page's process while the app is behind another; start the page again in a new view. */
        override fun onRenderProcessGone(view: WebView, detail: RenderProcessGoneDetail): Boolean {
            val at = view.url?.takeIf { shown }
            page.removeView(view)
            view.destroy()
            if (web === view) open(at ?: start)
            return true
        }
    }

    private inner class Chrome : WebChromeClient() {
        /**
         * window.open and target="_blank", from the page or any house inside it: never a second web view on screen.
         * Android only says where the new window is going once it starts loading, so an unseen one catches that.
         */
        override fun onCreateWindow(view: WebView, isDialog: Boolean, isUserGesture: Boolean, resultMsg: Message): Boolean {
            val catcher = WebView(this@Houses)
            var taken = false
            fun take(url: String?) {
                if (taken || url.isNullOrEmpty() || url == "about:blank") return
                taken = true
                if (Shell.opensOutside(url, true, home)) openOutside(url) else web?.loadUrl(url)
                ui.post { catcher.stopLoading(); catcher.destroy() }
            }
            catcher.webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(v: WebView, r: WebResourceRequest): Boolean { take(r.url.toString()); return true }
                override fun onPageStarted(v: WebView, url: String?, favicon: android.graphics.Bitmap?) { take(url) }
            }
            ui.postDelayed({ if (!taken) { taken = true; catcher.destroy() } }, 30_000)
            (resultMsg.obj as WebView.WebViewTransport).webView = catcher
            resultMsg.sendToTarget()
            return true
        }

        /** The page reads a code with the camera and listens for what to tell the house; Android asks the person. */
        override fun onPermissionRequest(request: PermissionRequest) {
            val needed = request.resources.mapNotNull(::permissionFor).distinct()
            if (needed.isEmpty()) return request.deny()
            val missing = needed.filter { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
            if (missing.isEmpty()) return grantWhatIsAllowed(request)
            asking?.deny()
            asking = request
            requestPermissions(missing.toTypedArray(), ASK_DEVICES)
        }

        override fun onPermissionRequestCanceled(request: PermissionRequest) {
            if (asking === request) asking = null
        }

        override fun onShowFileChooser(view: WebView, callback: ValueCallback<Array<Uri>>, params: FileChooserParams): Boolean {
            picking?.onReceiveValue(null)
            picking = callback
            return try {
                @Suppress("DEPRECATION")
                startActivityForResult(params.createIntent(), PICK_FILES)
                true
            } catch (_: ActivityNotFoundException) {
                picking = null
                false
            }
        }
    }

    private fun permissionFor(resource: String) = when (resource) {
        PermissionRequest.RESOURCE_VIDEO_CAPTURE -> Manifest.permission.CAMERA
        PermissionRequest.RESOURCE_AUDIO_CAPTURE -> Manifest.permission.RECORD_AUDIO
        else -> null
    }

    private fun grantWhatIsAllowed(request: PermissionRequest) {
        val allowed = request.resources.filter { r ->
            permissionFor(r)?.let { checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED } ?: false
        }
        if (allowed.isEmpty()) request.deny() else request.grant(allowed.toTypedArray())
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != ASK_DEVICES) return
        asking?.let(::grantWhatIsAllowed)
        asking = null
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_FILES) return
        picking?.onReceiveValue(WebChromeClient.FileChooserParams.parseResult(resultCode, data))
        picking = null
    }

    private fun openOutside(url: String) {
        try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addCategory(Intent.CATEGORY_BROWSABLE))
        } catch (_: ActivityNotFoundException) {
        }
    }

    /** Back goes back inside the Houses app while it can, and leaves the app when it cannot. */
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        val view = web
        if (view != null && view.canGoBack()) view.goBack()
        else @Suppress("DEPRECATION") super.onBackPressed()
    }

    override fun onDestroy() {
        ui.removeCallbacksAndMessages(null)
        web?.destroy()
        web = null
        super.onDestroy()
    }
}
