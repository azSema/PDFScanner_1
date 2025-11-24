import SwiftUI

struct QuickActionsGrid: View {
    
    let onConvertTap: () -> Void
    let onEditTap: () -> Void
    let onMergeTap: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // First row - 2 items
            HStack(spacing: 12) {
                QuickActionCard(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Convert",
                    subtitle: "Change format",
                    color: .appSuccess,
                    action: onConvertTap
                )
                
                QuickActionCard(
                    icon: "pencil.and.outline",
                    title: "Edit",
                    subtitle: "Modify PDF",
                    color: .appWarning,
                    action: onEditTap
                )
            }
            
            // Second row - 1 item centered
            HStack {
                Spacer()
                
                QuickActionCard(
                    icon: "doc.on.doc",
                    title: "Merge",
                    subtitle: "Combine files",
                    color: .appSecondary,
                    action: onMergeTap
                )
                .frame(maxWidth: .infinity)
                
                Spacer()
            }
        }
    }
}

struct QuickActionCard: View {
    
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            playHaptic(.medium)
            action()
        }) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.semiBold(18))
                            .foregroundStyle(.appText)
                        
                        Text(subtitle)
                            .font(.regular(12))
                            .foregroundStyle(.appTextSecondary)
                    }
                    
                    Spacer()
                }
                
                HStack {
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.2))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(color)
                    }
                }
            }
            .padding(16)
            .frame(height: 100)
            .background(.appSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.appBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0) { isPressing in
            isPressed = isPressing
        } perform: {}
    }
}

#Preview {
    VStack {
        QuickActionsGrid(
            onConvertTap: {},
            onEditTap: {},
            onMergeTap: {}
        )
        .padding()
        
        Spacer()
    }
    .background(.appBackground)
}