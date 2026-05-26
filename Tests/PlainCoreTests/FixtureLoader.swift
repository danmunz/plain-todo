import Foundation

enum FixtureLoaderError: Error {
    case missingFixture(String)
}

enum FixtureLoader {
    static func text(named name: String) throws -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: "txt", subdirectory: "Fixtures") else {
            throw FixtureLoaderError.missingFixture(name)
        }

        return try String(contentsOf: url, encoding: .utf8)
    }
}