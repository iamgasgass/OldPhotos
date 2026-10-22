import SwiftUI

// The black translucent iOS 6 Photos chrome: `photos_title_bar`, the black
// back button (`UINavigationBarBlackTranslucentBack`), the black rectangle
// bar button (`tool_bar_rectangle_button_larger_image_wide`), the viewer
// toolbar buttons (`tool_bar_button`) and the tab bar (`TabButton_Photos`).

// MARK: - Title bar

/// `photos_title_bar`: 65% black glass over the content, extended behind the
/// status bar / Dynamic Island as iOS 6 black translucent status bar.
struct PhotosTitleBar<Leading: View, Trailing: View>: View {
    let title: String
    let topInset: CGFloat
    var forward = true
    var titleWidth: CGFloat? = nil
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(spacing: 0) {
            Color.black.opacity(0.55)
                .frame(height: topInset)

            ZStack {
                LinearGradient(oldOS: OldPhotosBlackChrome.translucentBar)
                    .oldOSInnerShadowBottom(color: OldPhotosBlackChrome.highlight, radius: 0.025)
                    .oldOSBorder(width: 0.95, edges: [.bottom], color: OldPhotosBlackChrome.hairline)
                    .opacity(OldPhotosBlackChrome.translucentOpacity)
                    .shadow(color: Color.black.opacity(0.25), radius: 0.25, x: 0, y: -0.5)

                HStack {
                    Spacer()
                    Text(title)
                        .font(OldOSFont.bold(22))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.21), radius: 0, x: 0, y: -1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: titleWidth ?? 200)
                        .id(title)
                        .transition(
                            AnyTransition.asymmetric(
                                insertion: .move(edge: forward ? .trailing : .leading),
                                removal: .move(edge: forward ? .leading : .trailing)
                            ).combined(with: .opacity)
                        )
                    Spacer()
                }

                HStack {
                    leading()
                    Spacer()
                    trailing()
                }
            }
            .frame(height: 60)
        }
    }
}

/// The pointed black back button ("Albums", "Camera Roll").
struct PhotosBackButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            OldPhotosHaptics.tap()
            action()
        } label: {
            Text(title)
                .font(OldOSFont.bold(13))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.45), radius: 0, x: 0, y: -0.6)
                .lineLimit(1)
                .fixedSize()
                .offset(y: -1.1)
                .padding(.leading, 17)
                .padding(.trailing, 9)
                .frame(height: 30)
                .background(
                    Image("NavBackBlack")
                        .resizable(capInsets: EdgeInsets(top: 0, leading: 15, bottom: 0, trailing: 5.5), resizingMode: .stretch)
                )
                .frame(height: 33)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, 8)
    }
}

/// OldOS `tool_bar_rectangle_button_larger_image_wide` (black).
struct PhotosBarButton: View {
    var title: String = ""
    var image: String? = nil
    var type: OldOSButtonType = .black
    let action: () -> Void

    var body: some View {
        Button {
            OldPhotosHaptics.tap()
            action()
        } label: {
            Group {
                if let image {
                    Image(image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22)
                        .padding([.leading, .trailing], 12)
                        .offset(x: 2, y: -1)
                } else {
                    Text(title)
                        .font(OldOSFont.bold(13.25))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.75), radius: 1, x: 0, y: -0.25)
                        .lineLimit(1)
                        .fixedSize()
                        .padding([.leading, .trailing], 11)
                }
            }
            .frame(height: 32)
            .oldOSInnerShadowBackground(
                RoundedRectangle(cornerRadius: 5.5),
                oldOSButtonGradient(type),
                radius: 0.8,
                offset: CGPoint(x: 0, y: 0.6),
                intensity: 0.7
            )
            .shadow(color: Color.white.opacity(0.28), radius: 0, x: 0, y: 0.8)
        }
        .buttonStyle(.plain)
        .frame(height: 32)
    }
}

/// OldOS `tool_bar_button`: a bare glyph, centred in its slot.
struct PhotosToolbarButton: View {
    let image: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Button {
                guard enabled else { return }
                OldPhotosHaptics.tap()
                action()
            } label: {
                Image(image)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(enabled ? 1 : 0.25)
            Spacer(minLength: 0)
        }
    }
}

