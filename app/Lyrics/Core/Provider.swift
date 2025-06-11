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
            print("Failed to get Spotify proxy")
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
    
    func next(currentTrackID: String?) -> SpotifyTrack? {
        guard let spotify = self.spotify,
              let _ = spotify.currentTrack?.name,
              spotify.playerState == .playing else {
            print("Not playing \(spotify?.playerState ?? .unknown)")
            return nil
        }
        
        guard let currentTrack = spotify.currentTrack else {
            print("Failed to get current track")
            return nil
        }
        
        let id = currentTrack.id?()
        if id != currentTrackID {
            spotify.playpause?()
            spotify.play?()
            spotify.play?()
            spotify.play?()
            spotify.play?()
            spotify.play?()
            spotify.play?()
            spotify.play?()
            spotify.play?()
            return currentTrack
        }
        return nil
    }
}

