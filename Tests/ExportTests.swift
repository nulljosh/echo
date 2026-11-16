import XCTest
import Carbon.HIToolbox
@testable import Voxprint_macOS

@MainActor
final class ExportTests: XCTestCase {
    /// Export: Markdown bolds speakers and lists action items, SRT has numbered timed cues.
    func testExportFormats() {
        var e = TranscriptionEntry(text: "You: send the budget\nThem: tomorrow morning", duration: 6, model: "tiny")
        e.summary = TranscriptSummary(summary: "Budget talk.", actionItems: ["Them: email the budget"])
        e.lines = [TimedLine(start: 0, end: 2.5, text: "send the budget", speaker: "You"),
                   TimedLine(start: 3, end: 61.25, text: "tomorrow morning", speaker: "Them")]
        let md = Exporter.markdown(e)
        XCTAssertTrue(md.contains("**You:** send the budget"))
        XCTAssertTrue(md.contains("- [ ] Them: email the budget"))
        let srt = Exporter.srt(e)
        XCTAssertTrue(srt.hasPrefix("1\n00:00:00,000 --> 00:00:02,500\nYou: send the budget"), srt)
        XCTAssertTrue(srt.contains("2\n00:00:03,000 --> 00:01:01,250\nThem: tomorrow morning"), srt)
        XCTAssertEqual(Exporter.stamp(3725.5), "01:02:05,500")
        // DOCX is a real zip Word can open: unzip must pass its CRC check and find the speaker line.
        let docx = FileManager.default.temporaryDirectory.appendingPathComponent("echo-test.docx")
        try? Exporter.docx(e).write(to: docx)
        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzip.arguments = ["-p", docx.path, "word/document.xml"]
        let pipe = Pipe(); unzip.standardOutput = pipe
        try? unzip.run(); unzip.waitUntilExit()
        XCTAssertEqual(unzip.terminationStatus, 0)
        XCTAssertTrue(String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).contains("<w:b/></w:rPr><w:t xml:space=\"preserve\">You: </w:t>"))
    }

    /// The Mac hot key registers at launch and a real Carbon hot-key event reaches Echo. The recorder is swapped out so the mic stays off.
    func testDictationHotKey() {
        XCTAssertEqual(HotKey.status, noErr, "Control-Shift-Space is held by another app")
        let fired = expectation(description: "hot key")
        let original = HotKey.onPress
        HotKey.onPress = { fired.fulfill() }
        defer { HotKey.onPress = original }
        var event: EventRef?
        XCTAssertEqual(CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed), 0, EventAttributes(kEventAttributeNone), &event), noErr)
        XCTAssertEqual(SendEventToEventTarget(event, GetApplicationEventTarget()), noErr)
        wait(for: [fired], timeout: 2)
    }
}
