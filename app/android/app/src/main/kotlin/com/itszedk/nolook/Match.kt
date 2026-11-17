package com.itszedk.nolook

import java.net.URI
import java.util.regex.Pattern

// same matching as core/lib/src/match.dart and extension/src/match.ts

/** blocked site rule */
class SiteRule private constructor(val text: String, val host: String, val path: String) {
    companion object {
        private val scheme = Regex("^[a-zA-Z][a-zA-Z0-9+.-]*://")
        private val www = Regex("^www\\.", RegexOption.IGNORE_CASE)
        private val hostPattern = Regex("^[a-z0-9-]+(\\.[a-z0-9-]+)+(:\\d+)?$")

        /** normalise input, null if not a site */
        fun normalize(input: String): String? {
            var s = input.trim()
            s = s.replaceFirst(scheme, "").replaceFirst(www, "").replaceFirst(Regex("#.*$"), "")
            while (s.endsWith("/")) s = s.dropLast(1)
            if (s.isEmpty() || s.contains(' ')) return null
            val slash = s.indexOfFirst { it == '/' || it == '?' }
            val host = (if (slash == -1) s else s.substring(0, slash)).lowercase()
            if (!hostPattern.matches(host)) return null
            return host + if (slash == -1) "" else s.substring(slash)
        }

        fun parse(input: String): SiteRule? {
            val text = normalize(input) ?: return null
            val slash = text.indexOfFirst { it == '/' || it == '?' }
            val host = if (slash == -1) text else text.substring(0, slash)
            var path = if (slash == -1) "" else text.substring(slash).lowercase()
            if (path.startsWith("?")) path = "/$path"
            return SiteRule(text, host, path)
        }
    }

    /** url can be scheme-less (address bar) */
    fun matchesUrl(url: String): Boolean {
        val withScheme = if (scheme.containsMatchIn(url)) url.trim() else "https://${url.trim()}"
        val uri = try { URI(withScheme.replace(" ", "%20")) } catch (_: Exception) { return false }
        val h = (uri.host ?: return false).lowercase()
        val hostOnly = host.substringBefore(':')
        if (h != hostOnly && !h.endsWith(".$hostOnly")) return false
        if (path.isEmpty()) return true
        var full = (uri.rawPath.takeUnless { it.isNullOrEmpty() } ?: "/").lowercase()
        if (uri.rawQuery != null) full += "?" + uri.rawQuery.lowercase()
        if (!full.startsWith(path)) return false
        if (path.contains('?') || full.length == path.length) return true
        return "/?#".contains(full[path.length])
    }
}

/** port of dart KeywordMatcher */
class KeywordMatcher(keywords: Iterable<String>) {
    private val entries: List<Pair<String, Pattern>> = keywords.map { it.trim() }.filter { it.isNotEmpty() }.distinct().map {
        it to Pattern.compile(patternFor(it), Pattern.CASE_INSENSITIVE or Pattern.UNICODE_CASE)
    }

    val isEmpty get() = entries.isEmpty()

    companion object {
        private val special = Regex("[\\\\^$.|?*+()\\[\\]{}]")

        private val dotted = mapOf("i" to "[iİ]", "I" to "[Iı]", "ı" to "[ıI]", "İ" to "[İi]")

        fun patternFor(keyword: String): String {
            var k = keyword.trim().replace('’', '\'')
            // "final*": Türkçe ekli halleri de yakala (finali, finalde)
            val bare = k.replace(Regex("\\*+$"), "")
            val stem = bare != k && bare.isNotBlank()
            if (stem) k = bare
            val parts = k.split(Regex("[\\s\\-_]+")).filter { it.isNotEmpty() }.map { p ->
                p.replace(special) { "\\" + it.value }.replace(Regex("[iIıİ]")) { dotted.getValue(it.value) }.replace("'", "['’]")
            }
            return "(?<![\\p{L}\\p{N}])" + parts.joinToString("[\\s\\-_.]*") + (if (stem) "" else "(?:['’]s|s|es)?(?![\\p{L}\\p{N}])")
        }
    }

    fun find(text: String): List<String> = entries.filter { it.second.matcher(text).find() }.map { it.first }

    fun any(text: String): Boolean = entries.any { it.second.matcher(text).find() }
}

/** keywords always, spoiler words only with a topic word/keyword */
class BlockMatcher(keywords: Iterable<String>, spoilerWords: Iterable<String>, topicWords: Iterable<String>) {
    private val keywords = KeywordMatcher(keywords)
    private val spoilers = KeywordMatcher(spoilerWords)
    private val topics = KeywordMatcher(topicWords)

    val isEmpty get() = keywords.isEmpty && spoilers.isEmpty

    fun find(text: String): List<String> {
        val k = keywords.find(text)
        val s = spoilers.find(text)
        if (s.isEmpty()) return k
        if (k.isEmpty() && !topics.any(text)) return k
        return k + s
    }
}
