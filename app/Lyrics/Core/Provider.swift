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
            print("Not Get Spotify Proxy")
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
        print("verify next")
        
        guard let spotify = self.spotify,
              let _ = spotify.currentTrack?.name,
              spotify.playerState == .playing else {
            print("NOT Playing \(spotify?.playerState ?? .unknown)")
            return nil
        }
        
        guard let currentTrack = self.spotify?.currentTrack else {
            print("Not Get Current Track")
            return nil
        }
        let id = currentTrack.id?()
        print("Current Track Id \(id ?? "")")
        if  id != currentTrackID {
            print("Current Track Id \(id ?? "") and Cached Id \(currentTrackID ?? "")")
            return currentTrack
        }
        print("Current Track Id ... and Cached Id \(currentTrackID ?? "")")
        return nil
    }
}
