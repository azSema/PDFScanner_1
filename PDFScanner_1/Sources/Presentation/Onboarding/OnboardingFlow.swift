import SwiftUI

struct OnboardingFlow: View {
    
    @EnvironmentObject var router: Router
    @EnvironmentObject var premium: PremiumManager
        
    @State private var step: OnboardingPage = .page1
    
    @State private var isTrialEnabled: Bool = false
    
    @State private var isShowAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    @State private var orientation = UIDevice.current.orientation
        
    var body: some View {
        ZStack {

            Color.green.ignoresSafeArea()
            
            VStack(spacing: deviceType == .iphoneSE ? 8 : 12) {
                title(text: getTitle())
                subtitle(text: getSubtitle())
                    .frame(height: 50)
                    .animation(nil, value: step)
                VStack(spacing: 8) {
                    VStack(spacing: 5) {
                        OnboardPageControl(selected: $step)
                        messageSection
                    }

                    nextButton
                }
                
                FooterView(onRestore: {
                    Task {
                        await restoreTapped()
                    }
                })
            }
            .padding(.horizontal)
            .padding(.top)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .alert(isPresented: $isShowAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage))
        }
        .onRotate(perform: { orientation = $0 })
    }

    
    private func subtitle(text: String) -> some View {
        Text(text)
            .frame(maxWidth: .infinity, alignment: .top)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .overlay(alignment: .bottom) {
                limittedButton
                    .opacity(step == .paywall ? 1 : 0)
                    .offset(y: 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    private var limittedButton: some View {
        Button {
            router.finishOnboarding()
        } label: {
            Text("LIMITED BUTTON")
                .font(.system(size: 15, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundStyle(.white)
        }
    }
    
    @ViewBuilder
    private func title(text: String) -> some View {
        let chunks = text.components(separatedBy: "\n")
        VStack {
            if let top = chunks.first, let bottom = chunks.last {
                Text(top)
                    .foregroundStyle(.white)
                    .font(.system(size: deviceType == .iphoneSE ? 26 : 32, weight: .medium))
                Text(bottom)
                    .foregroundStyle(.white)
                    .font(.system(size: deviceType == .iphoneSE ? 26 : 32, weight: .bold))
            }
        }
        .multilineTextAlignment(.center)
    }
    
    @ViewBuilder
    private var messageSection: some View {
        Text(getMessage())
            .frame(height: 48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.system(size: 15))
            .foregroundStyle(.white)
            .overlay(alignment: .trailing) {
                Toggle(isTrialEnabled ? "" : "", isOn: $isTrialEnabled)
                    .opacity(step == .paywall ? 1 : 0)
            }
            .padding(.horizontal)
            .background(.white.opacity(0.15))
            .clipShape(Capsule())
    }
    
    private var nextButton: some View {
        Button {
            nextTapped()
        } label: {
            Text(getButtonTitle())
                .font(.system(size: 20, weight: .medium))
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundStyle(.red)
                .background(Color.white)
                .cornerRadius(16)
            
        }
    }
    
    private func nextTapped() {
        if let nextStep = step.next {
            DispatchQueue.main.async {
                step = nextStep
            }
        } else {
            Task(priority: .userInitiated) {
                await purchaseTapped()
            }
        }
    }
    
    private func getTitle() -> String {
        if step != .paywall {
            step.inputModel().title
        } else {
            "TITLE"
        }
    }

    private func getSubtitle() -> String {
        if step != .paywall {
            return step.inputModel().subtitle
        } else {
           return "SUBTITLE"
        }
    }
    
    private func getMessage() -> String {
        if step != .paywall {
            return step.inputModel().message
        } else {
            return "MESSAGE"
        }
    }
    
    private func getButtonTitle() -> String {
        if step != .paywall {
            return step.inputModel().titleButton
        } else {
            return isTrialEnabled
            ? "TRY FREE"
            : "CONTINUE"
        }
    }
    
    func restoreTapped() async {
        #warning("On resotre")
    }
    
    private func purchaseTapped() async {
        await premium.makePurchase()
        await MainActor.run { router.finishOnboarding() }
    }
    
    private func showError(message: String) {
        presentedAlert(title: "Error",
                       message: message)
        
    }
    
    private func presentedAlert(title: String, message: String) {
        alertMessage = message
        alertTitle = title
        isShowAlert.toggle()
    }

}

struct OnboardPageControl: View {
    
    @Binding var selected: OnboardingPage
    
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(OnboardingPage.allCases, id: \.self) { onboard in
                standartControl(for: onboard)
            }
        }
    }
    
    @ViewBuilder
    private func standartControl(for page: OnboardingPage) -> some View {
        if page == selected {
            Rectangle()
                .fill(.white)
                .frame(width: 13, height: 6)
                .clipShape(
                    RoundedRectangle(cornerRadius: 50)
                )
                .matchedGeometryEffect(id: "IndicatorAnimationId", in: animation)
        } else {
            Circle()
                .fill(.white.opacity(0.15))
                .frame(width: 6, height: 6)
        }
    }
}

#Preview {
    OnboardingFlow()
}

enum OnboardingPage: Int, CaseIterable {
    case page1, page2, page3, page4, paywall
    
    var id: Int {
        rawValue
    }
    
    var next: OnboardingPage? {
        switch self {
        case .page1: .page2
        case .page2: .page3
        case .page3: .page4
        case .page4: .paywall
        case .paywall: nil
        }
    }
    
    func inputModel() -> OnboardingModel {
        OnboardingModel(from: self)
    }
}

struct OnboardingModel {
    let title: String
    let message: String
    let subtitle: String
    var titleButton: String
    var imageBaseName: String
}

extension OnboardingModel {
    
    init(from page: OnboardingPage) {
        titleButton = "Continue"
        
        switch page {
        case .page1:
            title = "PDF Tools\n& Scanner "
            message = "Plan on taking the tests"
            subtitle = "Choose the date and time\nof the test that suits you"
            imageBaseName = "onb1"

        case .page2:
            title = "Smart Data\nWriting"
            message = "Choose the best option"
            subtitle = "Easily set test dates\nto organize your schedule"
            imageBaseName = "onb2"

        case .page3:
            title = "Complete\nPDF Toolkit"
            message = "Pass your tests"
            subtitle = "Find and save the most\nsuitable centre nearby"
            imageBaseName = "onb3"

        case .page4:
            title = "We value \nyour feedback"
            message = "Check why users love it"
            subtitle = "Any feedback is important to us\nso that we could improve our app"
            imageBaseName = "onb4"

        case .paywall:

            title = "Пейвол\nЗаглушка"
            message = ""
            subtitle = "Текст для\nтестов"
            titleButton = "Титл кнопки"
            imageBaseName = "onb5"

        }
    }
}
