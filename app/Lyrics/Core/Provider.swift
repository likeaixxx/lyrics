//
//  Provider.swift
//
//  Created by likeai on 2024/5/16.
//
import Foundation
import ScriptingBridge

final class Provider {
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
              spotify.playerState == .playing,
              spotify.currentTrack?.name != nil else {
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
            while true {
                print("play play play")
                spotify.play?()
                if spotify.playerState == .playing {
                    break
                }
            }
            return currentTrack
        }
        return nil
    }
}
