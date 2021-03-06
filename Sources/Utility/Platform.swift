/*
 This source file is part of the Swift.org open source project
 
 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception
 
 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Basic

public enum Platform {
    case darwin
    case linux(LinuxFlavor)
    
    public enum LinuxFlavor {
        case debian
    }
    
    // Lazily return current platform.
    public static var currentPlatform = Platform.findCurrentPlatform()
    private static func findCurrentPlatform() -> Platform? {
        guard let uname = try? Process.checkNonZeroExit(args: "uname").chomp().lowercased() else { return nil }
        switch uname {
        case "darwin":
            return .darwin
        case "linux":
            if isFile(AbsolutePath("/etc/debian_version")) {
                return .linux(.debian)
            }
        default:
            return nil
        }
        return nil
    }
}
