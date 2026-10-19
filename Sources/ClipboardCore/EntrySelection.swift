import Foundation

/// Selection is driven by explicit row clicks, separate from drag gestures.
public struct EntrySelection {
    public private(set) var ids: Set<UUID> = []
    public private(set) var previewID: UUID?
    private var anchorID: UUID?

    public init() {}

    public mutating func select(_ id: UUID, visibleIDs: [UUID], toggle: Bool = false, range: Bool = false) {
        guard let clicked = visibleIDs.firstIndex(of: id) else { return }
        if range, let anchorID, let anchor = visibleIDs.firstIndex(of: anchorID) {
            let rangeIDs = Set(visibleIDs[min(anchor, clicked)...max(anchor, clicked)])
            ids = toggle ? ids.union(rangeIDs) : rangeIDs
        } else if toggle {
            if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
            anchorID = id
        } else {
            ids = [id]
            anchorID = id
        }
        previewID = ids.contains(id) ? id : visibleIDs.first(where: { ids.contains($0) })
    }

    public mutating func selectAll(visibleIDs: [UUID]) {
        ids = Set(visibleIDs)
        if previewID == nil || !ids.contains(previewID!) { previewID = visibleIDs.first }
        anchorID = previewID
    }

    public mutating func reconcile(visibleIDs: [UUID]) {
        ids.formIntersection(visibleIDs)
        if previewID == nil || !ids.contains(previewID!) {
            previewID = visibleIDs.first(where: { ids.contains($0) })
        }
        if anchorID == nil || !visibleIDs.contains(anchorID!) { anchorID = previewID }
    }
}
