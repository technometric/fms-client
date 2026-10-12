package com.example.trackingmobile

import android.app.*; import android.content.*; import android.location.Location; import android.os.*; import androidx.core.app.NotificationCompat; import com.google.android.gms.location.*; import java.net.HttpURLConnection; import java.net.URL; import java.net.URLEncoder

class LocationService : Service() {
    private lateinit var client: FusedLocationProviderClient; private var callback: LocationCallback?=null; private var server=""; private var port=5055; private var device=""; private var interval=15L
    override fun onCreate(){super.onCreate(); createChannel(); client=LocationServices.getFusedLocationProviderClient(this)}
    override fun onStartCommand(i:Intent?, flags:Int, id:Int):Int { server=i?.getStringExtra("server")?:server; port=i?.getIntExtra("port",5055)?:5055; device=i?.getStringExtra("device")?:device; interval=i?.getLongExtra("interval",15)?:15; startUpdates(); return START_STICKY }
    private fun startUpdates(){ startForeground(7, NotificationCompat.Builder(this,"tracking").setContentTitle("Tracking aktif").setContentText("Mengirim lokasi ke Traccar").setSmallIcon(android.R.drawable.ic_menu_mylocation).build()); val req=LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, interval.coerceAtLeast(5)*1000).setMinUpdateIntervalMillis(5000).build(); callback=object:LocationCallback(){override fun onLocationResult(r:LocationResult){r.lastLocation?.let{send(it)}}}; try{client.requestLocationUpdates(req,callback!!,Looper.getMainLooper())}catch(_:SecurityException){} }
    private fun send(l:Location){ Thread { try { val q="id=${URLEncoder.encode(device,"UTF-8")}&lat=${l.latitude}&lon=${l.longitude}&speed=${l.speed*3.6}&accuracy=${l.accuracy}&timestamp=${System.currentTimeMillis()/1000}"; val c=URL("http://$server:$port/?$q").openConnection() as HttpURLConnection; c.connectTimeout=10000;c.readTimeout=10000;c.requestMethod="GET";c.responseCode;c.disconnect() }catch(_:Exception){} }.start() }
    private fun createChannel(){ if(Build.VERSION.SDK_INT>=26)getSystemService(NotificationManager::class.java).createNotificationChannel(NotificationChannel("tracking","Tracking",NotificationManager.IMPORTANCE_LOW)) }
    override fun onDestroy(){callback?.let{client.removeLocationUpdates(it)};super.onDestroy()}; override fun onBind(i:Intent?)=null
}
