package com.findo.game

import android.os.Build
import android.os.Bundle
import com.google.android.gms.games.PlayGamesSdk
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Play Games v2 has to be initialised before anything asks it to sign
        // the player in, and the plugin does not do it.
        PlayGamesSdk.initialize(this)
        super.onCreate(savedInstanceState)
        askForSixtyHertz()
    }

    /**
     * Asks the screen to run at 60Hz while the game is up.
     *
     * A phone with a 120Hz screen draws this game 120 times a second: the map,
     * the drift over it and the panel on top, all redrawn twice as often as
     * anything here changes. Nothing in a hidden object game moves fast enough
     * to need it -- the drift is a slow fall, the map only moves when a finger
     * moves it -- and testers playing for ten minutes reported the phone
     * getting hot. Half the frames is half that work.
     *
     * It is a request. A device that will not change modes simply keeps its
     * own, and the game runs exactly as it did before.
     */
    private fun askForSixtyHertz() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return
        }
        val modes = display?.supportedModes ?: return
        val current = display?.mode ?: return
        // Only among modes of the same size: a mode with a different
        // resolution would change how sharp everything is to save power, which
        // is not the trade being made here.
        val sixty = modes
            .filter {
                it.physicalWidth == current.physicalWidth &&
                    it.physicalHeight == current.physicalHeight &&
                    it.refreshRate >= 58f && it.refreshRate <= 62f
            }
            .minByOrNull { it.refreshRate }
            ?: return
        if (current.refreshRate <= 62f) {
            return
        }
        window.attributes = window.attributes.apply {
            preferredDisplayModeId = sixty.modeId
        }
    }
}
