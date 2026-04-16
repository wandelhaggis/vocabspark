import Foundation

struct CSVImportResult {
    let items: [(french: String, german: String)]
    let skippedLines: Int
}

enum CSVImportService {

    static func parse(data: Data) throws -> CSVImportResult {
        // Try UTF-8 first, fall back to Latin-1 (common in European Excel exports)
        let content: String
        if let utf8 = String(data: data, encoding: .utf8) {
            content = utf8
        } else if let latin = String(data: data, encoding: .isoLatin1) {
            content = latin
        } else {
            throw CSVError.invalidEncoding
        }

        var items: [(String, String)] = []
        var skipped = 0

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Auto-detect separator: semicolon > tab > comma
            let separator: Character
            if trimmed.contains(";") {
                separator = ";"
            } else if trimmed.contains("\t") {
                separator = "\t"
            } else if trimmed.contains(",") {
                separator = ","
            } else {
                skipped += 1
                continue
            }

            let parts = trimmed.split(separator: separator, maxSplits: 1)
            guard parts.count == 2 else {
                skipped += 1
                continue
            }

            let fr = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let de = String(parts[1]).trimmingCharacters(in: .whitespaces)
            guard !fr.isEmpty, !de.isEmpty else {
                skipped += 1
                continue
            }

            items.append((fr, de))
        }

        return CSVImportResult(items: items, skippedLines: skipped)
    }

    enum CSVError: LocalizedError {
        case invalidEncoding
        var errorDescription: String? { "Die Datei konnte nicht gelesen werden." }
    }
}
