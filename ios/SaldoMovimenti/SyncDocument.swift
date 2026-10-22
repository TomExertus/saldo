//
//  SyncDocument.swift
//  SaldoMovimenti
//

import SwiftUI
import UniformTypeIdentifiers

struct SaldoJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var jsonData: Data
    
    init(jsonData: Data) {
        self.jsonData = jsonData
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.jsonData = data
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: jsonData)
    }
}
