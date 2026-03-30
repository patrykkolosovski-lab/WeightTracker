import Foundation

struct WeightTimelineNormalizationResult<Entry> {
    let canonicalEntries: [Entry]
    let duplicateEntryIDs: [UUID]
    let survivorEntryIDs: [UUID]

    var hasDuplicates: Bool {
        !duplicateEntryIDs.isEmpty
    }
}

/// Shared day-level timeline normalization used by both local persistence and
/// cloud hydration paths.
enum WeightTimelineNormalizer {
    /// Returns one canonical local record per day, keeping the newest update
    /// when duplicates already exist.
    static func normalize(records: [WeightEntryRecord]) -> WeightTimelineNormalizationResult<WeightEntryRecord> {
        normalize(
            entries: records,
            id: \.id,
            date: \.date,
            updatedAt: \.updatedAt,
            createdAt: \.createdAt
        )
    }

    /// Returns one canonical synced snapshot per day so remote duplicates can
    /// be cleaned up before they reach the UI.
    static func normalize(
        snapshots: [SyncedWeightEntrySnapshot]
    ) -> WeightTimelineNormalizationResult<SyncedWeightEntrySnapshot> {
        normalize(
            entries: snapshots,
            id: \.id,
            date: \.date,
            updatedAt: \.updatedAt,
            createdAt: \.createdAt
        )
    }

    private static func normalize<Entry>(
        entries: [Entry],
        id: KeyPath<Entry, UUID>,
        date: KeyPath<Entry, Date>,
        updatedAt: KeyPath<Entry, Date>,
        createdAt: KeyPath<Entry, Date>
    ) -> WeightTimelineNormalizationResult<Entry> {
        let calendar = Calendar.current
        let groupedEntries = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry[keyPath: date])
        }

        var canonicalEntries: [Entry] = []
        var duplicateIDs: [UUID] = []
        var survivorIDs: [UUID] = []

        for dayEntries in groupedEntries.values {
            let sortedEntries = dayEntries.sorted { lhs, rhs in
                isOlder(
                    lhs,
                    than: rhs,
                    id: id,
                    date: date,
                    updatedAt: updatedAt,
                    createdAt: createdAt
                )
            }

            guard let survivor = sortedEntries.last else { continue }
            canonicalEntries.append(survivor)

            if sortedEntries.count > 1 {
                survivorIDs.append(survivor[keyPath: id])
                duplicateIDs.append(contentsOf: sortedEntries.dropLast().map { $0[keyPath: id] })
            }
        }

        canonicalEntries.sort { lhs, rhs in
            if lhs[keyPath: date] == rhs[keyPath: date] {
                return isOlder(
                    lhs,
                    than: rhs,
                    id: id,
                    date: date,
                    updatedAt: updatedAt,
                    createdAt: createdAt
                )
            }

            return lhs[keyPath: date] < rhs[keyPath: date]
        }

        return WeightTimelineNormalizationResult(
            canonicalEntries: canonicalEntries,
            duplicateEntryIDs: duplicateIDs,
            survivorEntryIDs: survivorIDs
        )
    }

    private static func isOlder<Entry>(
        _ lhs: Entry,
        than rhs: Entry,
        id: KeyPath<Entry, UUID>,
        date: KeyPath<Entry, Date>,
        updatedAt: KeyPath<Entry, Date>,
        createdAt: KeyPath<Entry, Date>
    ) -> Bool {
        if lhs[keyPath: updatedAt] == rhs[keyPath: updatedAt] {
            if lhs[keyPath: date] == rhs[keyPath: date] {
                if lhs[keyPath: createdAt] == rhs[keyPath: createdAt] {
                    return lhs[keyPath: id].uuidString < rhs[keyPath: id].uuidString
                }

                return lhs[keyPath: createdAt] < rhs[keyPath: createdAt]
            }

            return lhs[keyPath: date] < rhs[keyPath: date]
        }

        return lhs[keyPath: updatedAt] < rhs[keyPath: updatedAt]
    }
}
