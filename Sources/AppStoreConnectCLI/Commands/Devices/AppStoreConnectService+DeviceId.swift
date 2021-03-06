// Copyright 2020 Itty Bitty Apps Pty Ltd

import AppStoreConnect_Swift_SDK
import Foundation
import Combine

extension AppStoreConnectService {

    enum DeviceIDError: Error, LocalizedError {
        case notUnique(String)
        case notFound(String)

        var errorDescription: String? {
            switch self {
            case .notUnique(let identifier):
                return "'\(identifier)' is not a unique Device UDID."
            case .notFound(let identifier):
                return "Unable to find device with UDID: '\(identifier)'."
            }
        }
    }

    /// Find the opaque internal resource identifier for a Device  matching `udid`. Use this for reading, modifying and deleting Device resources.
    ///
    /// - parameter udid: The device UDID string.
    /// - returns: The App Store Connect API resource identifier for the Device UDID.
    func deviceUDIDResourceId(matching udid: String) -> AnyPublisher<String, Error> {
        let request = APIEndpoint.listDevices(
            filter: [.udid([udid])]
        )

        return self.request(request)
            .map { $0.data.filter { $0.attributes.udid == udid } }
            .tryMap { response -> String in
                switch response.first {
                case .none:
                    throw DeviceIDError.notFound(udid)
                case .some(let udid) where response.count == 1:
                    return udid.id
                case .some:
                    throw DeviceIDError.notUnique(udid)
                }
            }
            .eraseToAnyPublisher()
    }
}
