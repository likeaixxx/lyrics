//
//  API.swift
//  lyrics-v3
//
//  Created by 陈爱全 on 2024/5/15.
//

import Foundation
import Combine


let DOMAIN = "http://127.0.0.1:8331"
let LYRICS = DOMAIN + "/api/v1/lyrics"
let CONFIRM = DOMAIN + "/api/v1/lyrics/confirm"
let OFFSET = DOMAIN + "/api/v1/lyrics/offset"

let NET_WORK_ERROR = "☹️Network Error"
let NOTHING_FOUND = "☹️Nothing Found"
let INVALID = "☹️Invalid Track Name"

struct LyricAPI: Codable {
    let name: String?
    let singer: String?
    let id: String?
    let refresh: Bool?
}


struct ConfirmAPI: Codable {
    let item: LyricResponseItem
}

struct OffsetAPI: Codable {
    let sid: String
    let lid: String
    let offset: Int64?
}

extension LyricAPI {
    // 歌词
    func lyrics(success: @escaping ([LyricResponseItem]) -> Void, failure: @escaping (String) -> Void) {
        if self.name == nil {
            failure(INVALID)
            return
        }
        var request = URLRequest(url: URL(string: LYRICS)!)
        request.httpMethod = "POST"
        request.httpBody = try? JSONEncoder().encode(self)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let session = URLSession.shared
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                failure(error.localizedDescription)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data else {
                print("Server error or invalid response data")
                failure(NET_WORK_ERROR)
                return
            }
            
            do {
                let resp = try JSONDecoder().decode(LyricResponseBody.self, from: data)
                if let data = resp.data {
                    success(data)
                    return
                } else {
                    failure(NOTHING_FOUND)
                    return
                }
            } catch {
                print("Failed to decode data: \(error)")
                failure(NET_WORK_ERROR)
            }
        }
        task.resume()
    }
}

extension ConfirmAPI {
    func confirm(failure: @escaping (String) -> Void) {
        if let url = URL(string: CONFIRM) {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = try? JSONEncoder().encode(self.item)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let session = URLSession.shared
            let task = session.dataTask(with: request) { data, response, error in
                if error != nil {
                    failure(NET_WORK_ERROR)
                    return
                }
                return
            }
            task.resume()
        }
    }
}

extension OffsetAPI {
    func offset(failure: @escaping (String) -> Void) {
        if let url = URL(string: OFFSET) {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = try? JSONEncoder().encode(self)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let session = URLSession.shared
            let task = session.dataTask(with: request) { data, response, error in
                if error != nil {
                    failure(NET_WORK_ERROR)
                    return
                }
                return
            }
            task.resume()
        }
    }
}
