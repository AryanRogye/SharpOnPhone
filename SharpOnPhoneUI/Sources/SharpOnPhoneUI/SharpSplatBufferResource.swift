import RealityKit

/// The splat payload exchanged between the app and `SharpOnPhoneUI`.
///
/// RealityKit's Gaussian splat APIs are not present in the iOS Simulator SDK.
/// Keeping that SDK difference behind this name lets SwiftUI compile previews
/// without changing the type used by device builds.
#if targetEnvironment(simulator)
public struct SharpSplatBufferResource: Sendable {
    public init() {}
}
#else
public typealias SharpSplatBufferResource = GaussianSplatResource.BufferResource
#endif
