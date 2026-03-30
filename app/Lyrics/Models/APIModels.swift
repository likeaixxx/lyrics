import Foundation

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
