import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Shares as a real `.csv` file, so spreadsheets and Files open it directly.
struct CSVDocument: Transferable {
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { document in
            Data(document.text.utf8)
        }
        .suggestedFileName("\(Brand.name) Log.csv")
    }
}

struct BackupDocument: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { document in
            document.data
        }
        .suggestedFileName("\(Brand.name) Backup.json")
    }
}
