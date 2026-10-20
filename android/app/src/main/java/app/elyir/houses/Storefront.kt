// SPDX-License-Identifier: Apache-2.0
/*
 Which Play country the phone buys in, asked once before the Houses app loads, so its first page already knows
 what the store allows (docs/apps.md, design/store-app/, C). A store that does not answer quickly, or a phone
 without Play, counts as unknown, and the app goes on without it.
 */
package app.elyir.houses

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.GetBillingConfigParams
import com.android.billingclient.api.PendingPurchasesParams

object Storefront {
    fun ask(context: Context, waitMillis: Long, answer: (String?) -> Unit) {
        val ui = Handler(Looper.getMainLooper())
        var answered = false
        val client = BillingClient.newBuilder(context)
            .setListener { _, _ -> }
            .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
            .build()
        fun give(country: String?) = ui.post {
            if (answered) return@post
            answered = true
            answer(country)
            try { client.endConnection() } catch (_: Exception) {}
        }
        ui.postDelayed({ give(null) }, waitMillis)
        try {
            client.startConnection(object : BillingClientStateListener {
                override fun onBillingSetupFinished(result: BillingResult) {
                    if (result.responseCode != BillingClient.BillingResponseCode.OK) { give(null); return }
                    client.getBillingConfigAsync(GetBillingConfigParams.newBuilder().build()) { config, billing ->
                        give(if (config.responseCode == BillingClient.BillingResponseCode.OK) billing?.countryCode else null)
                    }
                }
                override fun onBillingServiceDisconnected() { give(null) }
            })
        } catch (_: Exception) {
            give(null)
        }
    }
}
