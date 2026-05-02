import SwiftUI

struct YearWheelPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let years: [Int]
    @Binding var selectedYear: Int

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("feed.year_picker.title", selection: $selectedYear) {
                    ForEach(years, id: \.self) { year in
                        Text(String(year))
                            .tag(year)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
            }
            .navigationTitle("feed.year_picker.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") {
                        dismiss()
                    }
                }
            }
            .background(Color.clear)
        }
    }
}
