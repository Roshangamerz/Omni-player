package echo.music.iad1tya.ui.screens

import android.annotation.SuppressLint
import android.content.Intent
import android.os.Message
import android.webkit.ConsoleMessage
import android.webkit.CookieManager
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.viewinterop.AndroidView
import androidx.datastore.preferences.core.edit
import androidx.navigation.NavController
import com.music.innertube.YouTube
import com.music.innertube.utils.parseCookieString
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.EntryPointAccessors
import dagger.hilt.components.SingletonComponent
import echo.music.iad1tya.LocalPlayerAwareWindowInsets
import echo.music.iad1tya.R
import echo.music.iad1tya.constants.AccountChannelHandleKey
import echo.music.iad1tya.constants.AccountEmailKey
import echo.music.iad1tya.constants.AccountNameKey
import echo.music.iad1tya.constants.DataSyncIdKey
import echo.music.iad1tya.constants.InnerTubeCookieKey
import echo.music.iad1tya.constants.SavedAccountsKey
import echo.music.iad1tya.constants.VisitorDataKey
import echo.music.iad1tya.constants.YtmSyncKey
import echo.music.iad1tya.models.AccountData
import echo.music.iad1tya.ui.component.IconButton
import echo.music.iad1tya.ui.utils.backToMain
import echo.music.iad1tya.utils.SyncUtils
import echo.music.iad1tya.utils.dataStore
import echo.music.iad1tya.utils.rememberPreference
import kotlinx.coroutines.DelicateCoroutinesApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import timber.log.Timber

@EntryPoint
@InstallIn(SingletonComponent::class)
interface LoginSyncEntryPoint {
  fun syncUtils(): SyncUtils
}

private val ALLOWED_LOGIN_HOSTS_REGEX =
  Regex(
    """(^|\.)(google|youtube|gstatic|googleusercontent|googleapis|googlevideo)\.[a-z.]+$|^g\.co$""",
    RegexOption.IGNORE_CASE,
  )

private fun isAllowedLoginHost(host: String): Boolean {
  if (host.isEmpty()) return false
  return ALLOWED_LOGIN_HOSTS_REGEX.containsMatchIn(host)
}

private fun hasValidSapisid(cookie: String?): Boolean {
  if (cookie.isNullOrBlank()) return false
  val parsed = parseCookieString(cookie)
  return "SAPISID" in parsed || "__Secure-3PAPISID" in parsed
}

