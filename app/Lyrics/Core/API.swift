//
//  API.swift
//  lyrics-v3
//
//  Created by likeai on 2024/5/15.
//

import Foundation
import Combine


private let LYRICS = "/api/v1/lyrics"
private let CONFIRM = "/api/v1/lyrics/confirm"
private let OFFSET = "/api/v1/lyrics/offset"

private let NET_WORK_ERROR = "☹️Network Error"
private let NOTHING_FOUND = "☹️Nothing Found"
private let INVALID = "☹️Invalid Track Name"

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
    func lyrics(host: String, success: @escaping ([LyricResponseItem]) -> Void, failure: @escaping (String) -> Void) {
        guard self.name != nil else {
            failure(INVALID)
            return
        }
        var request = URLRequest(url: URL(string: host + LYRICS)!)
        request.httpMethod = "POST"
        request.httpBody = try? JSONEncoder().encode(self)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
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
    func confirm(host: String, failure: @escaping (String) -> Void) {
        if let url = URL(string: host + CONFIRM) {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = try? JSONEncoder().encode(self.item)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 10.0
            
            let task = URLSession.shared.dataTask(with: request) { _, _, error in
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
    func offset(host: String, failure: @escaping (String) -> Void) {
        if let url = URL(string: host + OFFSET) {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = try? JSONEncoder().encode(self)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 10.0
            
            let task = URLSession.shared.dataTask(with: request) { _, _, error in
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
