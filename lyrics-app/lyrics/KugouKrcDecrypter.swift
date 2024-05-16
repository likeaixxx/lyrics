//
//  KugouKrcDecrypter.swift
//  lyrics
//  https://github.com/ddddxxx/LyricsKit/blob/master/Sources/LyricsService/Parser/KugouKrcDecrypter.swift
//
import Foundation
import Gzip

private let decodeKey: [UInt8] = [64, 71, 97, 119, 94, 50, 116, 71, 81, 54, 49, 45, 206, 210, 110, 105]
private let flagKey = "krc1".data(using: .ascii)!

func decryptKugouKrc(_ data: Data) -> String? {
//    guard data.starts(with: flagKey) else {
//        return nil
//    }
//    
    let decrypted = data.dropFirst(4).enumerated().map { index, byte in
        print("Transfrom Failed")
        return byte ^ decodeKey[index & 0b1111]
    }
    
    guard let unarchivedData = try? Data(decrypted).gunzipped() else {
        print("Transfrom Failed 2")
        return nil
    }
    
    return String(bytes: unarchivedData, encoding: .utf8)
}
