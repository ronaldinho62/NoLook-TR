package com.itszedk.nolook

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/** block as sent from dart (BrowserRules) */
class RuleBlock(
    val id: String,
    val name: String,
    val active: Boolean,
    val matcher: BlockMatcher,
    val sites: List<SiteRule>,
    /** package -> app name */
    val apps: Map<String, String>,
    val hide: Boolean,
)

/**
 * Current rules from dart. Saved to disk so blocking works after a reboot before dart is up.
 */
object Rules {
    @Volatile var blocks: List<RuleBlock> = emptyList()
        private set
    @Volatile var sayKeyword = true
        private set
    /** Show needs two taps */
    @Volatile var twoTapShow = false
        private set
    @Volatile var turkish = false
        private set

    private fun file(context: Context) = File(context.filesDir, "android_rules.json")

    fun update(context: Context, json: String) {
        if (parse(json)) file(context).writeText(json)
    }

    fun load(context: Context) {
        val f = file(context)
        if (blocks.isEmpty() && f.exists()) parse(f.readText())
    }

    private fun JSONArray?.strings(): List<String> = if (this == null) emptyList() else (0 until length()).map { getString(it) }

    private fun parse(json: String): Boolean = try {
        val root = JSONObject(json)
        root.optJSONObject("settings")?.let {
            sayKeyword = it.optBoolean("sayKeyword", true)
            twoTapShow = it.optBoolean("twoClickReveal", false)
            turkish = it.optString("lang") == "tr"
        }
        val list = root.optJSONArray("blocks") ?: JSONArray()
        blocks = (0 until list.length()).map { i ->
            val b = list.getJSONObject(i)
            val apps = mutableMapOf<String, String>()
            b.optJSONArray("apps")?.let { a ->
                for (j in 0 until a.length()) {
                    val app = a.getJSONObject(j)
                    for (id in app.optJSONArray("ids").strings()) apps[id.lowercase()] = app.optString("name")
                }
            }
            RuleBlock(
                id = b.optString("id"),
                name = b.optString("name"),
                active = b.optBoolean("active"),
                matcher = BlockMatcher(b.optJSONArray("keywords").strings(), b.optJSONArray("spoilerWords").strings(), b.optJSONArray("topicWords").strings()),
                sites = b.optJSONArray("sites").strings().mapNotNull { SiteRule.parse(it) },
                apps = apps,
                hide = b.optString("matchMode") == "hide",
            )
        }
        true
    } catch (e: Exception) {
        android.util.Log.w("NoLook", "Couldn't read the rules", e)
        false
    }

    /** active block for this app */
    fun blockForApp(pkg: String): RuleBlock? = blocks.firstOrNull { it.active && it.apps.containsKey(pkg.lowercase()) }

    /** active block for this url */
    fun blockForUrl(url: String): Pair<RuleBlock, SiteRule>? {
        for (b in blocks) {
            if (!b.active) continue
            b.sites.firstOrNull { it.matchesUrl(url) }?.let { return b to it }
        }
        return null
    }

    /** first matching block + matched words */
    fun blockForText(text: String): Pair<RuleBlock, List<String>>? {
        for (b in blocks) {
            if (!b.active || b.matcher.isEmpty) continue
            val m = b.matcher.find(text)
            if (m.isNotEmpty()) return b to m
        }
        return null
    }

    val anyWords get() = blocks.any { it.active && !it.matcher.isEmpty }
}
