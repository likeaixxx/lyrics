//
//  Provider.swift
//  lyrics-v3
//
//  Created by 陈爱全 on 2024/5/16.
//
import Foundation
import ScriptingBridge

class Provider {
    static let shared = Provider()
    var spotify: SpotifyApplication? = {
        guard let app = SBApplication(bundleIdentifier: "com.spotify.client") else {
            return nil
        }
        return app
    }()
    

    func playing() -> Bool {
        guard let spotify = self.spotify,
              let _ = spotify.currentTrack?.name,
              spotify.playerState == .playing else {
            return false
        }
        return true
    }
    
    func next(currentTrackID: String?)-> SpotifyTrack? {
        if let currentTrack = self.spotify?.currentTrack, currentTrack.id?() != currentTrackID {
            return currentTrack
        }
        return nil
    }
}
