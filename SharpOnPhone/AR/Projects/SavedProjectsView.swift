//
//  SavedProjectsView.swift
//  SharpOnPhone
//
//  Created by Aryan Rogye on 7/28/26.
//

import SwiftUI
import SharpOnPhoneModels
import SharpOnPhoneUI

struct SavedProjectsView: View {
    
    let unloadMemory: () -> Void
    public var onRunSharp: (UIImage, Double) async throws -> SharpSplatBufferResource
    @Binding var error: String?
    @Binding var showError: Bool
    
    @State var savedProjects: [CameraInfoStore.SavedProject] = []
    let cameraInfoStore = CameraInfoStore()
    @State private var isLoadingProjects: Bool = false
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                SavedProjectsHeader(
                    projectCount: savedProjects.count
                )
                
                if isLoadingProjects && savedProjects.isEmpty {
                    LoadingSavedProjectsView()
                } else if savedProjects.isEmpty {
                    EmptySavedProjectsView()
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(savedProjects) { project in
                            NavigationLink {
                                RecordedOverviewView(
                                    onRunSharp: onRunSharp,
                                    unloadMemory: unloadMemory,
                                    savedProject: project
                                )
                            } label: {
                                SavedProjectRow(
                                    project: project
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .contentMargins(.top, 76, for: .scrollContent)
        .scrollIndicators(.hidden)
        .background(Color(.systemGroupedBackground))
        .task {
            guard !isLoadingProjects else {
                return
            }
            
            isLoadingProjects = true
            defer {
                isLoadingProjects = false
            }
            
            do {
                savedProjects = try await cameraInfoStore.getAllProjects()
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }
}

struct SavedProjectsHeader: View {
    
    let projectCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Projects")
                .font(.largeTitle.bold())
            
            Text(
                projectCount == 1
                ? "1 saved recording"
                : "\(projectCount) saved recordings"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }
}

struct SavedProjectRow: View {
    
    let project: CameraInfoStore.SavedProject
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.accentColor.gradient)
                
                Image(systemName: "video.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }
            .frame(width: 52, height: 52)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(project.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                Label(
                    "\(project.cameraInfo.count) camera samples",
                    systemImage: "viewfinder"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            
            Spacer(minLength: 8)
            
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the recorded project")
    }
}

struct EmptySavedProjectsView: View {
    
    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
            .frame(width: 84, height: 84)
            
            VStack(spacing: 7) {
                Text("No Projects Yet")
                    .font(.title3.bold())
                
                Text("Record a scene and save it to build your project library.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
        .accessibilityElement(children: .combine)
    }
}

struct LoadingSavedProjectsView: View {
    
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            
            Text("Loading projects")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 72)
        .accessibilityElement(children: .combine)
    }
}
