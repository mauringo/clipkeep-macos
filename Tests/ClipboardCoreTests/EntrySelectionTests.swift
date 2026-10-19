import Foundation
import Testing
@testable import ClipboardCore

struct EntrySelectionTests {
    private let rows = (0..<5).map { _ in UUID() }

    @Test func clickingAnotherRowChangesPreviewAndSelection() {
        var selection = EntrySelection()
        selection.select(rows[0], visibleIDs: rows)
        selection.select(rows[3], visibleIDs: rows)
        #expect(selection.ids == [rows[3]])
        #expect(selection.previewID == rows[3])
    }

    @Test func commandClickAndCheckboxToggleKeepMultipleItems() {
        var selection = EntrySelection()
        selection.select(rows[1], visibleIDs: rows)
        selection.select(rows[3], visibleIDs: rows, toggle: true)
        #expect(selection.ids == [rows[1], rows[3]])
        #expect(selection.previewID == rows[3])
        selection.select(rows[3], visibleIDs: rows, toggle: true)
        #expect(selection.ids == [rows[1]])
        #expect(selection.previewID == rows[1])
    }

    @Test func shiftClickUsesAnchorInEitherDirectionAndCanExtendSelection() {
        var selection = EntrySelection()
        selection.select(rows[3], visibleIDs: rows)
        selection.select(rows[1], visibleIDs: rows, range: true)
        #expect(selection.ids == Set(rows[1...3]))
        #expect(selection.previewID == rows[1])
        selection.select(rows[4], visibleIDs: rows, toggle: true, range: true)
        #expect(selection.ids == Set(rows[1...4]))
    }

    @Test func filteringEvictionAndNewCapturesPreserveOnlyVisibleSelections() {
        var selection = EntrySelection()
        selection.selectAll(visibleIDs: rows)
        let visible = [UUID(), rows[2], rows[4]]
        selection.reconcile(visibleIDs: visible)
        #expect(selection.ids == [rows[2], rows[4]])
        #expect(selection.previewID == rows[2])
        selection.reconcile(visibleIDs: [])
        #expect(selection.ids.isEmpty)
        #expect(selection.previewID == nil)
    }
}
