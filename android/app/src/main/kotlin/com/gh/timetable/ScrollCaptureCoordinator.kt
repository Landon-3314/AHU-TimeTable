package com.gh.timetable

import android.graphics.Rect
import android.graphics.RectF
import android.os.Build
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.MotionEvent
import android.view.ScrollCaptureCallback
import android.view.ScrollCaptureSession
import android.view.TextureView
import android.view.View
import android.view.View.AccessibilityDelegate
import android.view.ViewGroup
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.FrameLayout
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterView
import io.flutter.plugin.common.MethodChannel
import java.util.function.Consumer
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

private const val SCROLL_CAPTURE_DIAG_TAG = "ScrollCaptureDiag"
private const val ENABLE_SCROLL_CAPTURE_OVERLAY_DIAGNOSTICS = false

class ScrollCaptureCoordinator(
    private val activity: FlutterActivity,
    private val channelProvider: () -> MethodChannel?,
) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var didInstallScrollCaptureCallback = false
    private var activeScrollCaptureCallback: ScrollCaptureCallback? = null
    private var overlayRecyclerView: RecyclerView? = null
    private var overlayAdapter: OverlayPlaceholderAdapter? = null
    private var overlayActiveScrollableId: String? = null
    private var isSyncingOverlayPosition = false
    private val overlayHideRunnable = Runnable {
        setOverlayVisible(false)
    }

    fun onResume() {
        mainHandler.post { installScrollCaptureCallbackIfNeeded() }
        if (ENABLE_SCROLL_CAPTURE_OVERLAY_DIAGNOSTICS) {
            setupScrollOverlayIfNeeded()
            refreshOverlayScrollable()
        }
    }

    fun onWindowFocusChanged(hasFocus: Boolean) {
        if (hasFocus && ENABLE_SCROLL_CAPTURE_OVERLAY_DIAGNOSTICS) {
            refreshOverlayScrollable()
        }
    }

    fun handleTouchEvent(event: MotionEvent) {
        when (event.actionMasked) {
            MotionEvent.ACTION_UP,
            MotionEvent.ACTION_CANCEL,
            MotionEvent.ACTION_POINTER_UP -> setOverlayVisible(false)
        }
    }

    fun onPause() {
        setOverlayVisible(false)
    }

    fun onDestroy() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            activeScrollCaptureCallback?.let { callback ->
                clearScrollCaptureCallbackSafely(findFlutterView(activity.window.decorView))
                unregisterScrollCaptureCallbackSafely(callback)
            }
        }
        activeScrollCaptureCallback = null
    }

    private fun installScrollCaptureCallbackIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            scrollCaptureLog("skip install sdk=${Build.VERSION.SDK_INT}")
            return
        }
        if (didInstallScrollCaptureCallback) {
            return
        }

        val decorView = activity.window.decorView
        if (!decorView.isAttachedToWindow) {
            scrollCaptureLog("install deferred decor not attached")
            decorView.addOnAttachStateChangeListener(
                object : View.OnAttachStateChangeListener {
                    override fun onViewAttachedToWindow(view: View) {
                        view.removeOnAttachStateChangeListener(this)
                        mainHandler.post { installScrollCaptureCallbackIfNeeded() }
                    }

                    override fun onViewDetachedFromWindow(view: View) {
                        view.removeOnAttachStateChangeListener(this)
                    }
                },
            )
            return
        }

        val flutterView =
            findFlutterView(decorView)
                ?: run {
                    scrollCaptureLog("install skipped missing FlutterView")
                    return
                }
        try {
            val callback = FlutterScrollCaptureCallback(flutterView)
            flutterView.scrollCaptureHint = View.SCROLL_CAPTURE_HINT_INCLUDE
            flutterView.setScrollCaptureCallback(callback)
            activity.window.registerScrollCaptureCallback(callback)
            activeScrollCaptureCallback = callback
            didInstallScrollCaptureCallback = true
            scrollCaptureLog(
                "installed view=${flutterView.width}x${flutterView.height} " +
                    "density=${activity.resources.displayMetrics.density}",
            )
        } catch (error: Throwable) {
            clearScrollCaptureCallbackSafely(flutterView)
            activeScrollCaptureCallback = null
            didInstallScrollCaptureCallback = false
            Log.w(
                SCROLL_CAPTURE_DIAG_TAG,
                "Failed to install scroll capture callback: ${error.message}",
                error,
            )
        }
    }

    @androidx.annotation.RequiresApi(Build.VERSION_CODES.S)
    private fun clearScrollCaptureCallbackSafely(flutterView: FlutterView?) {
        if (flutterView == null) {
            return
        }
        try {
            flutterView.setScrollCaptureCallback(null)
        } catch (error: Throwable) {
            scrollCaptureLog(
                "clear callback failed ${error.javaClass.simpleName}: ${error.message}",
            )
        }
    }

    @androidx.annotation.RequiresApi(Build.VERSION_CODES.S)
    private fun unregisterScrollCaptureCallbackSafely(callback: ScrollCaptureCallback) {
        try {
            activity.window.unregisterScrollCaptureCallback(callback)
        } catch (error: Throwable) {
            scrollCaptureLog(
                "unregister failed ${error.javaClass.simpleName}: ${error.message}",
            )
        }
    }

    private fun invokeFlutterMethod(
        method: String,
        arguments: Any? = null,
        onSuccess: (Any?) -> Unit,
        onFailure: () -> Unit,
    ) {
        val channel = channelProvider()
        if (channel == null) {
            onFailure()
            return
        }

        mainHandler.post {
            channel.invokeMethod(
                method,
                arguments,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        onSuccess(result)
                    }

                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        onFailure()
                    }

                    override fun notImplemented() {
                        onFailure()
                    }
                },
            )
        }
    }

    private fun findFlutterView(view: View): FlutterView? {
        if (view is FlutterView) {
            return view
        }
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                val child = view.getChildAt(index)
                val match = findFlutterView(child)
                if (match != null) {
                    return match
                }
            }
        }
        return null
    }

    private fun scrollCaptureLog(message: String) {
        Log.d(SCROLL_CAPTURE_DIAG_TAG, "${System.currentTimeMillis()} $message")
    }

    private fun findTextureView(view: View): TextureView? {
        if (view is TextureView) {
            return view
        }
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                val child = view.getChildAt(index)
                val match = findTextureView(child)
                if (match != null) {
                    return match
                }
            }
        }
        return null
    }

    private fun setupScrollOverlayIfNeeded() {
        if (overlayRecyclerView != null) {
            return
        }
        val root = activity.window.decorView as? FrameLayout ?: return
        val screenHeight = activity.resources.displayMetrics.heightPixels
        val density = activity.resources.displayMetrics.density
        val adapter = OverlayPlaceholderAdapter(screenHeight * 5)
        val recyclerView = RecyclerView(activity).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            )
            alpha = 0f
            visibility = View.GONE
            layoutManager = LinearLayoutManager(context)
            this.adapter = adapter
            accessibilityDelegate = object : AccessibilityDelegate() {
                override fun onInitializeAccessibilityNodeInfo(
                    host: View,
                    info: AccessibilityNodeInfo,
                ) {
                    super.onInitializeAccessibilityNodeInfo(host, info)
                    info.className = "android.widget.ScrollView"
                    info.isScrollable = true
                    info.addAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_FORWARD)
                    info.addAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_BACKWARD)
                }
            }
            addOnScrollListener(
                object : RecyclerView.OnScrollListener() {
                    override fun onScrolled(rv: RecyclerView, dx: Int, dy: Int) {
                        if (isSyncingOverlayPosition) {
                            return
                        }
                        val id = overlayActiveScrollableId ?: return
                        val offsetDp = rv.computeVerticalScrollOffset() / density
                        invokeFlutterMethod(
                            method = "scrollTo",
                            arguments = mapOf("id" to id, "offset" to offsetDp.toDouble()),
                            onSuccess = {},
                            onFailure = {},
                        )
                    }
                },
            )
        }
        overlayRecyclerView = recyclerView
        overlayAdapter = adapter
        root.addView(recyclerView)
    }

    private fun setOverlayVisible(visible: Boolean) {
        val recyclerView = overlayRecyclerView ?: return
        if (visible) {
            if (recyclerView.visibility != View.VISIBLE) {
                recyclerView.visibility = View.VISIBLE
                recyclerView.bringToFront()
            }
            refreshOverlayScrollable()
            mainHandler.removeCallbacks(overlayHideRunnable)
            mainHandler.postDelayed(overlayHideRunnable, 12_000L)
        } else {
            recyclerView.visibility = View.GONE
            mainHandler.removeCallbacks(overlayHideRunnable)
        }
    }

    private fun updateOverlayHeight(maxScrollExtentDp: Double) {
        val adapter = overlayAdapter ?: return
        val density = activity.resources.displayMetrics.density
        val screenHeight = activity.resources.displayMetrics.heightPixels
        val totalPx = screenHeight + (maxScrollExtentDp * density).roundToInt()
        adapter.updateHeight(totalPx)
    }

    private fun syncOverlayToOffset(offsetDp: Double) {
        val recyclerView = overlayRecyclerView ?: return
        val density = activity.resources.displayMetrics.density
        val targetPx = (offsetDp * density).roundToInt()
        val currentPx = recyclerView.computeVerticalScrollOffset()
        val dy = targetPx - currentPx
        if (dy == 0) {
            return
        }
        isSyncingOverlayPosition = true
        try {
            recyclerView.scrollBy(0, dy)
        } finally {
            isSyncingOverlayPosition = false
        }
    }

    private fun refreshOverlayScrollable() {
        invokeFlutterMethod(
            method = "describeScrollables",
            onSuccess = { raw ->
                val flutterView = findFlutterView(activity.window.decorView)
                val bestScrollable = if (flutterView == null) null else chooseBestScrollable(raw, flutterView)
                overlayActiveScrollableId = bestScrollable?.id
                if (bestScrollable != null) {
                    updateOverlayHeight(bestScrollable.maxScrollExtent.toDouble())
                    syncOverlayToOffset(bestScrollable.pixels.toDouble())
                }
            },
            onFailure = {},
        )
    }

    private class OverlayPlaceholderAdapter(
        initialHeightPx: Int,
    ) : RecyclerView.Adapter<OverlayPlaceholderAdapter.OverlayViewHolder>() {
        private var itemHeightPx: Int = initialHeightPx

        class OverlayViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView)

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): OverlayViewHolder {
            val view = View(parent.context).apply {
                layoutParams = RecyclerView.LayoutParams(
                    RecyclerView.LayoutParams.MATCH_PARENT,
                    itemHeightPx,
                )
            }
            return OverlayViewHolder(view)
        }

        override fun onBindViewHolder(holder: OverlayViewHolder, position: Int) {
            val params =
                (holder.itemView.layoutParams as? RecyclerView.LayoutParams)
                    ?: RecyclerView.LayoutParams(
                        RecyclerView.LayoutParams.MATCH_PARENT,
                        itemHeightPx,
                    )
            if (params.height != itemHeightPx) {
                params.height = itemHeightPx
                holder.itemView.layoutParams = params
            }
        }

        override fun getItemCount(): Int = 1

        fun updateHeight(heightPx: Int) {
            if (heightPx <= 0 || heightPx == itemHeightPx) {
                return
            }
            itemHeightPx = heightPx
            notifyItemChanged(0)
        }
    }

    private fun parseScrollableTarget(raw: Any?): ScrollableTarget? {
        val map = raw as? Map<*, *> ?: return null
        val id = map["id"] as? String ?: return null
        val left = (map["left"] as? Number)?.toFloat() ?: return null
        val top = (map["top"] as? Number)?.toFloat() ?: return null
        val width = (map["width"] as? Number)?.toFloat() ?: return null
        val height = (map["height"] as? Number)?.toFloat() ?: return null
        val pixels = (map["pixels"] as? Number)?.toFloat() ?: return null
        val maxScrollExtent = (map["maxScrollExtent"] as? Number)?.toFloat() ?: return null
        val viewportDimension = (map["viewportDimension"] as? Number)?.toFloat() ?: return null
        val devicePixelRatio =
            ((map["devicePixelRatio"] as? Number)?.toFloat() ?: activity.resources.displayMetrics.density)
                .coerceAtLeast(1f)
        if (width <= 0f || height <= 0f || viewportDimension <= 0f) {
            return null
        }
        return ScrollableTarget(
            id = id,
            bounds = Rect(
                logicalToPhysical(left, devicePixelRatio),
                logicalToPhysical(top, devicePixelRatio),
                logicalToPhysical(left + width, devicePixelRatio),
                logicalToPhysical(top + height, devicePixelRatio),
            ),
            pixels = pixels,
            maxScrollExtent = maxScrollExtent,
            viewportDimension = viewportDimension,
            devicePixelRatio = devicePixelRatio,
        )
    }

    private fun chooseBestScrollable(raw: Any?, flutterView: FlutterView): ScrollableTarget? {
        val items = raw as? List<*> ?: return null
        var bestTarget: ScrollableTarget? = null
        var bestArea = 0
        val viewportBounds = Rect(0, 0, flutterView.width, flutterView.height)

        for (item in items) {
            val candidate = parseScrollableTarget(item) ?: continue
            if (candidate.maxScrollExtent <= 1f) {
                continue
            }

            val visibleBounds = Rect(candidate.bounds)
            if (!visibleBounds.intersect(viewportBounds)) {
                continue
            }

            val viewportDimensionPx =
                candidate.viewportDimension * candidate.devicePixelRatio
            val visibleHeight = min(visibleBounds.height().toFloat(), viewportDimensionPx)
                .roundToInt()
            if (visibleHeight <= 0) {
                continue
            }

            val adjusted = candidate.copy(
                bounds = Rect(
                    visibleBounds.left,
                    visibleBounds.top,
                    visibleBounds.right,
                    visibleBounds.top + visibleHeight,
                ),
            )
            val area = adjusted.bounds.width() * adjusted.bounds.height()
            if (area > bestArea) {
                bestArea = area
                bestTarget = adjusted
            }
        }

        return bestTarget
    }

    private fun logicalToPhysical(value: Float, devicePixelRatio: Float): Int {
        return (value * devicePixelRatio).roundToInt()
    }

    private fun parseScrollResult(raw: Any?): ScrollMetricsSnapshot? {
        val map = raw as? Map<*, *> ?: return null
        val ok = map["ok"] as? Boolean ?: false
        if (!ok) {
            return null
        }
        val pixels = (map["pixels"] as? Number)?.toFloat() ?: return null
        val maxScrollExtent = (map["maxScrollExtent"] as? Number)?.toFloat() ?: return null
        val viewportDimension = (map["viewportDimension"] as? Number)?.toFloat() ?: return null
        return ScrollMetricsSnapshot(
            pixels = pixels,
            maxScrollExtent = maxScrollExtent,
            viewportDimension = viewportDimension,
        )
    }

    private data class ScrollableTarget(
        val id: String,
        val bounds: Rect,
        val pixels: Float,
        val maxScrollExtent: Float,
        val viewportDimension: Float,
        val devicePixelRatio: Float,
    )

    private data class ScrollMetricsSnapshot(
        val pixels: Float,
        val maxScrollExtent: Float,
        val viewportDimension: Float,
    )

    private data class ActiveCaptureState(
        val id: String,
        val bounds: Rect,
        val startPixels: Float,
        var maxScrollExtent: Float,
        var viewportDimension: Float,
        val devicePixelRatio: Float,
    )

    @androidx.annotation.RequiresApi(Build.VERSION_CODES.S)
    private inner class FlutterScrollCaptureCallback(
        private val flutterView: FlutterView,
        ) : ScrollCaptureCallback {
        private var activeCaptureState: ActiveCaptureState? = null

        override fun onScrollCaptureSearch(
            cancellationSignal: CancellationSignal,
            onReady: Consumer<Rect>,
        ) {
            scrollCaptureLog("search start")
            invokeFlutterMethod(
                method = "describeScrollables",
                onSuccess = { raw ->
                    if (cancellationSignal.isCanceled) {
                        scrollCaptureLog("search canceled before target selection")
                        onReady.accept(Rect())
                        return@invokeFlutterMethod
                    }

                    val count = (raw as? List<*>)?.size ?: -1
                    val target = chooseBestScrollable(raw, flutterView)
                    activeCaptureState =
                        target?.let {
                            ActiveCaptureState(
                                id = it.id,
                                bounds = Rect(it.bounds),
                                startPixels = it.pixels,
                                maxScrollExtent = it.maxScrollExtent,
                                viewportDimension = it.viewportDimension,
                                devicePixelRatio = it.devicePixelRatio,
                            )
                        }
                    if (target == null) {
                        scrollCaptureLog("search empty rawCount=$count")
                    } else {
                        scrollCaptureLog(
                            "search target id=${target.id} rawCount=$count " +
                                "bounds=${target.bounds} pixels=${target.pixels} " +
                                "max=${target.maxScrollExtent} viewport=${target.viewportDimension} " +
                                "dpr=${target.devicePixelRatio}",
                        )
                    }
                    onReady.accept(target?.bounds ?: Rect())
                },
                onFailure = {
                    activeCaptureState = null
                    scrollCaptureLog("search failed channel")
                    onReady.accept(Rect())
                },
            )
        }

        override fun onScrollCaptureStart(
            session: ScrollCaptureSession,
            cancellationSignal: CancellationSignal,
            onReady: Runnable,
        ) {
            val state = activeCaptureState
            if (state == null || cancellationSignal.isCanceled) {
                scrollCaptureLog("start without active state canceled=${cancellationSignal.isCanceled}")
                onReady.run()
                return
            }

            invokeFlutterMethod(
                method = "prepareCapture",
                arguments = mapOf("id" to state.id),
                onSuccess = {
                    scrollCaptureLog("start prepared id=${state.id}")
                    onReady.run()
                },
                onFailure = {
                    scrollCaptureLog("start prepare failed id=${state.id}")
                    onReady.run()
                },
            )
        }

        override fun onScrollCaptureImageRequest(
            session: ScrollCaptureSession,
            cancellationSignal: CancellationSignal,
            captureArea: Rect,
            onComplete: Consumer<Rect>,
        ) {
            val state = activeCaptureState
            if (state == null || captureArea.isEmpty || cancellationSignal.isCanceled) {
                scrollCaptureLog(
                    "image request skipped state=${state != null} area=$captureArea " +
                        "canceled=${cancellationSignal.isCanceled}",
                )
                onComplete.accept(Rect())
                return
            }

            val targetPixels =
                (state.startPixels + captureArea.top / state.devicePixelRatio)
                    .coerceIn(0f, state.maxScrollExtent)
            scrollCaptureLog(
                "image request id=${state.id} area=$captureArea target=$targetPixels " +
                    "start=${state.startPixels} dpr=${state.devicePixelRatio}",
            )
            invokeFlutterMethod(
                method = "scrollTo",
                arguments = mapOf("id" to state.id, "offset" to targetPixels),
                onSuccess = { raw ->
                    if (cancellationSignal.isCanceled) {
                        scrollCaptureLog("image request canceled after scroll")
                        onComplete.accept(Rect())
                        return@invokeFlutterMethod
                    }

                    val scrollMetrics = parseScrollResult(raw)
                    if (scrollMetrics == null) {
                        scrollCaptureLog("image request invalid scroll result raw=$raw")
                        onComplete.accept(Rect())
                        return@invokeFlutterMethod
                    }

                    state.maxScrollExtent = scrollMetrics.maxScrollExtent
                    state.viewportDimension = scrollMetrics.viewportDimension
                    val captured = captureBitmapIntoSession(
                        session = session,
                        captureArea = captureArea,
                        state = state,
                        currentPixels = scrollMetrics.pixels,
                    )
                    scrollCaptureLog("image request complete captured=${captured ?: Rect()}")
                    onComplete.accept(captured ?: Rect())
                },
                onFailure = {
                    scrollCaptureLog("image request scrollTo failed")
                    onComplete.accept(Rect())
                },
            )
        }

        override fun onScrollCaptureEnd(onReady: Runnable) {
            val state = activeCaptureState
            activeCaptureState = null
            if (state == null) {
                scrollCaptureLog("end without active state")
                onReady.run()
                return
            }

            invokeFlutterMethod(
                method = "restoreCapture",
                arguments = mapOf("id" to state.id),
                onSuccess = {
                    scrollCaptureLog("end restored id=${state.id}")
                    onReady.run()
                },
                onFailure = {
                    scrollCaptureLog("end restore failed id=${state.id}")
                    onReady.run()
                },
            )
        }

        private fun captureBitmapIntoSession(
            session: ScrollCaptureSession,
            captureArea: Rect,
            state: ActiveCaptureState,
            currentPixels: Float,
        ): Rect? {
            val textureView =
                findTextureView(flutterView)
                    ?: run {
                        scrollCaptureLog("capture failed missing TextureView")
                        return null
                    }
            val bitmap =
                textureView.bitmap
                    ?: run {
                        scrollCaptureLog("capture failed null TextureView bitmap")
                        return null
                    }

            return try {
                val scrollDelta = (currentPixels - state.startPixels) * state.devicePixelRatio
                val visibleLocalTop = max(0f, captureArea.top - scrollDelta)
                val visibleLocalBottom = min(
                    state.bounds.height().toFloat(),
                    captureArea.bottom - scrollDelta,
                )
                if (visibleLocalBottom <= visibleLocalTop) {
                    scrollCaptureLog(
                        "capture failed invisible area=$captureArea scrollDelta=$scrollDelta " +
                            "bounds=${state.bounds}",
                    )
                    return null
                }

                val availableTop = (visibleLocalTop + scrollDelta).roundToInt()
                val availableBottom = (visibleLocalBottom + scrollDelta).roundToInt()
                val availableRect = Rect(
                    captureArea.left,
                    availableTop,
                    captureArea.right,
                    availableBottom,
                )

                val sourceRect = Rect(
                    state.bounds.left + captureArea.left,
                    state.bounds.top + visibleLocalTop.roundToInt(),
                    state.bounds.left + captureArea.right,
                    state.bounds.top + visibleLocalBottom.roundToInt(),
                )
                sourceRect.intersect(0, 0, bitmap.width, bitmap.height)
                if (sourceRect.isEmpty) {
                    scrollCaptureLog(
                        "capture failed empty source area=$captureArea source=$sourceRect " +
                            "bitmap=${bitmap.width}x${bitmap.height}",
                    )
                    return null
                }

                val canvas = session.surface.lockCanvas(availableRect)
                try {
                    canvas.drawBitmap(bitmap, sourceRect, RectF(availableRect), null)
                } finally {
                    session.surface.unlockCanvasAndPost(canvas)
                }
                availableRect
            } catch (error: Throwable) {
                scrollCaptureLog("capture failed ${error.javaClass.simpleName}: ${error.message}")
                null
            } finally {
                bitmap.recycle()
            }
        }
    }
}