@SuppressLint("SetJavaScriptEnabled")
@OptIn(ExperimentalMaterial3Api::class, DelicateCoroutinesApi::class)
@Composable
fun LoginScreen(navController: NavController) {
  val context = LocalContext.current
  val coroutineScope = rememberCoroutineScope()
  var visitorData by rememberPreference(VisitorDataKey, "")
  var dataSyncId by rememberPreference(DataSyncIdKey, "")
  var innerTubeCookie by rememberPreference(InnerTubeCookieKey, "")
  var accountName by rememberPreference(AccountNameKey, "")
  var accountEmail by rememberPreference(AccountEmailKey, "")
  var accountChannelHandle by rememberPreference(AccountChannelHandleKey, "")
  var savedAccountsJson by rememberPreference(SavedAccountsKey, "[]")
  var hasCompletedLogin by remember { mutableStateOf(false) }
  var isLoading by remember { mutableStateOf(true) }
  var webView by remember { mutableStateOf<WebView?>(null) }

  val syncUtils = remember {
    EntryPointAccessors.fromApplication(context.applicationContext, LoginSyncEntryPoint::class.java)
      .syncUtils()
  }

  fun processSuccessfulAuth(capturedCookie: String) {
    if (hasCompletedLogin) return
    hasCompletedLogin = true

    coroutineScope.launch {
      // Give JS bridge a brief moment to capture VISITOR_DATA & DATASYNC_ID
      repeat(8) {
        if (visitorData.isNotBlank() && dataSyncId.isNotBlank()) return@repeat
        delay(250)
      }

      val finalVisitorData = visitorData
      val finalDataSyncId = dataSyncId
      innerTubeCookie = capturedCookie

      YouTube.cookie = capturedCookie
      if (finalDataSyncId.isNotBlank()) YouTube.dataSyncId = finalDataSyncId
      if (finalVisitorData.isNotBlank()) YouTube.visitorData = finalVisitorData

      // Ensure DataStore is flushed synchronously before SyncUtils checks isLoggedIn()
      context.dataStore.edit { prefs ->
        prefs[InnerTubeCookieKey] = capturedCookie
        if (finalDataSyncId.isNotBlank()) prefs[DataSyncIdKey] = finalDataSyncId
        if (finalVisitorData.isNotBlank()) prefs[VisitorDataKey] = finalVisitorData
        prefs[YtmSyncKey] = true
      }

      Timber.d("Login: YouTube object initialized, validating accountInfo...")

      val accountResult = withContext(Dispatchers.IO) { YouTube.accountInfo() }
      accountResult
        .onSuccess { info ->
          accountName = info.name
          accountEmail = info.email.orEmpty()
          accountChannelHandle = info.channelHandle.orEmpty()

          val newAccount =
            AccountData(
              name = info.name,
              email = info.email.orEmpty(),
              channelHandle = info.channelHandle.orEmpty(),
              cookie = capturedCookie,
              visitorData = finalVisitorData,
              dataSyncId = finalDataSyncId,
              avatarUrl = info.thumbnailUrl.orEmpty(),
            )
          val accounts =
            try {
                Json.decodeFromString<List<AccountData>>(savedAccountsJson)
              } catch (e: Exception) {
                emptyList()
              }
              .toMutableList()
          accounts.removeAll { acc -> acc.name == newAccount.name }
          accounts.add(newAccount)
          val encoded = Json.encodeToString(accounts)
          savedAccountsJson = encoded

          context.dataStore.edit { prefs ->
            prefs[AccountNameKey] = info.name
            prefs[AccountEmailKey] = info.email.orEmpty()
            prefs[AccountChannelHandleKey] = info.channelHandle.orEmpty()
            prefs[SavedAccountsKey] = encoded
          }

          // Trigger immediate YouTube playlist & library sync
          withContext(Dispatchers.IO) {
            syncUtils.syncSavedPlaylists()
            syncUtils.tryAutoSync()
          }

          webView?.apply {
            stopLoading()
            clearHistory()
            clearCache(true)
            clearFormData()
          }

          android.widget.Toast.makeText(
              context,
              "Logged in as ${info.name}. Syncing playlists...",
              android.widget.Toast.LENGTH_SHORT,
            )
            .show()

          if (!navController.navigateUp()) {
            navController.backToMain()
          }
        }
        .onFailure { error ->
          Timber.e(error, "Login: accountInfo() failed, saving cookie & triggering playlist sync")
          val fallbackName = accountName.ifBlank { "YouTube Music" }
          val newAccount =
            AccountData(
              name = fallbackName,
              email = accountEmail,
              channelHandle = accountChannelHandle,
              cookie = capturedCookie,
              visitorData = finalVisitorData,
              dataSyncId = finalDataSyncId,
              avatarUrl = "",
            )
          val accounts =
            try {
                Json.decodeFromString<List<AccountData>>(savedAccountsJson)
              } catch (e: Exception) {
                emptyList()
              }
              .toMutableList()
          accounts.removeAll { acc -> acc.cookie == capturedCookie }
          accounts.add(newAccount)
          val encoded = Json.encodeToString(accounts)
          savedAccountsJson = encoded

          context.dataStore.edit { prefs ->
            prefs[AccountNameKey] = fallbackName
            prefs[SavedAccountsKey] = encoded
          }

          withContext(Dispatchers.IO) {
            syncUtils.syncSavedPlaylists()
            syncUtils.tryAutoSync()
          }

          webView?.apply {
            stopLoading()
            clearHistory()
            clearCache(true)
            clearFormData()
          }

          android.widget.Toast.makeText(
              context,
              "Logged in. Syncing playlists...",
              android.widget.Toast.LENGTH_SHORT,
            )
            .show()

          if (!navController.navigateUp()) {
            navController.backToMain()
          }
        }
    }
  }

  Column(
    modifier = Modifier.fillMaxSize().windowInsetsPadding(LocalPlayerAwareWindowInsets.current)
  ) {
    TopAppBar(
      title = { Text(stringResource(R.string.login)) },
      navigationIcon = {
        IconButton(onClick = navController::navigateUp, onLongClick = navController::backToMain) {
          Icon(painterResource(R.drawable.arrow_back), contentDescription = null)
        }
      },
    )

    if (isLoading) {
      LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
    }

    AndroidView(
      modifier = Modifier.fillMaxSize(),
      factory = { webViewContext ->
        WebView(webViewContext).apply {
          webViewClient =
            object : WebViewClient() {
              override fun shouldOverrideUrlLoading(
                view: WebView,
                request: WebResourceRequest,
              ): Boolean {
                val url = request.url ?: return false
                val host = url.host?.lowercase().orEmpty()
                val scheme = url.scheme?.lowercase().orEmpty()

                if (scheme != "http" && scheme != "https") {
                  try {
                    context.startActivity(Intent(Intent.ACTION_VIEW, url))
                  } catch (e: Exception) {
                    Timber.w(e, "Cannot open scheme: $url")
                  }
                  return true
                }

                if (isAllowedLoginHost(host)) {
                  return false
                }

                try {
                  context.startActivity(Intent(Intent.ACTION_VIEW, url))
                } catch (e: Exception) {
                  Timber.w(e, "Cannot open external URL: $url")
                }
                return true
              }

              override fun onPageStarted(
                view: WebView?,
                url: String?,
                favicon: android.graphics.Bitmap?,
              ) {
                isLoading = true
              }

              override fun onPageFinished(view: WebView, url: String?) {
                isLoading = false
                if (url?.contains("youtube.com") == true) {
                  evaluateJavascript(
                    "(function() { return (window.yt && window.yt.config_) ? window.yt.config_.VISITOR_DATA : ''; })();",
                  ) { value ->
                    val unquoted = value?.removeSurrounding("\"")
                    if (!unquoted.isNullOrEmpty() && unquoted != "null") {
                      visitorData = unquoted
                    }
                  }
                  evaluateJavascript(
                    "(function() { return (window.yt && window.yt.config_) ? window.yt.config_.DATASYNC_ID : ''; })();",
                  ) { value ->
                    val unquoted = value?.removeSurrounding("\"")
                    if (!unquoted.isNullOrEmpty() && unquoted != "null") {
                      dataSyncId = unquoted.substringBefore("||")
                    }
                  }
                  loadUrl(
                    "javascript:Android.onRetrieveVisitorData(window.yt && window.yt.config_ ? window.yt.config_.VISITOR_DATA : '')",
                  )
                  loadUrl(
                    "javascript:Android.onRetrieveDataSyncId(window.yt && window.yt.config_ ? window.yt.config_.DATASYNC_ID : '')",
                  )
                }

                val cookieManager = CookieManager.getInstance()
                cookieManager.flush()
                val musicCookie = cookieManager.getCookie("https://music.youtube.com")
                val ytCookie = cookieManager.getCookie("https://www.youtube.com")
                val currentCookie =
                  if (!url.isNullOrEmpty()) cookieManager.getCookie(url) else null

                val effectiveCookie =
                  when {
                    hasValidSapisid(musicCookie) -> musicCookie
                    hasValidSapisid(ytCookie) -> ytCookie
                    hasValidSapisid(currentCookie) -> currentCookie
                    else -> null
                  }

                val isYouTube = url?.contains("youtube.com") == true
                if (isYouTube && effectiveCookie != null && !hasCompletedLogin) {
                  processSuccessfulAuth(effectiveCookie)
                }
              }
            }

          webChromeClient =
            object : WebChromeClient() {
              override fun onCreateWindow(
                view: WebView?,
                isDialog: Boolean,
                isUserGesture: Boolean,
                resultMsg: Message?,
              ): Boolean {
                val transport = resultMsg?.obj as? WebView.WebViewTransport ?: return false
                transport.webView = view
                resultMsg.sendToTarget()
                return true
              }

              override fun onConsoleMessage(consoleMessage: ConsoleMessage?): Boolean {
                Timber.d(
                  "Login WebView: ${consoleMessage?.message()} [${consoleMessage?.sourceId()}:${consoleMessage?.lineNumber()}]",
                )
                return super.onConsoleMessage(consoleMessage)
              }
            }

          settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            javaScriptCanOpenWindowsAutomatically = true
            setSupportMultipleWindows(true)
            allowFileAccess = false
            allowContentAccess = false
            setSupportZoom(true)
            builtInZoomControls = true
            displayZoomControls = false
            mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE

            val defaultUa = userAgentString ?: WebSettings.getDefaultUserAgent(context)
            userAgentString =
              defaultUa.replace("; wv", "").replace(Regex("Version/\\d+\\.\\d+\\s*"), "")
          }

          addJavascriptInterface(
            object {
              @JavascriptInterface
              fun onRetrieveVisitorData(newVisitorData: String?) {
                if (!newVisitorData.isNullOrBlank()) {
                  visitorData = newVisitorData
                }
              }

              @JavascriptInterface
              fun onRetrieveDataSyncId(newDataSyncId: String?) {
                if (!newDataSyncId.isNullOrBlank()) {
                  dataSyncId = newDataSyncId.substringBefore("||")
                }
              }
            },
            "Android",
          )
          webView = this

          val cookieManager = CookieManager.getInstance()
          cookieManager.setAcceptCookie(true)
          cookieManager.setAcceptThirdPartyCookies(this, true)
          cookieManager.removeAllCookies {
            cookieManager.flush()
            loadUrl("https://accounts.google.com/ServiceLogin?continue=https%3A%2F%2Fmusic.youtube.com")
          }
        }
      },
    )
  }

  BackHandler(enabled = webView?.canGoBack() == true) { webView?.goBack() }
}