/// `photo_destination_tool_bar` background: the same 65% black glass.
struct PhotosToolbarBackground: View {
    var body: some View {
        LinearGradient(oldOS: OldPhotosBlackChrome.translucentBar)
            .oldOSInnerShadowBottom(color: OldPhotosBlackChrome.highlight, radius: 0.025)
            .oldOSBorder(width: 0.95, edges: [.top], color: .black)
            .opacity(OldPhotosBlackChrome.translucentOpacity)
    }
}

// MARK: - Tab bar

/// The 57pt opaque black tab bar of `PhotosTabView`, extended behind the
/// home indicator.
struct PhotosTabBar: View {
    @EnvironmentObject private var navigator: PhotosNavigator
    let bottomInset: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(PhotosTab.allCases) { tab in
                        PhotosTabButton(tab: tab, selected: navigator.tab == tab, width: geometry.size.width / 2) {
                            navigator.select(tab)
                        }
                    }
                }
                .frame(height: 55)
                .frame(maxHeight: .infinity)
            }
            .frame(height: 57)
            Color.clear.frame(height: bottomInset)
        }
        .background(
            VStack(spacing: 0) {
                LinearGradient(oldOS: OldPhotosBlackChrome.tabBar).frame(height: 57)
                OldPhotosBlackChrome.tabBarBottom
            }
        )
    }
}

/// OldOS `TabButton_Photos`.
struct PhotosTabButton: View {
    let tab: PhotosTab
    let selected: Bool
    let width: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if selected {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: max(width - 5, 0), height: 51)
                        .blendMode(.screen)
                    VStack(spacing: 2) {
                        ZStack {
                            glyph(width: 30.5, height: 30.5)
                                .overlay(LinearGradient(oldOS: [.oldOS(205, 233, 249), .oldOS(75, 220, 251)]))
                                .mask(glyph(width: 30.5, height: 30.5))
                                .offset(y: -0.5)
                            glyph(width: 30, height: 30)
                                .overlay(
                                    LinearGradient(oldOS: [
                                        OldOSStop(.oldOS(197, 210, 229), 0),
                                        OldOSStop(.oldOS(99, 162, 216), 0.47),
                                        OldOSStop(.oldOS(0, 145, 230), 0.49),
                                        OldOSStop(.oldOS(21, 197, 252), 1)
                                    ])
                                    .rotationEffect(.degrees(-15))
                                    .frame(width: 40, height: 30)
                                    .brightness(0.095)
                                )
                                .mask(glyph(width: 30, height: 30))
                                .shadow(color: Color.black.opacity(0.6), radius: 2.5, x: 0, y: 2.5)
                        }
                        Text(tab.title)
                            .font(OldOSFont.bold(11))
                            .foregroundColor(.white)
                    }
                } else {
                    VStack(spacing: 2) {
                        glyph(width: 30, height: 30)
                            .overlay(LinearGradient(oldOS: [.oldOS(157, 157, 157), .oldOS(89, 89, 89)]))
                            .mask(glyph(width: 30, height: 30))
                            .shadow(color: Color.black.opacity(0.75), radius: 0, x: 0, y: -1)
                        Text(tab.title)
                            .font(OldOSFont.bold(11))
                            .foregroundColor(.oldOS(168, 168, 168))
                    }
                }
            }
            .frame(width: width, height: 55)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func glyph(width: CGFloat, height: CGFloat) -> some View {
        Image(tab.iconName)
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: width, height: height)
    }
}

// MARK: - Action sheet

/// OldOS `photo_video_share_view`: the black iOS 6 sheet with silver
/// buttons (red for destructive) and the black Cancel button.
struct PhotosActionSheet: View {
    var title: String? = nil
    let buttons: [PhotosSheetButton]
    var bottomInset: CGFloat = 0
    let onCancel: () -> Void

    @State private var shown = false

    private var titleHeight: CGFloat { title == nil ? 0 : 34 }

    private func height(_ available: CGFloat) -> CGFloat {
        min(30 + 28 + titleHeight + CGFloat(buttons.count) * 55 + 50 + 35 + bottomInset, available * 0.92)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.35)
                    .contentShape(Rectangle())
                    .onTapGesture { onCancel() }

