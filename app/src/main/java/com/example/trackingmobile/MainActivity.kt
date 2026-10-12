package com.example.trackingmobile

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import android.widget.*

class MainActivity : AppCompatActivity() {
    private lateinit var server: EditText; private lateinit var port: EditText; private lateinit var device: EditText
    private lateinit var interval: EditText; private lateinit var status: TextView
    override fun onCreate(state: Bundle?) { super.onCreate(state); setContentView(R.layout.activity_main)
        server=findViewById(R.id.server); port=findViewById(R.id.port); device=findViewById(R.id.deviceId); interval=findViewById(R.id.interval); status=findViewById(R.id.status)
        getPreferences(0).let { server.setText(it.getString("server", "")); device.setText(it.getString("device", "")); interval.setText(it.getString("interval", "15")) }
        findViewById<Button>(R.id.start).setOnClickListener { start() }; findViewById<Button>(R.id.stop).setOnClickListener { stop() }
    }
    private fun start() { if (device.text.isBlank() || server.text.isBlank()) { status.text="Status: isi server dan device ID"; return }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) { ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION), 9); return }
        getPreferences(0).edit().putString("server",server.text.toString()).putString("device",device.text.toString()).putString("interval",interval.text.toString()).apply()
        val i=Intent(this, LocationService::class.java).apply { putExtra("server",server.text.toString()); putExtra("port",port.text.toString().toIntOrNull()?:5055); putExtra("device",device.text.toString()); putExtra("interval",interval.text.toString().toLongOrNull()?:15) }
        ContextCompat.startForegroundService(this,i); status.text="Status: tracking aktif" }
    private fun stop() { stopService(Intent(this, LocationService::class.java)); status.text="Status: berhenti" }
}
