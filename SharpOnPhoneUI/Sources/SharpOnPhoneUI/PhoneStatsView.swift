//
//  PhoneStatsView.swift
//  SharpOnPhoneUI
//
//  Created by Aryan Rogye on 7/28/26.
//

import SwiftUI
import Foundation
import Darwin

struct PhoneStatsView: View {
    
    @State private var thermalState = ProcessInfo.processInfo.thermalState
    @State private var thermalStateToken: (any NSObjectProtocol)?
    
    @State private var memoryUsage: UInt64 = 0
    @State private var cpuUsage: Double = 0
    
    @State private var statsTask: Task<Void, Never>?
    
    private var thermalIcon: String {
        switch thermalState {
        case .nominal: return "checkmark.circle.fill"
        case .fair: return "flame"
        case .serious: return "flame.fill"
        case .critical: return "exclamationmark.triangle.fill"
        @unknown default: return "questionmark.circle"
        }
    }
    
    private var thermalLabel: String {
        switch thermalState {
        case .nominal: return "Normal"
        case .fair: return "Elevated"
        case .serious: return "Hot"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
    
    private var thermalColor: Color {
        switch thermalState {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .gray
        }
    }

    
    var body: some View {
        VStack {
            HStack(spacing: 14) {
                StatPill(
                    icon: thermalIcon,
                    label: "Thermal",
                    value: thermalLabel,
                    tint: thermalColor
                )
                
                Divider()
                    .frame(height: 20)
                    .background(.white.opacity(0.2))
                
                StatPill(
                    icon: "memorychip",
                    label: "Memory",
                    value: memoryUsage.formattedMemory,
                    tint: .white
                )
                
                Divider()
                    .frame(height: 20)
                    .background(.white.opacity(0.2))
                
                StatPill(
                    icon: "cpu",
                    label: "CPU",
                    value: cpuUsage.formatted(.number.precision(.fractionLength(1))) + "%",
                    tint: cpuUsage > 80 ? .orange : .white
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.black.opacity(0.4), in: Capsule())
            .foregroundStyle(.white)
            
            Spacer()
        }
        .onAppear {
            observeProcessInfo()
            startStatsMonitoring()
        }
        .onDisappear {
            closeObservations()
            stopStatsMonitoring()
        }
    }
    
    private func observeProcessInfo() {
        thermalStateToken = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: ProcessInfo.processInfo,
            queue: .main
        ) { _ in
            Task { @MainActor in
                thermalState = ProcessInfo.processInfo.thermalState
            }
        }
    }
    
    private func closeObservations() {
        if let thermalStateToken {
            NotificationCenter.default.removeObserver(thermalStateToken)
            self.thermalStateToken = nil
        }
    }
    
    private func startStatsMonitoring() {
        statsTask?.cancel()
        
        statsTask = Task {
            while !Task.isCancelled {
                let newMemoryUsage = PhoneStats.currentMemoryUsage()
                let newCPUUsage = PhoneStats.currentCPUUsage()
                
                await MainActor.run {
                    memoryUsage = newMemoryUsage
                    cpuUsage = newCPUUsage
                }
                
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
    
    private func stopStatsMonitoring() {
        statsTask?.cancel()
        statsTask = nil
    }
}

private struct StatPill: View {
    let icon: String
    let label: String
    let value: String
    let tint: Color
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .font(.system(size: 11))
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
            }
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

// MARK: - Phone Stats

private enum PhoneStats {
    
    /// The app's current physical memory footprint.
    static func currentMemoryUsage() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size
            / MemoryLayout<natural_t>.size
        )
        
        let result = withUnsafeMutablePointer(to: &info) { infoPointer in
            infoPointer.withMemoryRebound(
                to: integer_t.self,
                capacity: Int(count)
            ) { reboundPointer in
                task_info(
                    mach_task_self_,
                    task_flavor_t(TASK_VM_INFO),
                    reboundPointer,
                    &count
                )
            }
        }
        
        guard result == KERN_SUCCESS else {
            return 0
        }
        
        return info.phys_footprint
    }
    
    /// The combined CPU usage of the app's active threads.
    static func currentCPUUsage() -> Double {
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        
        let result = task_threads(
            mach_task_self_,
            &threadList,
            &threadCount
        )
        
        guard
            result == KERN_SUCCESS,
            let threadList
        else {
            return 0
        }
        
        defer {
            let size = vm_size_t(
                Int(threadCount)
                * MemoryLayout<thread_t>.stride
            )
            
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: threadList)),
                size
            )
        }
        
        var totalCPUUsage: Double = 0
        
        for index in 0..<Int(threadCount) {
            var threadInfo = thread_basic_info()
            var threadInfoCount = mach_msg_type_number_t(
                THREAD_INFO_MAX
            )
            
            let threadInfoResult = withUnsafeMutablePointer(
                to: &threadInfo
            ) { threadInfoPointer in
                threadInfoPointer.withMemoryRebound(
                    to: integer_t.self,
                    capacity: Int(threadInfoCount)
                ) { reboundPointer in
                    thread_info(
                        threadList[index],
                        thread_flavor_t(THREAD_BASIC_INFO),
                        reboundPointer,
                        &threadInfoCount
                    )
                }
            }
            
            guard threadInfoResult == KERN_SUCCESS else {
                continue
            }
            
            let isIdle =
            threadInfo.flags & TH_FLAGS_IDLE
            == TH_FLAGS_IDLE
            
            guard !isIdle else {
                continue
            }
            
            totalCPUUsage += Double(threadInfo.cpu_usage)
            / Double(TH_USAGE_SCALE)
            * 100
        }
        
        return totalCPUUsage
    }
}

// MARK: - Formatting

private extension UInt64 {
    
    var formattedMemory: String {
        ByteCountFormatter.string(
            fromByteCount: Int64(self),
            countStyle: .memory
        )
    }
}
