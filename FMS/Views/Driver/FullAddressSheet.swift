import SwiftUI

struct FullAddressSheet: View {
    let source: String
    let destination: String
    let tripCode: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Card
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TRIP CODE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.8)
                        Text(tripCode)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.fmsIndigo)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)

                    // Departure Port Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Color.fmsIndigo)
                            Text("DEPARTURE PORT")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                                .tracking(0.6)
                        }
                        
                        Text(source)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                        
                        Button {
                            UIPasteboard.general.string = source
                        } label: {
                            Label("Copy Address", systemImage: "doc.on.doc")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.fmsIndigo)
                        }
                        .buttonStyle(.borderless)
                        .padding(.leading, 4)
                    }

                    // Arrival Terminal Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.orange)
                            Text("ARRIVAL TERMINAL")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                                .tracking(0.6)
                        }
                        
                        Text(destination)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                        
                        Button {
                            UIPasteboard.general.string = destination
                        } label: {
                            Label("Copy Address", systemImage: "doc.on.doc")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.orange)
                        }
                        .buttonStyle(.borderless)
                        .padding(.leading, 4)
                    }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Full Route Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
