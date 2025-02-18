//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAsyncDNSResolver open source project
//
// Copyright (c) 2020-2024 Apple Inc. and the SwiftAsyncDNSResolver project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAsyncDNSResolver project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import CAsyncDNSResolver
import Foundation

// MARK: - ares_channel

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
class AresChannel {
    let pointer: UnsafeMutablePointer<ares_channel?>
    let lock = NSLock()

    private var underlying: ares_channel? {
        self.pointer.pointee
    }

    deinit {
        ares_destroy(pointer.pointee)
        pointer.deallocate()
        ares_library_cleanup()
    }

    init(options: AresOptions) throws {
        // Initialize c-ares
        try checkAresResult { ares_library_init(ARES_LIB_INIT_ALL) }

        // Initialize channel with options
        let pointer = UnsafeMutablePointer<ares_channel?>.allocate(capacity: 1)
        try checkAresResult { ares_init_options(pointer, options.pointer, options.optionMasks) }

        // Additional options that require channel
        if let serversCSV = options.servers?.joined(separator: ",") {
            try checkAresResult { ares_set_servers_ports_csv(pointer.pointee, serversCSV) }
        }

        if let sortlist = options.sortlist?.joined(separator: " ") {
            try checkAresResult { ares_set_sortlist(pointer.pointee, sortlist) }
        }

        self.pointer = pointer
    }

    func withChannel(_ body: (ares_channel) -> Void) {
        self.lock.lock()
        defer { self.lock.unlock() }

        guard let underlying = self.underlying else {
            fatalError("ares_channel not initialized")
        }
        body(underlying)
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
private func checkAresResult(body: () -> Int32) throws {
    let result = body()
    guard result == ARES_SUCCESS else {
        throw AsyncDNSResolver.Error(code: result, "failed to initialize channel")
    }
}
