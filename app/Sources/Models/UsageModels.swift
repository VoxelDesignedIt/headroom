import Foundation

struct UsageWindow: Equatable {
    let utilization: Double
    let resetsAt: Date

    var percent: Double {
        let value: Double
        if utilization >= 0 && utilization <= 1 {
            value = utilization * 100
        } else if utilization > 1 && utilization <= 100 {
            value = utilization
        } else {
            value = min(max(utilization, 0), 100)
        }
        return min(max(value, 0), 100)
    }

    var resetHasPassed: Bool {
        resetsAt <= Date()
    }

    var isStaleAtCap: Bool {
        resetHasPassed && percent >= 90
    }
}

struct UsageSnapshot: Equatable {
    let session: UsageWindow
    let weekly: UsageWindow
    let weeklySonnet: UsageWindow?
    let weeklyOpus: UsageWindow?
    let lastUpdated: Date
}

enum UsageServiceError: LocalizedError {
    case missingCookie
    case invalidURL
    case unauthorized
    case serverError(Int)
    case invalidResponse
    case organizationNotFound

    var errorDescription: String? {
        switch self {
        case .missingCookie:
            return "No session cookie saved. Open Settings to add your claude.ai session."
        case .invalidURL:
            return "Invalid API URL."
        case .unauthorized:
            return "Session expired. Paste a fresh sessionKey from claude.ai."
        case .serverError(let code):
            return "Claude API returned status \(code)."
        case .invalidResponse:
            return "Could not parse usage response."
        case .organizationNotFound:
            return "Could not find your Claude organization."
        }
    }
}
