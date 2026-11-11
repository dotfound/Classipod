package uk.dotfound.pixelpod

import android.app.Activity
import android.app.ActivityManager
import android.app.admin.DeviceAdminReceiver
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Device admin component; device owner is granted to it over adb. */
class PixelPodAdminReceiver : DeviceAdminReceiver()

/**
 * Makes PixelPod the whole phone when the app is device owner: lock task
 * mode with the status bar disabled, and a maintenance exit that opens
 * Android's Wi-Fi or Bluetooth settings. Does nothing when the app is not
 * device owner, so the same build still runs as an ordinary app.
 */
object PixelPodKiosk {
    private const val CHANNEL = "uk.dotfound.pixelpod/kiosk"

    private fun admin(context: Context) =
        ComponentName(context, PixelPodAdminReceiver::class.java)

    private fun policy(context: Context) =
        context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager

    fun isDeviceOwner(context: Context): Boolean =
        policy(context).isDeviceOwnerApp(context.packageName)

    /** Called on every resume, so a launch, Home press or reboot relocks. */
    fun lock(activity: Activity) {
        if (!isDeviceOwner(activity)) return
        val policy = policy(activity)
        val admin = admin(activity)
        try {
            policy.setLockTaskPackages(admin, arrayOf(activity.packageName))
            // Keep the power menu so the phone can still be switched off.
            policy.setLockTaskFeatures(
                admin,
                DevicePolicyManager.LOCK_TASK_FEATURE_GLOBAL_ACTIONS,
            )
            val home = IntentFilter(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                addCategory(Intent.CATEGORY_DEFAULT)
            }
            policy.addPersistentPreferredActivity(admin, home, activity.componentName)
            policy.setStatusBarDisabled(admin, true)
            val manager =
                activity.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            if (manager.lockTaskModeState == ActivityManager.LOCK_TASK_MODE_NONE) {
                activity.startLockTask()
            }
        } catch (error: Exception) {
            android.util.Log.w("PixelPodKiosk", "Could not lock: $error")
        }
    }

    /** Leaves lock task mode and opens a system settings screen. */
    private fun openMaintenance(activity: Activity, action: String) {
        if (isDeviceOwner(activity)) {
            try {
                activity.stopLockTask()
                policy(activity).setStatusBarDisabled(admin(activity), false)
            } catch (error: Exception) {
                android.util.Log.w("PixelPodKiosk", "Could not unlock: $error")
            }
        }
        activity.startActivity(Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    private fun setDockMode(context: Context, enabled: Boolean) {
        if (!isDeviceOwner(context)) return
        // 7 = stay on while plugged into AC, USB or wireless power.
        policy(context).setGlobalSetting(
            admin(context),
            Settings.Global.STAY_ON_WHILE_PLUGGED_IN,
            if (enabled) "7" else "0",
        )
    }

    fun attach(activity: Activity, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isDeviceOwner" -> result.success(isDeviceOwner(activity))
                    "openWifiSettings" -> {
                        openMaintenance(activity, Settings.ACTION_WIFI_SETTINGS)
                        result.success(null)
                    }
                    "openBluetoothSettings" -> {
                        openMaintenance(activity, Settings.ACTION_BLUETOOTH_SETTINGS)
                        result.success(null)
                    }
                    "setDockMode" -> {
                        setDockMode(activity, call.arguments == true)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
