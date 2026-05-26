import Foundation

public enum TodoSnapshotLoaderError: Error {
    case nonUTF8File(URL)
}

public enum TodoSnapshotLoader {
    public static func load(from url: URL) throws -> TodoFileSnapshot {
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw TodoSnapshotLoaderError.nonUTF8File(url)
        }

        return TodoParser.parse(text)
    }
}