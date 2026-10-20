// SPDX-License-Identifier: Apache-2.0
/*
 The widget's errands, run by WorkManager so they finish even after the app and the tap are gone: asking each house
 about every quarter of an hour, and running Bedtime or Everything off. A tap's words stay until the refresh a
 quarter of an hour after it, which takes them away, as on iOS.
 */
package app.elyir.houses

import android.content.Context
import androidx.work.Data
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import java.util.concurrent.TimeUnit

object Work {
    private const val EVERY = "widget.every"
    private const val NOW = "widget.now"
    private const val AFTER_TAP = "widget.after-tap"

    fun refresh(context: Context) {
        val work = WorkManager.getInstance(context)
        work.enqueueUniquePeriodicWork(
            EVERY, ExistingPeriodicWorkPolicy.KEEP,
            PeriodicWorkRequestBuilder<Refresh>(Face.REFRESH_MILLIS, TimeUnit.MILLISECONDS).build(),
        )
        work.enqueueUniqueWork(NOW, ExistingWorkPolicy.REPLACE, OneTimeWorkRequestBuilder<Refresh>().build())
    }

    fun run(context: Context, house: String, scene: HouseScene) {
        val work = WorkManager.getInstance(context)
        work.enqueue(OneTimeWorkRequestBuilder<RunScene>().setInputData(workDataOf(HOUSE to house, SCENE to scene.name)).build())
        work.enqueueUniqueWork(
            AFTER_TAP, ExistingWorkPolicy.REPLACE,
            OneTimeWorkRequestBuilder<Refresh>().setInitialDelay(Face.REFRESH_MILLIS, TimeUnit.MILLISECONDS).build(),
        )
    }

    fun stop(context: Context) {
        val work = WorkManager.getInstance(context)
        listOf(EVERY, NOW, AFTER_TAP).forEach(work::cancelUniqueWork)
    }

    /** Asks every house a widget shows, once each, and draws what it said, or what was kept when it said nothing. */
    fun askAndDraw(context: Context, ids: IntArray = Widgets.all(context)) {
        val store = HouseStore.of(context)
        val now = System.currentTimeMillis()
        val asked = mutableMapOf<String, Glance?>()
        for (id in ids) {
            val house = store.house(id)
            val fresh = house?.let { h -> asked.getOrPut(h.id) { HouseClient.glance(h)?.also { store.keep(it, h.id, now) } } }
            Widgets.draw(context, id, Face.make(house, fresh, house?.let { store.kept(it.id) }, house?.let { store.tap(it.id) }, now))
        }
    }

    private const val HOUSE = "house"
    private const val SCENE = "scene"

    class Refresh(context: Context, params: WorkerParameters) : Worker(context, params) {
        override fun doWork(): Result {
            if (Widgets.all(applicationContext).isNotEmpty()) askAndDraw(applicationContext)
            return Result.success()
        }
    }

    class RunScene(context: Context, params: WorkerParameters) : Worker(context, params) {
        override fun doWork(): Result {
            val input: Data = inputData
            val id = input.getString(HOUSE) ?: return Result.failure()
            val scene = HouseScene.entries.firstOrNull { it.name == input.getString(SCENE) } ?: return Result.failure()
            val store = HouseStore.of(applicationContext)
            val ok = store.houses().firstOrNull { it.id == id }?.let { HouseClient.run(scene, it) } ?: false
            store.keep(Tap(id, scene, ok, System.currentTimeMillis()))
            Widgets.drawKept(applicationContext)
            askAndDraw(applicationContext)
            return Result.success()
        }
    }
}
