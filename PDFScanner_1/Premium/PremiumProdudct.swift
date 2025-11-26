import SwiftUI


enum PaywallType: String {
    case main
    case onboarding
}

struct PremiumProduct: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var periodly: String
    var pricePerPeriod: String
    var pricePerWeek: String
    
    var subtitle: String {
        "MOCK subtitle"
    }
    
    var isTrial: Bool {
        title == "week"
    }
}

extension PremiumProduct {
    static func mocks(_ id: PaywallType) -> [PremiumProduct] {
        id == .main
        ? [
            PremiumProduct(id: "w",
                         title: "Weakly",
                         periodly: "week",
                         pricePerPeriod: "4.99/week",
                         pricePerWeek: "Total $4.99/week"),
            PremiumProduct(id: "m",
                         title: "Monthly",
                         periodly: "month",
                         pricePerPeriod: "$12.99/month",
                         pricePerWeek: "Total $3.24/week"),
            PremiumProduct(id: "y",
                         title: "Yearly",
                         periodly: "year",
                         pricePerPeriod: "$39.99/year",
                         pricePerWeek: "Total $0.83/week"),
            PremiumProduct(id: "u",
                         title: "Lifetime",
                         periodly: "lifetime",
                         pricePerPeriod: "59.99",
                         pricePerWeek: "Limited Time Offer")
        ]
        : [
            PremiumProduct(id: "w",
                         title: "Weakly",
                         periodly: "week",
                         pricePerPeriod: "4.99/week",
                         pricePerWeek: "Total $4.99/week")
        ]
    }
}
