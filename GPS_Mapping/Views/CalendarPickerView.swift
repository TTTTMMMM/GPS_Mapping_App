import SwiftUI

/// A month calendar where the dates in `availableDays` are filled in and are the only
/// ones that can be selected.
/// It opens on the most recent available month, and the month arrows stop at the
/// earliest and latest months that contain an available date.
struct CalendarPickerView: View {
    let availableDays: [Date]
    let selectedDate: Date?
    let onSelect: (Date) -> Void

    @State private var displayedMonth: Date

    private let calendar = DayID.calendar
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    init(availableDays: [Date], selectedDate: Date?, onSelect: @escaping (Date) -> Void) {
        self.availableDays = availableDays
        self.selectedDate = selectedDate
        self.onSelect = onSelect

        // Start on the selected date's month, otherwise the latest month with data.
        let start = selectedDate ?? availableDays.max() ?? Date()
        _displayedMonth = State(initialValue: Self.startOfMonth(for: start))
    }

    // MARK: - Month bounds

    private static func startOfMonth(for date: Date) -> Date {
        let calendar = DayID.calendar
        return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private var firstMonth: Date { Self.startOfMonth(for: availableDays.min() ?? displayedMonth) }
    private var lastMonth: Date { Self.startOfMonth(for: availableDays.max() ?? displayedMonth) }
    private var canGoBack: Bool { displayedMonth > firstMonth }
    private var canGoForward: Bool { displayedMonth < lastMonth }

    private var availableSet: Set<Date> { Set(availableDays) }

    // MARK: - Layout helpers

    /// Weekday letters, starting from the calendar's first weekday.
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    /// One entry per grid cell: `nil` for the blanks before the 1st, then each day of the month.
    private var cells: [Date?] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let weekdayOfFirst = calendar.component(.weekday, from: displayedMonth)
        let blanks = (weekdayOfFirst - calendar.firstWeekday + 7) % 7

        let days: [Date?] = dayRange.compactMap {
            calendar.date(byAdding: .day, value: $0 - 1, to: displayedMonth)
        }
        return Array(repeating: nil, count: blanks) + days
    }

    // MARK: - Views

    var body: some View {
        VStack(spacing: 12) {
            header

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.custom("Josefin Sans", size: 12))
                        .foregroundStyle(.black.opacity(0.6))
                }

                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(for: date)
                    } else {
                        Color.clear.frame(height: 38)
                    }
                }
            }
        }
        .frame(maxWidth: 420)
        .foregroundStyle(.black)
    }

    private var header: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!canGoBack)

            Spacer()

            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.custom("Josefin Sans", size: 18))

            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!canGoForward)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
    }

    private func dayCell(for date: Date) -> some View {
        let isAvailable = availableSet.contains(date)
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false

        // Days with data are filled in dark blue; the day currently chosen is white with a ring.
        let fill: Color = isSelected ? .white : (isAvailable ? .calendarDayBlue : .clear)
        let textColor: Color = isSelected ? .calendarDayBlue : (isAvailable ? .white : Color.black.opacity(0.3))

        return Button {
            onSelect(date)
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(.custom("Josefin Sans", size: 15))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .foregroundStyle(textColor)
                .background(Circle().fill(fill))
                .overlay(Circle().stroke(Color.calendarDayBlue, lineWidth: isSelected ? 2 : 0))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
    }

    private func shiftMonth(by value: Int) {
        if let month = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = month
        }
    }
}
