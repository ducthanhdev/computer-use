package com.deskpulse.app

import android.annotation.SuppressLint
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import android.view.KeyEvent
import android.view.View
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout

class MainActivity : AppCompatActivity() {

    private lateinit var webView: WebView
    private lateinit var swipeRefresh: SwipeRefreshLayout
    private lateinit var prefs: SharedPreferences

    companion object {
        private const val PREFS_NAME = "deskpulse_prefs"
        private const val KEY_SERVER_URL = "server_url"
        private const val DEFAULT_URL = "http://192.168.1.50:8765"
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        // Setup dynamic layout
        val rootLayout = FrameLayout(this)
        swipeRefresh = SwipeRefreshLayout(this)
        webView = WebView(this)

        swipeRefresh.addView(webView)
        rootLayout.addView(swipeRefresh)
        setContentView(rootLayout)

        // Configure WebView
        val settings = webView.settings
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.databaseEnabled = true
        settings.useWideViewPort = true
        settings.loadWithOverviewMode = true
        settings.cacheMode = WebSettings.LOAD_DEFAULT
        settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW

        webView.webChromeClient = WebChromeClient()
        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                swipeRefresh.isRefreshing = false
            }

            override fun onReceivedError(
                view: WebView?,
                request: WebResourceRequest?,
                error: WebResourceError?
            ) {
                if (request?.isForMainFrame == true) {
                    swipeRefresh.isRefreshing = false
                    showConnectionErrorDialog()
                }
            }
        }

        swipeRefresh.setOnRefreshListener {
            webView.reload()
        }

        // Long click anywhere with 2 fingers or long click on root to open settings
        webView.setOnLongClickListener {
            showServerAddressDialog()
            true
        }

        val savedUrl = prefs.getString(KEY_SERVER_URL, null)
        if (savedUrl.isNullOrEmpty()) {
            showServerAddressDialog()
        } else {
            loadServerUrl(savedUrl)
        }
    }

    private fun loadServerUrl(rawUrl: String) {
        var formatted = rawUrl.trim()
        if (!formatted.startsWith("http://") && !formatted.startsWith("https://")) {
            formatted = "http://$formatted"
        }
        prefs.edit().putString(KEY_SERVER_URL, formatted).apply()
        swipeRefresh.isRefreshing = true
        webView.loadUrl(formatted)
    }

    private fun showServerAddressDialog() {
        val currentUrl = prefs.getString(KEY_SERVER_URL, DEFAULT_URL) ?: DEFAULT_URL
        val input = EditText(this)
        input.hint = "192.168.1.xxx:8765"
        input.setText(currentUrl.replace("http://", "").replace("https://", ""))
        input.setSingleLine()

        val padding = (24 * resources.displayMetrics.density).toInt()
        val container = FrameLayout(this)
        container.setPadding(padding, padding / 2, padding, 0)
        container.addView(input)

        AlertDialog.Builder(this)
            .setTitle("Kết nối đến Máy tính (PC)")
            .setMessage("Nhập địa chỉ IP hiển thị trên màn hình terminal của máy tính:")
            .setView(container)
            .setPositiveButton("Kết nối") { _, _ ->
                val entered = input.text.toString().trim()
                if (entered.isNotEmpty()) {
                    loadServerUrl(entered)
                }
            }
            .setNeutralButton("Đổi IP") { _, _ ->
                input.setText("")
            }
            .setNegativeButton("Hủy", null)
            .show()
    }

    private fun showConnectionErrorDialog() {
        AlertDialog.Builder(this)
            .setTitle("Không thể kết nối")
            .setMessage("Không tìm thấy DeskPulse Server trên máy tính.\n\nHãy đảm bảo:\n1. Server đang chạy trên PC (chạy ./start.sh).\n2. Điện thoại và PC đang dùng chung mạng Wi-Fi.")
            .setPositiveButton("Thử lại") { _, _ ->
                webView.reload()
            }
            .setNegativeButton("Đổi địa chỉ IP") { _, _ ->
                showServerAddressDialog()
            }
            .show()
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_BACK && webView.canGoBack()) {
            webView.goBack()
            return true
        }
        return super.onKeyDown(keyCode, event)
    }
}
