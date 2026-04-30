import Foundation
import UIKit
import AudioToolbox
import CoreMotion
import QuartzCore
import CoreHaptics

final class AppBadgePhysicsAnimator {

    static func play(
        on badge: UIView?,
        in rootView: UIView,
        completion: (() -> Void)? = nil
    ) {
        guard let badge else { return }

        badge.superview?.layoutIfNeeded()
        rootView.layoutIfNeeded()
        rootView.window?.layoutIfNeeded()

        let startFrame: CGRect
        if let superview = badge.superview {
            startFrame = superview.convert(badge.frame, to: rootView)
        } else {
            startFrame = badge.frame
        }

        let startCenter = CGPoint(x: startFrame.midX, y: startFrame.midY)
        let originalCenter = startCenter

        guard let animatedBadge = badge.snapshotView(afterScreenUpdates: true) else {
            completion?()
            return
        }

        animatedBadge.frame = startFrame
        animatedBadge.transform = badge.transform
        rootView.addSubview(animatedBadge)
        badge.isHidden = true

        let originalTransform = animatedBadge.transform
        let bottomY = rootView.bounds.height - animatedBadge.bounds.height / 2

        let impact: UIImpactFeedbackGenerator
        if #available(iOS 13.0, *) {
            impact = UIImpactFeedbackGenerator(style: .rigid)
        } else {
            impact = UIImpactFeedbackGenerator(style: .heavy)
        }
        impact.prepare()

        let driftX = TiltManager.shared.driftOffset(maxOffset: 60)

        UIView.animate(
            withDuration: 0.95,
            delay: 0,
            options: [.curveLinear],
            animations: {
                animatedBadge.center = CGPoint(x: startCenter.x + driftX, y: bottomY)
                animatedBadge.transform = CGAffineTransform(
                    rotationAngle: CGFloat.random(in: -0.35...0.35)
                )
            },
            completion: { _ in
                if #available(iOS 13.0, *) {
                    impact.impactOccurred(intensity: 1.0)
                } else {
                    // Fallback on earlier versions
                    impact.impactOccurred()
                }
                AudioServicesPlaySystemSound(1519)

                playBounce(
                    badge: animatedBadge,
                    originalBadge: badge,
                    root: rootView,
                    originalCenter: originalCenter,
                    originalTransform: originalTransform,
                    completion: completion
                )
            }
        )
    }

    private static func playBounce(
        badge: UIView,
        originalBadge: UIView,
        root: UIView,
        originalCenter: CGPoint,
        originalTransform: CGAffineTransform,
        completion: (() -> Void)?
    ) {

        var velocity: CGFloat = CGFloat.random(in: -18 ... -14)
        var velocityX: CGFloat =
            CGFloat(TiltManager.shared.gravityX) * CGFloat.random(in: 6 ... 14)
        let gravity: CGFloat = 1.2
        let damping: CGFloat = 0.72
        var bounceCount = 0

        let impact: UIImpactFeedbackGenerator
        if #available(iOS 13.0, *) {
            impact = UIImpactFeedbackGenerator(style: .soft)
        } else {
            impact = UIImpactFeedbackGenerator(style: .heavy)
        }
        impact.prepare()

        var displayLink: CADisplayLink?
        var lastTimestamp: CFTimeInterval = 0

        displayLink = CADisplayLink(target: BlockTarget { link in

            if lastTimestamp == 0 {
                lastTimestamp = link.timestamp
                return
            }

            let dt = CGFloat(link.timestamp - lastTimestamp)
            lastTimestamp = link.timestamp

            velocity += gravity * (dt * 60)
            badge.center.y += velocity * (dt * 60)
            badge.center.x += velocityX * (dt * 60)

            if badge.center.y >= root.bounds.height - badge.bounds.height / 2 {

                badge.center.y = root.bounds.height - badge.bounds.height / 2
                velocity = velocity * -damping
                velocityX *= 0.82

                bounceCount += 1

                let intensity = max(0.25, 0.7 - CGFloat(bounceCount) * 0.12)
                if #available(iOS 13.0, *) {
                    impact.impactOccurred(intensity: intensity)
                }

                AudioServicesPlaySystemSound(1519)

                if abs(velocity) < 1.8 {

                    displayLink?.invalidate()
                    displayLink = nil

                    badge.transform = .identity

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        pullBack(
                            badge: badge,
                            originalBadge: originalBadge,
                            originalCenter: originalCenter,
                            originalTransform: originalTransform,
                            completion: completion
                        )
                    }
                    return
                }
            }

            let minX = badge.bounds.width / 2
            let maxX = root.bounds.width - badge.bounds.width / 2
            badge.center.x = max(minX, min(maxX, badge.center.x))

            badge.transform = CGAffineTransform(
                rotationAngle: velocity * 0.01 + CGFloat.random(in: -0.03...0.03)
            )

        }, selector: #selector(BlockTarget.invoke))

        displayLink?.preferredFramesPerSecond = 0
        displayLink?.add(to: .main, forMode: .common)
    }

    private static func pullBack(
        badge: UIView,
        originalBadge: UIView,
        originalCenter: CGPoint,
        originalTransform: CGAffineTransform,
        completion: (() -> Void)?
    ) {

        let light = UIImpactFeedbackGenerator(style: .light)
        light.prepare()

        let totalSteps: CGFloat = 70
        var stepProgress: CGFloat = 0
        var lastTimestamp: CFTimeInterval = 0
        var lastHapticBucket = -1
        var displayLink: CADisplayLink?

        let dx = originalCenter.x - badge.center.x
        let dy = originalCenter.y - badge.center.y

        displayLink = CADisplayLink(target: BlockTarget { link in

            if lastTimestamp == 0 {
                lastTimestamp = link.timestamp
                return
            }

            let dt = CGFloat(link.timestamp - lastTimestamp)
            lastTimestamp = link.timestamp

            // 保持原来 60fps 下的动画节奏，只是改成由 DisplayLink 驱动
            stepProgress += dt * 60

            if stepProgress >= totalSteps {

                displayLink?.invalidate()
                displayLink = nil

                UIView.animate(
                    withDuration: 0.4,
                    delay: 0,
                    usingSpringWithDamping: 0.7,
                    initialSpringVelocity: 0.6,
                    options: [],
                    animations: {
                        badge.center = originalCenter
                        badge.transform = originalTransform
                    },
                    completion: { _ in
                        if #available(iOS 13.0, *) {
                            light.impactOccurred(intensity: 0.5)
                        } else {
                            light.impactOccurred()
                        }
                        badge.removeFromSuperview()
                        originalBadge.isHidden = false
                        completion?()
                    }
                )

                return
            }

            let progress = stepProgress / totalSteps
            let ease = progress * progress

            badge.center.x += dx * 0.022 * ease
            badge.center.y += dy * 0.022 * ease

            let jitterX = CGFloat.random(in: -0.9...0.9)
            let jitterY = CGFloat.random(in: -0.9...0.9)

            badge.transform =
                CGAffineTransform(translationX: jitterX, y: jitterY)
                .rotated(by: CGFloat.random(in: -0.08...0.08))
                .scaledBy(
                    x: 1.0 + CGFloat.random(in: -0.03...0.03),
                    y: 1.0 + CGFloat.random(in: -0.03...0.03)
                )

            let currentBucket = Int(stepProgress) / 6
            if currentBucket > lastHapticBucket {
                lastHapticBucket = currentBucket

                if #available(iOS 13.0, *) {
                    MagneticHaptic.shared.playMagneticPull()
                } else {
                    light.impactOccurred()
                }
            }

        }, selector: #selector(BlockTarget.invoke))

        displayLink?.preferredFramesPerSecond = 0
        displayLink?.add(to: .main, forMode: .common)
    }
}