                ZStack {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(LinearGradient(oldOS: [Color.oldOS(101, 100, 100, 0.88), Color.oldOS(31, 30, 30, 0.88)]))
                            .oldOSInnerShadowBottom(color: Color.white.opacity(0.98), radius: 0.1)
                            .oldOSBorder(width: 1, edges: [.top], color: .black)
                            .frame(height: 30)
                        Rectangle()
                            .fill(LinearGradient(oldOS: [Color.oldOS(21, 20, 20, 0.88), Color.black.opacity(0.9)]))
                    }

                    VStack(spacing: 0) {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {
                                if let title {
                                    Text(title)
                                        .font(OldOSFont.regular(15))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 25)
                                        .frame(height: titleHeight)
                                        .padding(.top, 20)
                                }
                                ForEach(Array(buttons.enumerated()), id: \.element.id) { index, button in
                                    sheetButton(button)
                                        .padding(.top, index == 0 && title == nil ? 28 : 2.5)
                                        .padding(.bottom, 2.5)
                                }
                            }
                        }
                        cancelButton
                            .padding(.top, 10)
                            .padding(.bottom, 25 + bottomInset)
                    }
                }
                .frame(height: height(geometry.size.height))
                .offset(y: shown ? 0 : height(geometry.size.height))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 0.3)) { shown = true }
        }
    }

    private func bevel<Inner: View>(dimmed: Bool = false, @ViewBuilder inner: () -> Inner) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(oldOS: [.oldOS(3, 3, 3), .oldOS(21, 21, 21), .oldOS(32, 32, 32)]))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(LinearGradient(oldOS: [.oldOS(83, 83, 83), .oldOS(143, 143, 143)]), lineWidth: 0.5)
                )
                .opacity(dimmed ? 0.6 : 1)
            inner()
        }
        .padding([.leading, .trailing], 25)
        .frame(minHeight: 50, maxHeight: 50)
    }

    private func sheetButton(_ button: PhotosSheetButton) -> some View {
        Button {
            OldPhotosHaptics.tap()
            button.action()
        } label: {
            bevel {
                if button.destructive {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(oldOSButtonGradient(.red))
                        .oldOSAddBorder(LinearGradient(oldOS: [Color.white.opacity(0.9), Color.white.opacity(0.25)]), width: 0.4, cornerRadius: 9)
                        .padding(3)
                    Text(button.title)
                        .font(OldOSFont.bold(18))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.6), radius: 0, x: 0, y: -0.6)
                        .lineLimit(1)
                } else {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(LinearGradient(oldOS: [
                            OldOSStop(.oldOS(235, 235, 236), 0),
                            OldOSStop(.oldOS(208, 209, 211), 0.52),
                            OldOSStop(.oldOS(192, 193, 196), 0.52),
                            OldOSStop(.oldOS(192, 193, 196), 1)
                        ]))
                        .oldOSAddBorder(LinearGradient(oldOS: [Color.white.opacity(0.9), Color.white.opacity(0.25)]), width: 0.4, cornerRadius: 9)
                        .padding(3)
                    Text(button.title)
                        .font(OldOSFont.bold(18))
                        .foregroundColor(.black)
                        .shadow(color: Color.white.opacity(0.9), radius: 0, x: 0, y: 0.9)
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var cancelButton: some View {
        Button {
            OldPhotosHaptics.tap()
            onCancel()
        } label: {
            bevel(dimmed: true) {
                RoundedRectangle(cornerRadius: 9)
                    .fill(LinearGradient(oldOS: [
                        OldOSStop(.oldOS(124, 124, 124), 0),
                        OldOSStop(.oldOS(26, 26, 26), 0.50),
                        OldOSStop(.oldOS(0, 0, 0), 0.53),
                        OldOSStop(.oldOS(0, 0, 0), 1)
                    ]))
                    .oldOSAddBorder(LinearGradient(oldOS: [Color.gray.opacity(0.9), Color.gray.opacity(0.35)]), width: 0.4, cornerRadius: 9)
                    .padding(3)
                    .opacity(0.6)
                Text("Cancel")
                    .font(OldOSFont.bold(18))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.9), radius: 0, x: 0, y: -0.9)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
