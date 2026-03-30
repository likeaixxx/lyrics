import Foundation
import Combine

final class LyricsService {
    static let shared = LyricsService()

    private let LYRICS = "/api/v1/lyrics"
    private let CONFIRM = "/api/v1/lyrics/confirm"
    private let OFFSET = "/api/v1/lyrics/offset"

    private let NET_WORK_ERROR = "☹️Network Error"
    private let NOTHING_FOUND = "☹️Nothing Found"
    private let INVALID = "☹️Invalid Track Name"

    func fetchLyrics(apiData: LyricAPI, host: String, success: @escaping ([LyricResponseItem]) -> Void, failure: @escaping (String) -> Void) {
        guard apiData.name != nil else {
            failure(INVALID)
            return
        }
        guard let url = URL(string: host + LYRICS) else {
             failure(NET_WORK_ERROR)
             return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONEncoder().encode(apiData)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                failure(error.localizedDescription)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data else {
                print("Server error or invalid response data")
                failure(self.NET_WORK_ERROR)
                return
            }

            do {
                let resp = try JSONDecoder().decode(LyricResponseBody.self, from: data)
                if let data = resp.data {
                    success(data)
                } else {
                    failure(self.NOTHING_FOUND)
                }
            } catch {
                print("Failed to decode data: \(error)")
                failure(self.NET_WORK_ERROR)
            }
        }
        task.resume()
    }

    func confirm(item: LyricResponseItem, host: String, failure: @escaping (String) -> Void) {
        guard let url = URL(string: host + CONFIRM) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONEncoder().encode(item)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0

        let task = URLSession.shared.dataTask(with: request) { [weak self] _, _, error in
            if error != nil {
                failure(self?.NET_WORK_ERROR ?? "Error")
            }
        }
        task.resume()
    }

    func offset(data: OffsetAPI, host: String, failure: @escaping (String) -> Void) {
         guard let url = URL(string: host + OFFSET) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONEncoder().encode(data)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0

        let task = URLSession.shared.dataTask(with: request) { [weak self] _, _, error in
            if error != nil {
                failure(self?.NET_WORK_ERROR ?? "Error")
            }
        }
        task.resume()
    }
}