private final class TiltManager {

    static let shared = TiltManager()

    private let motion = CMMotionManager()
    private(set) var gravityX: Double = 0

    private init() {
        guard motion.isDeviceMotionAvailable else { return }

        motion.deviceMotionUpdateInterval = 1.0 / 30.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let g = data?.gravity else { return }
            self?.gravityX = g.x
        }
    }

    func driftOffset(maxOffset: CGFloat = 60) -> CGFloat {
        let x = CGFloat(gravityX)
        return max(-maxOffset, min(maxOffset, x * maxOffset))
    }
}

@available(iOS 13.0, *)
private final class MagneticHaptic {

    static let shared = MagneticHaptic()

    private var engine: CHHapticEngine?
    private var isEngineRunning = false

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        try? engine?.start()
        isEngineRunning = true
        engine?.stoppedHandler = { [weak self] _ in
            self?.isEngineRunning = false
        }

        engine?.resetHandler = { [weak self] in
            do {
                try self?.engine?.start()
                self?.isEngineRunning = true
            } catch {
                // ignore
            }
        }
    }

    private func ensureRunning() {
        guard let engine else { return }

        if !isEngineRunning {
            do {
                try engine.start()
                isEngineRunning = true
            } catch {
                // ignore
            }
        }
    }

    func playMagneticPull() {

        ensureRunning()

        guard
            let engine,
            CHHapticEngine.capabilitiesForHardware().supportsHaptics
        else { return }

        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.22)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.12)

        let continuous = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [intensity, sharpness],
            relativeTime: 0,
            duration: 0.32
        )

        let ramp = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0, value: 0.15),
                .init(relativeTime: 0.18, value: 0.55),
                .init(relativeTime: 0.32, value: 0.95)
            ],
            relativeTime: 0
        )

        let finalImpact = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: 1.0),
                .init(parameterID: .hapticSharpness, value: 0.9)
            ],
            relativeTime: 0.34
        )

        do {
            let pattern = try CHHapticPattern(
                events: [continuous, finalImpact],
                parameterCurves: [ramp]
            )

            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)

        } catch {
            // ignore
        }
    }
}

private final class BlockTarget {

    private let block: (CADisplayLink) -> Void

    init(_ block: @escaping (CADisplayLink) -> Void) {
        self.block = block
    }

    @objc func invoke(_ link: CADisplayLink) {
        block(link)
    }
}
