import SwiftUI

struct YearWheelPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let years: [Int]
    @Binding var selectedYear: Int

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Year", selection: $selectedYear) {
                    ForEach(years, id: \.self) { year in
                        Text(String(year))
                            .tag(year)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
            }
            .navigationTitle("Year")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .background(Color.clear)
        }
    }
}
