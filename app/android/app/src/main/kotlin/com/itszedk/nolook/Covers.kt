package com.itszedk.nolook

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Covers matching posts in any app. Can't blur other apps on android so it's a solid cover
 * with the hidden pill + Show.
 *
 * Cover passes touches through so scrolling works, only the pill (own window) takes taps.
 */
class Covers(private val service: AccessibilityService) {
    private val wm = service.getSystemService(WindowManager::class.java)
    private val main = Handler(Looper.getMainLooper())
    private val shown = mutableMapOf<String, Shown>()
    private val revealed = mutableSetOf<String>()
    private val reported = mutableSetOf<String>()
    private val skipped = mutableSetOf<String>()
    private var lastSkip = 0L

    companion object {
        /** full screen video feeds, matches get swiped past instead of covered */
        val videoFeeds = setOf(
            "com.zhiliaoapp.musically", "com.ss.android.ugc.trill", // TikTok
            "com.instagram.android", // Reels
            "com.google.android.youtube", // Shorts
            "com.facebook.katana", // Facebook reels
            "com.snapchat.android", // Spotlight
        )
    }
    private var pkg = ""
    private var lastEventPkg = ""
    private var scanQueued = false

    private class Shown(val cover: View, val coverLp: WindowManager.LayoutParams, val pill: View, val pillLp: WindowManager.LayoutParams, var rect: Rect)

