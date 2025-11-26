import SwiftUI

let gradient: LinearGradient = .linearGradient(colors: [Color.init(hex: "#DB312C"),
                                                        Color.init(hex: "#FF5351")], startPoint: .bottom, endPoint: .top)

struct OnboardingFlow: View {
    
    @EnvironmentObject var router: Router
    @EnvironmentObject var premium: PremiumManager
        
    @State private var step: OnboardingPage = .page1
    
    @State private var isTrialEnabled: Bool = false
    
    @State private var isShowAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    @State private var orientation = UIDevice.current.orientation
    @State private var deviceType = DeviceManager.shared.deviceType
    
    @ViewBuilder
    private var animationOverlay: some View {
        switch step {
        case .page1:
            if deviceType == .iphoneSE {
                AnimationView(item: deviceType == .iphoneLarge ? .onb1Iphone : .onb1Ipad,
                              contentMode: .scaleAspectFill)
                    .scaleEffect(0.96)
                    .cornerRadius(60)
                    .offset(y: -5)
                    .overlay(content: {
                        Image(.mask)
                            .resizable()
                            .scaledToFit()
                            .offset(y: -20)
                    })
                    .frame(width: UIScreen.main.bounds.width - 120,
                           height: UIScreen.main.bounds.height - 120)
                    .offset(y: -35)
                    .scaleEffect(0.98)
            } else {
                AnimationView(item: deviceType == .iphoneLarge ? .onb1Iphone : .onb1Ipad,
                              contentMode: orientation.isLandscape ? .scaleAspectFit : .scaleAspectFill)
                    .scaleEffect(0.96)
                    .cornerRadius(60)
                    .offset(y: -5)
                    .overlay(content: {
                        Image(.mask)
                            .resizable()
                            .scaledToFit()
                            .offset(y: -30)
                    })
                    .frame(width: UIScreen.main.bounds.width - 100,
                           height: UIScreen.main.bounds.height - 200)
                    .offset(y: -50)
                    .scaleEffect(0.98)
            }
        case .page2:
            switch deviceType {
            case .iphoneSE:
                AnimationView(item: .signature)
                    .frame(width: 150, height: 150)
                    .offset(x: 70, y: 5)
                    .rotationEffect(.degrees(-15))
            case .iphoneLarge:
                AnimationView(item: .signature)
                    .frame(width: 150, height: 150)
                    .offset(x: 70, y: 5)
                    .rotationEffect(.degrees(-15))
            case .ipad:
                if orientation.isLandscape {
                    AnimationView(item: .signature)
                        .frame(width: 150, height: 150)
                        .offset(x: 100, y: 20)
                        .rotationEffect(.degrees(-15))
                } else {
                    AnimationView(item: .signature)
                        .frame(width: 200, height: 200)
                        .offset(x: 70, y: 100)
                        .rotationEffect(.degrees(-15))
                }
            }
            
        case .page3:
            if deviceType == .iphoneSE {
                AnimationView(item: deviceType == .iphoneLarge ? .onb2Iphone : .onb2Ipad,
                              contentMode: .scaleAspectFill)
                    .scaleEffect(0.96)
                    .cornerRadius(60)
                    .offset(y: -5)
                    .overlay(content: {
                        Image(.mask)
                            .resizable()
                            .scaledToFit()
                            .offset(y: -20)
                    })
                    .frame(width: UIScreen.main.bounds.width - 120,
                           height: UIScreen.main.bounds.height - 120)
                    .offset(y: -35)
                    .scaleEffect(0.98)
            } else {
                AnimationView(item: deviceType == .iphoneLarge ? .onb2Iphone : .onb2Ipad,
                              contentMode: orientation.isLandscape ? .scaleAspectFit : .scaleAspectFill)
                    .scaleEffect(0.96)
                    .cornerRadius(60)
                    .offset(y: -5)
                    .overlay(content: {
                        Image(.mask)
                            .resizable()
                            .scaledToFit()
                            .offset(y: -30)
                    })
                    .frame(width: UIScreen.main.bounds.width - 100,
                           height: UIScreen.main.bounds.height - 200)
                    .offset(y: -50)
                    .scaleEffect(0.98)
            }
        case .page4:
             AnimationView(item: .ocrScan)
                .frame(width: 1, height: 1)
        case .paywall:
            if deviceType == .iphoneLarge {
                VStack {
                    AnimationView(item: .pdfFIle)
                       .frame(width: 120, height: 120)
                       .padding(.top, 50)
                    Spacer()
                }
            }

        }
    }
        
    var body: some View {
        ZStack {

            BackImage(baseName: step.inputModel().imageBaseName)
                .overlay {
                    animationOverlay
                }
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                VStack(spacing: deviceType == .iphoneSE ? 8 : 12) {
                    OnboardPageControl(selected: $step)
                    title(text: getTitle())
                    subtitle(text: getSubtitle())
                        .frame(height: 50)
                        .animation(nil, value: step)
                    VStack(spacing: 8) {
                        messageSection
                        nextButton
                    }
                    
                    FooterView(color: Color.init(hex: "#AEAEB2"),  onRestore: {
                        Task {
                            await restoreTapped()
                        }
                    })
                }
                .padding()
                .background {
                    Rectangle()
                        .fill(.white)
                        .cornerRadius(16)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.appBorder, lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.1), radius: 14)
                }
                .padding()
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            
        }
        .alert(isPresented: $isShowAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage))
        }
        .onRotate(perform: { orientation = $0 })
    }

    
    private func subtitle(text: String) -> some View {
        Text(text)
            .frame(maxWidth: .infinity, alignment: .top)
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(.appTextSecondary)
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
                .font(.system(size: 16, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundStyle(.appTextSecondary)
        }
    }
    
    @ViewBuilder
    private func title(text: String) -> some View {
        let chunks = text.components(separatedBy: "\n")
        VStack {
            if let top = chunks.first, let bottom = chunks.last {
                Text(top)
                    .font(.system(size: deviceType == .iphoneSE ? 26 : 28, weight: .medium))
                Text(bottom)
                    .font(.system(size: deviceType == .iphoneSE ? 22 : 24, weight: .medium))
            }
        }
        .foregroundStyle(.black)
        .multilineTextAlignment(.center)
    }
    
    @ViewBuilder
    private var messageSection: some View {
        Text(getMessage())
            .frame(height: 48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.system(size: 15))
            .foregroundStyle(.appTextSecondary)
            .overlay(alignment: .trailing) {
                Toggle(isTrialEnabled ? "" : "", isOn: $isTrialEnabled)
                    .opacity(step == .paywall ? 1 : 0)
            }
            .padding(.horizontal)
            .background(.appSecondary.opacity(0.3))
            .cornerRadius(16)
    }
    
    private var nextButton: some View {
        
        return Button {
            nextTapped()
        } label: {
            Text(getButtonTitle())
                .font(.system(size: 20, weight: .medium))
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundStyle(.white)
                .background(gradient)
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
        HStack(spacing: 2) {
            ForEach(OnboardingPage.allCases, id: \.self) { onboard in
                standartControl(for: onboard)
            }
        }
    }
    
    @ViewBuilder
    private func standartControl(for page: OnboardingPage) -> some View {
        if page == selected {
            Rectangle()
                .fill(gradient)
                .frame(width: 13, height: 6)
                .clipShape(
                    RoundedRectangle(cornerRadius: 50)
                )
                .matchedGeometryEffect(id: "IndicatorAnimationId", in: animation)
        } else {
            Circle()
                .fill(gradient)
                .opacity(0.35)
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
