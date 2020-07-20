// Copyright 2020 Itty Bitty Apps Pty Ltd

import ArgumentParser
import FileSystem
import Foundation

struct TestFlightPushCommand: CommonParsableCommand {

    static var configuration =  CommandConfiguration(
        commandName: "push",
        abstract: "Push the local configuration to TestFlight."
    )

    @OptionGroup()
    var common: CommonOptions

    @Option(
        default: "./config/apps",
        help: "Path to the folder containing the TestFlight configuration."
    )
    var inputPath: String

    @Flag(help: "Perform a dry run.")
    var dryRun: Bool

    func run() throws {
        let service = try makeService()

        let localConfigs = try TestFlightConfigLoader().load(appsFolderPath: inputPath)

        let serverConfigs = try service.pullTestFlightConfigs()

        try serverConfigs.forEach { serverConfig in
            guard
                let localConfig = localConfigs
                    .first(where: { $0.app.id == serverConfig.app.id }) else {
                return
            }

            let appId = localConfig.app.id

            // 1. compare shared testers in app
            let sharedTestersHandleStrategies = SyncResourceComparator(
                localResources: localConfig.testers,
                serverResources: serverConfig.testers
            ).compare()

            // 1.1 handle shared testers delete only
            try processAppTesterStrategies(sharedTestersHandleStrategies, appId: appId, service: service)

            // 2. compare beta groups
            let localBetagroups = localConfig.betagroups
            let serverBetagroups = serverConfig.betagroups

            let betaGroupHandlingStrategies = SyncResourceComparator(
                    localResources: localBetagroups,
                    serverResources: serverBetagroups
                )
                .compare()

            // 2.1 handle groups create, update, delete
            try processBetagroupsStrategies(betaGroupHandlingStrategies, appId: appId, service: service)

            // 3. compare testers in group and add, delete
            try localBetagroups.forEach { localBetagroup in
                guard
                    let serverBetagroup = serverBetagroups.first(where: {  $0.id == localBetagroup.id }) else {
                    return
                }

                let betagroupId = serverBetagroup.id

                let localGroupTesters = localBetagroup.testers

                let serverGroupTesters = serverBetagroup.testers

                let testersInGroupHandlingStrategies = SyncResourceComparator(
                    localResources: localGroupTesters,
                    serverResources: serverGroupTesters
                ).compare()

                // 3.1 handling adding/deleting testers per group
                try processTestersInBetaGroupStrategies(
                    testersInGroupHandlingStrategies,
                    betagroupId: betagroupId!,
                    appTesters: localConfig.testers,
                    service: service
                )
            }
        }
    }

    func processAppTesterStrategies(_ strategies: [SyncStrategy<FileSystem.BetaTester>], appId: String, service: AppStoreConnectService) throws {
        if dryRun {
            SyncResultRenderer<FileSystem.BetaTester>().render(strategies, isDryRun: true)
        } else {
            try strategies.forEach { strategy in
                switch strategy {
                case .delete(let betatester):
                    try service.removeTesterFromApp(testerEmail: betatester.email, appId: appId)
                    SyncResultRenderer<FileSystem.BetaTester>().render(strategies, isDryRun: false)
                default:
                    return
                }
            }
        }
    }

    func processBetagroupsStrategies(_ strategies: [SyncStrategy<FileSystem.BetaGroup>], appId: String, service: AppStoreConnectService) throws {
        let renderer = SyncResultRenderer<FileSystem.BetaGroup>()

        if dryRun {
            renderer.render(strategies, isDryRun: true)
        } else {
            try strategies.forEach { strategy in
                switch strategy {
                case .create(let betagroup):
                    _ = try service.createBetaGroup(
                        appId: appId,
                        groupName: betagroup.groupName,
                        publicLinkEnabled: betagroup.publicLinkEnabled ?? false,
                        publicLinkLimit: betagroup.publicLinkLimit
                    )
                    renderer.render(strategy, isDryRun: false)
                case .delete(let betagroup):
                    try service.deleteBetaGroup(with: betagroup.id!)
                    renderer.render(strategy, isDryRun: false)
                case .update(let betagroup):
                    try service.updateBetaGroup(betaGroup: betagroup)
                    renderer.render(strategy, isDryRun: false)
                }
            }
        }
    }

    func processTestersInBetaGroupStrategies(
        _ strategies: [SyncStrategy<BetaGroup.EmailAddress>],
        betagroupId: String,
        appTesters: [BetaTester],
        service: AppStoreConnectService
    ) throws {
        let renderer = SyncResultRenderer<FileSystem.BetaGroup.EmailAddress>()

        if dryRun {
            renderer.render(strategies, isDryRun: true)
        } else {
            let deletingEmailsWithStrategy = strategies.compactMap { (strategy: SyncStrategy<BetaGroup.EmailAddress>) -> (email: String, strategy: SyncStrategy<BetaGroup.EmailAddress>)? in
                if case .delete(let email) = strategy {
                    return (email, strategy)
                }
                return nil
            }

            try service.removeTestersFromGroup(
                emails: deletingEmailsWithStrategy.map { $0.email },
                groupId: betagroupId
            )
            renderer.render(deletingEmailsWithStrategy.map { $0.strategy }, isDryRun: false)

            let creatingTestersWithStrategy = strategies
                .compactMap { (strategy: SyncStrategy<BetaGroup.EmailAddress>) ->
                    (tester: BetaTester, strategy: SyncStrategy<BetaGroup.EmailAddress>)? in
                    if case .create(let email) = strategy,
                       let betatester = appTesters.first(where: { $0.email == email }) {
                        return (betatester, strategy)
                    }
                    return nil
                }

            try creatingTestersWithStrategy.forEach {
                try service.inviteBetaTesterToGroups(
                    firstName: $0.tester.firstName,
                    lastName: $0.tester.lastName,
                    email: $0.tester.email,
                    groupId: betagroupId
                )

                renderer.render($0.strategy, isDryRun: false)
            }
        }
    }

}
