// Copyright 2020 Itty Bitty Apps Pty Ltd

import AppStoreConnect_Swift_SDK
import Combine
import Foundation

struct ListBetaGroupsOperation: APIOperation {

    struct Options {
        let appIds: [String]
    }

    typealias BetaGroup = AppStoreConnect_Swift_SDK.BetaGroup
    typealias App = AppStoreConnect_Swift_SDK.App

    typealias Output = [(app: App, betaGroup: BetaGroup)]

    enum Error: LocalizedError {
        case missingAppData(BetaGroup)

        var errorDescription: String? {
            switch self {
            case .missingAppData(let betaGroup):
                return "Missing app data for beta group: \(betaGroup)"
            }
        }
    }

    private let options: Options

    init(options: Options) {
        self.options = options
    }

    func execute(with requestor: EndpointRequestor) -> AnyPublisher<Output, Swift.Error> {
        let filters = options.appIds.isEmpty ? [] : [ListBetaGroups.Filter.app(options.appIds)]
        let endpoint = APIEndpoint.betaGroups(filter: filters, include: [.app])
        let response = requestor.request(endpoint)

        let output = response.tryMap { response -> Output in
            let apps = response.included?.reduce(
                into: [String: AppStoreConnect_Swift_SDK.App](),
                { result, relationship in
                    switch relationship {
                    case .app(let app):
                        result[app.id] = app
                    default:
                        break
                    }
                }
            )

            return try response.data.map { betaGroup -> (App, BetaGroup) in
                guard
                    let appId = betaGroup.relationships?.app?.data?.id,
                    let app = apps?[appId]
                else {
                    throw Error.missingAppData(betaGroup)
                }

                return (app, betaGroup)
            }
        }

        return output.eraseToAnyPublisher()
    }
}