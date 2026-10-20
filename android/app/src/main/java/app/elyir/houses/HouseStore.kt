// SPDX-License-Identifier: Apache-2.0
/*
 Where the app leaves the houses for the widget. The list, with each house's pass, is sealed with a key the Android
 Keystore holds and never lets out, so the file alone reads as nothing; the key needs no unlock, so a widget can
 refresh on a locked phone, and backups are off for the whole app. What is not a secret (the house last opened, each
 house's last glance, a tap on a button, the house each widget was set to) sits beside it unsealed.
 */
package app.elyir.houses

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** A few strings by name: the app's private preferences, or a map in a test. */
interface Shelf {
    operator fun get(key: String): String?
    operator fun set(key: String, value: String?)
}

/** Seals the list before it is kept, and opens it again; null when it cannot. */
interface Seal {
    fun close(text: String): String?
    fun open(sealed: String): String?
}

class HouseStore(private val shelf: Shelf, private val seal: Seal) {
    fun houses(): List<HouseRecord> = HouseRecord.parseList(shelf[HOUSES]?.let(seal::open))

    /** Keeps the list the Houses app sent, and forgets everything about a house it no longer has. Whether anything changed. */
    fun save(list: List<HouseRecord>): Boolean {
        val before = houses()
        if (list == before) return false
        shelf[HOUSES] = seal.close(HouseRecord.listJson(list)) ?: return false
        val ids = list.map { it.id }.toSet()
        for (gone in before.map { it.id } - ids) {
            shelf[glanceKey(gone)] = null
            shelf[tapKey(gone)] = null
        }
        if (opened?.let { it !in ids } == true) opened = null
        return true
    }

    var opened: String?
        get() = shelf[OPENED]
        set(value) { shelf[OPENED] = value }

    fun kept(id: String): Kept? = Kept.parse(shelf[glanceKey(id)])
    fun keep(glance: Glance, id: String, now: Long = System.currentTimeMillis()) { shelf[glanceKey(id)] = Kept(glance, now).json() }

    fun tap(id: String): Tap? = Tap.parse(shelf[tapKey(id)])
    fun keep(tap: Tap) { shelf[tapKey(tap.id)] = tap.json() }

    /** The house a widget was set to when it was added. */
    fun picked(widget: Int): String? = shelf[pickKey(widget)]
    fun pick(widget: Int, id: String?) { shelf[pickKey(widget)] = id }

    /** The house a widget shows, worked out the same way every time. */
    fun house(widget: Int): HouseRecord? = Face.choose(houses(), picked(widget), opened)

    companion object {
        fun of(context: Context): HouseStore =
            HouseStore(PrefsShelf(context.applicationContext.getSharedPreferences("widget", Context.MODE_PRIVATE)), KeystoreSeal)

        private const val HOUSES = "houses"
        private const val OPENED = "opened"
        private fun glanceKey(id: String) = "glance.$id"
        private fun tapKey(id: String) = "tap.$id"
        private fun pickKey(widget: Int) = "widget.$widget"
    }
}

private class PrefsShelf(private val prefs: SharedPreferences) : Shelf {
    override fun get(key: String): String? = prefs.getString(key, null)
    override fun set(key: String, value: String?) {
        prefs.edit().apply { if (value == null) remove(key) else putString(key, value) }.apply()
    }
}

private object KeystoreSeal : Seal {
    private const val ALIAS = "houses.list"
    private const val GCM_TAG_BITS = 128

    override fun close(text: String): String? = try {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, key()) }
        Base64.encodeToString(cipher.iv + cipher.doFinal(text.toByteArray()), Base64.NO_WRAP)
    } catch (_: Exception) { null }

    override fun open(sealed: String): String? = try {
        val bytes = Base64.decode(sealed, Base64.NO_WRAP)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(GCM_TAG_BITS, bytes, 0, 12))
        String(cipher.doFinal(bytes, 12, bytes.size - 12))
    } catch (_: Exception) { null }

    @Synchronized
    private fun key(): SecretKey {
        val keys = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (keys.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(
                KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .build(),
            )
        }.generateKey()
    }
}
