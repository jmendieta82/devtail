import Testing
@testable import Devtail

struct FileIconMapTests {
    @Test func knownExtensionsMapToDistinctSymbols() {
        #expect(FileIconMap.icon(for: "App.swift").symbol == "swift")
        #expect(FileIconMap.icon(for: "index.ts").symbol == "chevron.left.forwardslash.chevron.right")
        #expect(FileIconMap.icon(for: "data.json").symbol == "curlybraces")
        #expect(FileIconMap.icon(for: "logo.png").symbol == "photo.fill")
        #expect(FileIconMap.icon(for: "notes.pdf").symbol == "doc.richtext.fill")
    }

    @Test func caseInsensitive() {
        #expect(FileIconMap.icon(for: "APP.SWIFT").symbol == "swift")
        #expect(FileIconMap.icon(for: "Logo.PNG").symbol == "photo.fill")
    }

    @Test func exactNamesBeatExtension() {
        #expect(FileIconMap.icon(for: "package.json").symbol == "shippingbox.fill")
        #expect(FileIconMap.icon(for: "docker-compose.yml").symbol == "cube.box.fill")
        #expect(FileIconMap.icon(for: "README.md").symbol == "book.fill")
    }

    @Test func envFamilyMatches() {
        #expect(FileIconMap.icon(for: ".env").symbol == "key.fill")
        #expect(FileIconMap.icon(for: ".env.local").symbol == "key.fill")
        #expect(FileIconMap.icon(for: ".environment").symbol != "key.fill")
    }

    @Test func unknownFallsBackToGenericDoc() {
        #expect(FileIconMap.icon(for: "mystery.xyzzy").symbol == FileIconMap.genericFile.symbol)
        #expect(FileIconMap.icon(for: "noextension").symbol == FileIconMap.genericFile.symbol)
    }
}
