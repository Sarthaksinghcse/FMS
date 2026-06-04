//
//  MessageFilterView.swift
//  FMS
//
//  Created by Gauri Verma on 26/05/26.
//


import SwiftUI

enum ChatCategory: String, CaseIterable {
    case all = "All"
    case drivers = "Drivers"
    case managers = "Managers"
    case maintenance = "Maintenance"
}

struct MessageFilterView: View {
    @Binding var selectedCategory: ChatCategory

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ChatCategory.allCases, id: \.self) { category in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            selectedCategory = category
                        }
                    } label: {
                        Text(category.rawValue)
                            .font(.system(size: 13 + (AccessibilityManager.shared.isLargeTextEnabled ? 4 : 0), weight: .bold, design: .rounded))
                            .foregroundColor(
                                selectedCategory == category ? .white : AppTheme.Text.secondary
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                ZStack {
                                    if selectedCategory == category {
                                        Capsule()
                                            .fill(AppTheme.Brand.primary)
                                            .shadow(color: AppTheme.Brand.primary.opacity(0.2), radius: 4, y: 2)
                                    } else {
                                        Capsule()
                                            .fill(Color.black.opacity(0.04))
                                    }
                                }
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }
}

#Preview {
    MessageFilterView(selectedCategory: .constant(.all))
}

