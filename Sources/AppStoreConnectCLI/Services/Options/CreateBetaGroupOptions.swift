// Copyright 2020 Itty Bitty Apps Pty Ltd

import Foundation

struct CreateBetaGroupOptions {
    let appBundleId: String
    let groupName: String
    let publicLinkEnabled: Bool
    let publicLinkLimit: Int?
}