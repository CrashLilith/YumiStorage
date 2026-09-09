import SwiftUI

/// A small compatibility layer for custom surfaces that should participate in
/// Apple's Liquid Glass refresh without making older supported systems opaque.
struct YumiGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 22
    var tint: Color? = nil

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(
                .regular.tint(tint ?? .accentColor),
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            content.background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
    }
}

extension View {
    func yumiGlass(cornerRadius: CGFloat = 22, tint: Color? = nil) -> some View {
        modifier(YumiGlassModifier(cornerRadius: cornerRadius, tint: tint))
    }
}
