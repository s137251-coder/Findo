package com.findo.game

import android.os.Bundle
import com.google.android.gms.games.PlayGamesSdk
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Play Games v2 has to be initialised before anything asks it to sign
        // the player in, and the plugin does not do it.
        PlayGamesSdk.initialize(this)
        super.onCreate(savedInstanceState)
    }
}