    private fun dp(v: Float) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, service.resources.displayMetrics)

    fun onEvent(event: AccessibilityEvent, pkg: String) {
        if (pkg != lastEventPkg) {
            // app changed, drop old covers
            if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) clear()
            lastEventPkg = pkg
        }
        if (!Rules.anyWords) {
            clear()
            return
        }
        // scroll = rescan fast, everything else can wait
        val delay = if (event.eventType == AccessibilityEvent.TYPE_VIEW_SCROLLED) 30L else 140L
        if (scanQueued) return
        scanQueued = true
        main.postDelayed({
            scanQueued = false
            scan()
        }, delay)
    }

    /** queue a rescan */
    fun recheck() {
        if (scanQueued) return
        scanQueued = true
        main.postDelayed({
            scanQueued = false
            scan()
        }, 140L)
    }

    fun clear() {
        for (k in shown.keys.toList()) remove(k)
    }

    private fun remove(key: String) {
        val s = shown.remove(key) ?: return
        runCatching { wm.removeView(s.cover) }
        runCatching { wm.removeView(s.pill) }
    }

    private data class Hit(val id: String, val rect: Rect, val block: RuleBlock, val matched: List<String>, val fullScreen: Boolean = false)

    private fun scan() {
        val root = service.rootInActiveWindow ?: return clear()
        // go by the front window not the event source (keyboard events), never cover our own screens
        val app = root.packageName?.toString() ?: return clear()
        if (app == service.packageName || app == "com.android.systemui") return clear()
        pkg = app

        val screen = service.resources.displayMetrics
        val hits = mutableListOf<Hit>()
        val stack = ArrayDeque<AccessibilityNodeInfo>().apply { add(root) }
        var seen = 0
        while (stack.isNotEmpty() && seen < 2000) {
            val n = stack.removeLast()
            seen++
            for (i in 0 until n.childCount) n.getChild(i)?.let { stack.add(it) }
            if (n.isEditable || !n.isVisibleToUser) continue
            val text = listOfNotNull(n.text?.toString(), n.contentDescription?.toString()).joinToString(" ")
            if (text.length < 3) continue
            val (block, matched) = Rules.blockForText(text) ?: continue
            val (box, list, fullScreen) = container(n, screen.heightPixels)
            val r = Rect().also { box.getBoundsInScreen(it) }
            // clip to the list so half scrolled posts don't cover the bars
            if (list != null && !r.intersect(list)) continue
            if (r.width() < dp(24f) || r.height() < dp(16f)) continue
            if (hits.any { Rect.intersects(it.rect, r) && (it.rect.contains(r) || r.contains(it.rect)) }) {
                // nested covers, keep the outer one
                hits.removeAll { r.contains(it.rect) }
                if (hits.any { it.rect.contains(r) }) continue
            }
            hits.add(Hit("$pkg|${text.hashCode()}", r, block, matched, fullScreen))
        }

        // video feeds: covering the caption doesn't stop the video, swipe to the next (once per video, no Show)
        if (pkg in videoFeeds) {
            val video = hits.firstOrNull { it.fullScreen && it.id !in revealed && it.id !in skipped }
            // only mark skipped once the swipe actually fired
            if (video != null && skipNext(video.rect)) skipped.add(video.id)
            if (skipped.size > 2000) skipped.clear()
        }

        // same text can show up twice, number the dupes
        val wanted = mutableMapOf<String, Hit>()
        for (h in hits.filter { it.id !in revealed }) {
            var k = h.id
            var i = 1
            while (k in wanted) k = "${h.id}#${i++}"
            wanted[k] = h
        }
        for (k in shown.keys - wanted.keys) remove(k)
        for ((k, hit) in wanted) {
            val s = shown[k]
            if (s == null) add(k, hit) else if (s.rect != hit.rect) move(s, hit.rect)
        }

        // report once per post
        val fresh = hits.filter { reported.add(it.id) }
        if (fresh.isNotEmpty()) {
            val label = runCatching { service.packageManager.getApplicationLabel(service.packageManager.getApplicationInfo(pkg, 0)).toString() }.getOrDefault(pkg)
            for ((block, group) in fresh.groupBy { it.block }) {
                NoLookEngine.send("covered", mapOf("blockId" to block.id, "app" to label, "matched" to group.flatMap { it.matched }.distinct(), "count" to group.size))
            }
            if (reported.size > 5000) reported.clear()
        }
    }

    /**
     * Walks up to the list item so the whole post gets covered, not just the line.
     */
    private fun container(node: AccessibilityNodeInfo, screenHeight: Int): Triple<AccessibilityNodeInfo, Rect?, Boolean> {
        // nearest list = post container. lists further up can still tell us it's a video feed
        // (shorts have small lists of their own under the video)
        var item = node
        var p = node.parent
        var depth = 0
        var post: AccessibilityNodeInfo? = null
        var postList: Rect? = null
        while (p != null && depth < 40) {
            // feeds don't always say scrollable, check the class too
            val cls = p.className?.toString() ?: ""
            if (p.isScrollable || p.collectionInfo != null || "RecyclerView" in cls || "ViewPager" in cls || cls.endsWith("ListView")) {
                val r = Rect().also { item.getBoundsInScreen(it) }
                val list = Rect().also { p.getBoundsInScreen(it) }
                // full screen feed: item ~= list size and the list fills most of the screen
                val full = list.height() >= screenHeight * .6 &&
                    r.height() >= list.height() * .9 && r.height() <= list.height() * 1.05 &&
                    r.width() >= list.width() * .9
                if (full) return Triple(node, postList ?: list, true)
                // only a nearby list decides the cover
                if (post == null && depth < 12) {
                    post = item
                    postList = list
                }
            }
            item = p
            p = p.parent
            depth++
        }
        return Triple(post ?: node, postList, false)
    }

    /**
     * Swipe to the next video, starting above the caption so it misses the Show button.
     * False if too soon after the last swipe.
     */
    private fun skipNext(caption: Rect): Boolean {
        val now = android.os.SystemClock.elapsedRealtime()
        if (now - lastSkip < 900) return false
        val m = service.resources.displayMetrics
        val startY = minOf(m.heightPixels * .62f, caption.top - dp(32f)).coerceAtLeast(m.heightPixels * .45f)
        val path = Path().apply {
            moveTo(m.widthPixels / 2f, startY)
            lineTo(m.widthPixels / 2f, startY - m.heightPixels * .4f)
        }
        val sent = service.dispatchGesture(GestureDescription.Builder().addStroke(GestureDescription.StrokeDescription(path, 0, 200)).build(), null, null)
        if (sent) lastSkip = now
        return sent
    }

    /** move cover + pill with the post */
    private fun move(s: Shown, r: Rect) {
        s.rect = r
        s.coverLp.x = r.left
        s.coverLp.y = r.top
        s.coverLp.width = r.width()
        s.coverLp.height = r.height()
        placePill(s.pill, s.pillLp, r)
        runCatching { wm.updateViewLayout(s.cover, s.coverLp) }
        runCatching { wm.updateViewLayout(s.pill, s.pillLp) }
    }

    private fun placePill(pill: View, lp: WindowManager.LayoutParams, r: Rect) {
        lp.x = r.centerX() - pill.measuredWidth / 2
        lp.y = r.centerY() - pill.measuredHeight / 2
    }

    private fun overlay(width: Int, height: Int, touchable: Boolean) = WindowManager.LayoutParams(
        width, height,
        WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
            (if (touchable) 0 else WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE),
        PixelFormat.TRANSLUCENT,
    ).apply { gravity = Gravity.TOP or Gravity.START }

    private fun add(key: String, hit: Hit) {
        val dark = (service.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        val surface = if (dark) Color.parseColor("#1D2024") else Color.parseColor("#ECEEF4")
        val pillBg = if (dark) Color.parseColor("#32353A") else Color.WHITE
        val ink = if (dark) Color.parseColor("#E2E2E9") else Color.parseColor("#191C20")
        val chipBg = if (dark) Color.parseColor("#3E4759") else Color.parseColor("#DAE2F9")
        val turkce = Rules.turkish

        val cover = View(service).apply {
            background = GradientDrawable().apply {
                setColor(surface)
                // small radius so thumbnail corners don't peek out
                cornerRadius = dp(4f)
            }
        }
        val compact = hit.rect.height() < dp(64f) || hit.rect.width() < dp(240f)
        // smaller pill for short boxes
        val tiny = hit.rect.height() < dp(52f)
        val pill = LinearLayout(service).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            val v = if (tiny) 2f else 8f
            setPadding(dp(if (tiny) 10f else 14f).toInt(), dp(v).toInt(), dp(if (tiny) 4f else 8f).toInt(), dp(v).toInt())
            background = GradientDrawable().apply {
                setColor(pillBg)
                cornerRadius = dp(999f)
            }
        }
        val label = TextView(service).apply {
            val what = if (turkce) "NoLook tarafından gizlendi" else "Hidden by NoLook"
            text = if (Rules.sayKeyword && !compact && hit.matched.isNotEmpty()) {
                what + (if (turkce) " · eşleşen: " else " · matched ") + hit.matched.first()
            } else {
                what
            }
            setTextColor(ink)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, if (tiny) 12f else 14f)
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            maxLines = 1
        }
        val canShow = !hit.block.hide
        // too narrow, button only
        val narrow = hit.rect.width() < dp(200f)
        if (!(narrow && canShow)) pill.addView(label)
        if (canShow) {
            val show = TextView(service).apply {
                text = if (turkce) "Göster" else "Show"
                setTextColor(ink)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, if (tiny) 12f else 13f)
                typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
                setPadding(dp(if (tiny) 8f else 12f).toInt(), dp(if (tiny) 1f else 4f).toInt(), dp(if (tiny) 8f else 12f).toInt(), dp(if (tiny) 1f else 4f).toInt())
                background = GradientDrawable().apply {
                    setColor(chipBg)
                    cornerRadius = dp(999f)
                }
                var armed = false
                setOnClickListener {
                    if (Rules.twoTapShow && !armed) {
                        armed = true
                        text = if (turkce) "Tekrar dokun" else "Tap again"
                        // recentre after it grew
                        shown[key]?.let { s ->
                            s.pill.measure(
                                View.MeasureSpec.makeMeasureSpec(maxOf(s.rect.width(), dp(120f).toInt()), View.MeasureSpec.AT_MOST),
                                View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
                            )
                            s.pillLp.width = s.pill.measuredWidth
                            s.pillLp.height = s.pill.measuredHeight
                            placePill(s.pill, s.pillLp, s.rect)
                            runCatching { wm.updateViewLayout(s.pill, s.pillLp) }
                        }
                        return@setOnClickListener
                    }
                    revealed.add(hit.id)
                    remove(key)
                }
            }
            if (narrow) pill.setPadding(dp(4f).toInt(), pill.paddingTop, dp(4f).toInt(), pill.paddingBottom)
            pill.addView(show, LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { leftMargin = if (narrow) 0 else dp(10f).toInt() })
        }
        // cap pill width to the post
        pill.measure(
            View.MeasureSpec.makeMeasureSpec(maxOf(hit.rect.width(), dp(120f).toInt()), View.MeasureSpec.AT_MOST),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
        )

        val coverLp = overlay(hit.rect.width(), hit.rect.height(), touchable = false).apply {
            x = hit.rect.left
            y = hit.rect.top
        }
        val pillLp = overlay(pill.measuredWidth, pill.measuredHeight, touchable = canShow)
        placePill(pill, pillLp, hit.rect)
        runCatching {
            wm.addView(cover, coverLp)
            wm.addView(pill, pillLp)
            shown[key] = Shown(cover, coverLp, pill, pillLp, Rect(hit.rect))
        }.onFailure {
            runCatching { wm.removeView(cover) }
        }
    }
}
