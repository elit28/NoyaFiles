import Foundation

/// Loose files of one category, with their combined size.
public struct CategoryGroup: Sendable, Equatable, Identifiable {
    public let category: FileCategory
    public let items: [FileItem]
    public let bytes: Int64

    public var id: FileCategory { category }
}

/// A period of time used to group files by date.
public enum DateBucket: Int, CaseIterable, Sendable, Comparable {
    case today
    case yesterday
    case previous7Days
    case previous30Days
    case earlierThisYear
    case older

    public static func < (lhs: DateBucket, rhs: DateBucket) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// The bucket a date falls into, relative to `now`. Missing dates count as older.
    public static func bucket(for date: Date?, now: Date, calendar: Calendar = .current) -> DateBucket {
        guard let date else { return .older }
        if date >= now || calendar.isDate(date, inSameDayAs: now) { return .today }

        let startOfToday = calendar.startOfDay(for: now)
        func daysAgo(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: startOfToday) ?? startOfToday
        }

        if date >= daysAgo(1) { return .yesterday }
        if date >= daysAgo(7) { return .previous7Days }
        if date >= daysAgo(30) { return .previous30Days }
        if calendar.isDate(date, equalTo: now, toGranularity: .year) { return .earlierThisYear }
        return .older
    }
}

public enum Grouping {
    /// Groups loose files and packages by category, largest group first. Folders are ignored.
    public static func byCategory(
        _ items: [FileItem],
        measurements: [URL: FolderSizer.Measurement] = [:]
    ) -> [CategoryGroup] {
        var buckets: [FileCategory: [FileItem]] = [:]
        for item in items where !item.isFolder {
            buckets[item.category ?? .other, default: []].append(item)
        }

        return buckets
            .map { category, items in
                let bytes = items.reduce(Int64(0)) { total, item in
                    total + (item.isContainer ? (measurements[item.url]?.bytes ?? 0) : item.size)
                }
                return CategoryGroup(category: category, items: items, bytes: bytes)
            }
            .sorted { lhs, rhs in
                if lhs.bytes != rhs.bytes { return lhs.bytes > rhs.bytes }
                return lhs.category.rawValue < rhs.category.rawValue
            }
    }

    /// Groups items by when they last saw activity, most recent bucket first. Empty buckets are omitted.
    public static func byDate(
        _ items: [FileItem],
        now: Date,
        calendar: Calendar = .current
    ) -> [(bucket: DateBucket, items: [FileItem])] {
        var buckets: [DateBucket: [FileItem]] = [:]
        for item in items {
            buckets[DateBucket.bucket(for: item.lastActivityDate, now: now, calendar: calendar), default: []].append(item)
        }
        return DateBucket.allCases.compactMap { bucket in
            guard let items = buckets[bucket] else { return nil }
            return (bucket, items)
        }
    }
}
