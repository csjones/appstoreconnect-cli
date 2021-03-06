// Copyright 2020 Itty Bitty Apps Pty Ltd

import AppStoreConnect_Swift_SDK
import Combine
import Foundation
import struct Model.BetaTester
import SwiftyTextTable

extension BetaTester {
    init(_ output: GetBetaTesterOperation.Output) {
        let attributes = output.betaTester.attributes
        let relationships = output.betaTester.relationships

        // Find tester related beta groups and apps in included data
        let betaGroupsNames = relationships?.betaGroups?.data?
            .compactMap { group -> [AppStoreConnect_Swift_SDK.BetaGroup]? in
                output.betaGroups?.filter { $0.id == group.id }
            }
            .flatMap { $0.compactMap { $0.attributes?.name } }

        let appsBundleIds = relationships?.apps?.data?
            .compactMap { app -> [AppStoreConnect_Swift_SDK.App]? in
                output.apps?.filter { app.id == $0.id }
            }
            .flatMap { $0.compactMap { $0.attributes?.bundleId } }

        self.init(
            email: attributes?.email,
            firstName: attributes?.firstName,
            lastName: attributes?.lastName,
            inviteType: attributes?.inviteType?.rawValue,
            betaGroups: betaGroupsNames,
            apps: appsBundleIds
        )
    }
}

extension BetaTester: ResultRenderable, TableInfoProvider {
    static func tableColumns() -> [TextTableColumn] {
       return [
            TextTableColumn(header: "Email"),
            TextTableColumn(header: "First Name"),
            TextTableColumn(header: "Last Name"),
            TextTableColumn(header: "Invite Type"),
            TextTableColumn(header: "Beta Groups"),
            TextTableColumn(header: "Apps"),
        ]
    }

    var tableRow: [CustomStringConvertible] {
        return [
            email ?? "",
            firstName ?? "",
            lastName ?? "",
            inviteType ?? "",
            betaGroups?.joined(separator: ", ") ?? [],
            apps?.joined(separator: ", ") ?? [],
        ]
    }
}
