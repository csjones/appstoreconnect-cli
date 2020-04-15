// Copyright 2020 Itty Bitty Apps Pty Ltd

import AppStoreConnect_Swift_SDK
import ArgumentParser
import Combine
import Foundation

struct DeleteBundleIdCommand: CommonParsableCommand {

    public static var configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Delete a bundle ID that is used for app development."
    )

    @OptionGroup()
    var common: CommonOptions

    @Argument(help: "The reverse-DNS bundle ID identifier to delete. Must be unique. (eg. com.example.app)")
    var identifier: String

    func run() throws {
        let api = try makeClient()

        _ = try api
            .bundleIdResourceId(matching: identifier)
            .flatMap { api.request(APIEndpoint.delete(bundleWithId: $0)) }
            .renderResult(format: common.outputFormat)
    }
}
