import Foundation

struct BaseResponse: Codable, Equatable {
    let code: Int?
}

typealias APIResponseEnvelope = BaseResponse
