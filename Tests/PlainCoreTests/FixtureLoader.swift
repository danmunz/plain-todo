import Foundation

enum FixtureLoaderError: Error {
    case missingFixture(String)
}

enum FixtureLoader {
    static func text(named name: String) throws -> String {
        #if SWIFT_PACKAGE
        let fixtureURL = Bundle.module.url(forResource: name, withExtension: "txt", subdirectory: "Fixtures")
        #else
        let fixtureURL = Bundle(for: BundleToken.self).url(forResource: name, withExtension: "txt")
        #endif

        guard let url = fixtureURL else {
            throw FixtureLoaderError.missingFixture(name)
        }

        return try String(contentsOf: url, encoding: .utf8)
    }
}

private final class BundleToken {}