//
//  AudioDeviceSelector.swift
//  Duophonic
//
//  Created by Juri Beforth on 19.12.25.
//

import SwiftUI

struct AudioDeviceSelectorView: View {
    @EnvironmentObject private var audioManager: AudioAggregateManager
    let role: AudioAggregateManager.Role
    @Binding var isExpanded: Bool
    @State private var isRefreshing = false
    @Namespace private var audioNamespace
    @State private var deviceListContentHeight: CGFloat = 0
    private let deviceListMaxHeight: CGFloat = 220
    private let deviceListFallbackHeight: CGFloat = 160

    private var currentDeviceListHeight: CGFloat {
        let measured =
            deviceListContentHeight > 0
            ? deviceListContentHeight : deviceListFallbackHeight
        return min(measured, deviceListMaxHeight)
    }

    private var currentDevice: AudioDevice? { audioManager.device(for: role) }

    private var currentDeviceName: String {
        if let currentDevice {
            return currentDevice.name
        }
        if let name = audioManager.selectedName(for: role) {
            return "\(name) (Not Connected)"
        }
        return "Not Connected"
    }

    var body: some View {
        VStack {
            if isExpanded {
                expandedView
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(
                                with: .scale(scale: 0.98)
                            ),
                            removal: .opacity.combined(
                                with: .scale(scale: 0.92)
                            )
                        )
                    )
            } else {
                controlSurface(cornerRadius: 20) {
                    collapsedView
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(
                                    with: .scale(scale: 0.98)
                                ),
                                removal: .opacity.combined(
                                    with: .scale(scale: 0.92)
                                )
                            )
                        )
                }
            }
        }
        .animation(
            .spring(response: 0.36, dampingFraction: 0.85),
            value: isExpanded
        )
    }

    private var collapsedView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(.ultraThinMaterial.opacity(0.4))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: currentDevice?.iconName ?? "speaker.slash")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(
                                currentDevice != nil ? Color.accentColor : Color.secondary
                            )
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(currentDeviceName)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    volumeSlider(compact: true)
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { withAnimation { isExpanded.toggle() } }
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: isExpanded ? "Hide Devices" : "Show Devices") {
                withAnimation { isExpanded.toggle() }
            }
        }
    }

    private var expandedView: some View {
        controlSurface(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 10) {
                collapsedView
                Divider().opacity(0.2)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        if audioManager.devices.isEmpty {
                            Text("No audio devices available")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            section(title: "Audio Devices") {
                                ForEach(audioManager.devices) { device in
                                    AudioDeviceRow(
                                        device: device,
                                        isSelected: audioManager.uid(for: role) == device.uid,
                                        action: {
                                            audioManager.select(device.uid, for: role)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.bottom, 4)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: DeviceListHeightKey.self,
                                value: proxy.size.height
                            )
                        }
                    )
                }
                .frame(height: currentDeviceListHeight)
                .frame(maxWidth: .infinity)
                .onPreferenceChange(DeviceListHeightKey.self) {
                    deviceListContentHeight = $0
                }

                Button(action: refreshDevices) {
                    HStack {
                        Spacer()
                        if isRefreshing {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .labelStyle(.titleAndIcon)
                                .font(.footnote)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func refreshDevices() {
        guard !isRefreshing else { return }
        isRefreshing = true
        audioManager.refreshDevices()
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            isRefreshing = false
        }
    }

    @ViewBuilder
    private func volumeSlider(compact: Bool) -> some View {
        let slider = Slider(
            value: Binding(
                get: { currentDevice?.volume ?? 0.5 },
                set: { audioManager.setVolume($0, for: role) }
            ),
            in: 0...1
        )
        .disabled(!(currentDevice?.supportsVolume ?? false))
        .tint(.accentColor)
        .accessibilityLabel("\(currentDevice?.name ?? "Output") Volume")

        HStack(spacing: 8) {
            slider
        }
        .opacity(currentDevice == nil ? 0.45 : 1)
        .animation(
            .easeInOut(duration: 0.2),
            value: currentDevice?.supportsVolume
        )
        .padding(.top, compact ? 0 : 4)
    }

    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            content()
        }
    }

    @ViewBuilder
    private func controlSurface<Content: View>(
        cornerRadius: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.clear)
                    .matchedGeometryEffect(
                        id: "audioBackground",
                        in: audioNamespace
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.06))
                    .matchedGeometryEffect(
                        id: "audioBorder",
                        in: audioNamespace
                    )
            )
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 6)
    }
}

private struct AudioDeviceRow: View {
    let device: AudioDevice
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: device.iconName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(
                        isSelected ? Color.accentColor : Color.secondary
                    )
                    .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.callout)
                    Text(device.category.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Circle().fill(Color.accentColor))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.white.opacity(0.14)
                            : Color.white.opacity(0.04)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct DeviceListHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#if DEBUG
    #Preview("Audio Device Control") {
        VStack(alignment: .leading, spacing: 16) {
            AudioDeviceSelectorView(role: .primary, isExpanded: .constant(true))
                .padding()
        }
        .frame(width: 320, height: 320)
        .background(Color.black)
        .environmentObject(AudioAggregateManager.preview)
    }
#endif
