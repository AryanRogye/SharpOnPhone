//
//  CameraInfoStore.swift
//  SharpOnPhoneModels
//
//  Created by Aryan Rogye on 7/28/26.
//

import Foundation

public enum SavedStoreError: LocalizedError {
    case projectNameAlreadyExists
    case couldNotCreateProjectFolder(String)
    case copyFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .projectNameAlreadyExists:
            return "A project with this name already exists."
        case .couldNotCreateProjectFolder(let message):
            return message
        case .copyFailed(let message):
            return message
        }
    }
}


public actor CameraInfoStore {
    public let folderName: String = "CameraInfo"
    
    public init() {
        
    }
}

// MARK: - Create
extension CameraInfoStore {
    public func createNewProject(
        named name: String,
        withInfo cameraInfo: [ARCameraInfo],
        videoUrl: URL
    ) throws {
        try createBaseDirIfNeeded()
        
        /// create the project path name, which would be the foldername/project_name
        let projectPath = URL.documentsDirectory.appending(
            path: "\(folderName)/\(name)"
        )
        if directoryExists(at: projectPath) {
            throw SavedStoreError.projectNameAlreadyExists
        }
        
        /// projectFileName would be the name of the file stored
        let projectFileName = videoUrl.lastPathComponent
        let projectURL: URL = projectPath.appending(path: projectFileName)
        
        /// create the directory
        do {
            try FileManager.default.createDirectory(
                atPath: projectPath.path,
                withIntermediateDirectories: true
            )
        } catch {
            throw SavedStoreError.couldNotCreateProjectFolder("Couldnt Create Project Folder")
        }
        
        /// move the project video file to the folder
        do {
            try FileManager.default.moveItem(at: videoUrl, to: projectURL)
        } catch {
            /// if something goes wrong delete the project, as anything
            /// going wrong during init would cause corrupted state
            /// its ok right now to swallow the error
            try? self.deleteProject(named: name)
            throw SavedStoreError.couldNotCreateProjectFolder("Couldnt Copy Video File")
        }
        
        /// convert our [ARCameraInfo] -> [ARCameraInfoCodableRepresentation]
        let codableRepresentation: [ARCameraInfoCodableRepresentation] = cameraInfo.map(\.codableRepresentation)
        guard let data = try? JSONEncoder().encode(codableRepresentation) else {
            /// swallow error and delete project
            try? self.deleteProject(named: name)
            throw SavedStoreError.couldNotCreateProjectFolder("Couldnt Encode CameraInfo to Json")
        }
        
        do {
            let jsonURL = projectPath.appending(path: "metadata.json")
            try data.write(to: jsonURL)
        } catch {
            /// swallow error and delete project
            try? self.deleteProject(named: name)
            throw SavedStoreError.couldNotCreateProjectFolder("Couldnt Write Json Metadata")
        }
    }
}

// MARK: - Get All Projects
extension CameraInfoStore {
    public struct SavedProject: Identifiable {
        public let id = UUID()
        public let name: String
        public let videoURL: URL
        public let cameraInfo: [ARCameraInfo]
    }
    
    public func getAllProjects() throws -> [SavedProject] {
        let baseURL = URL.documentsDirectory.appending(path: folderName)
        
        guard let folders = try? FileManager.default.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return []
        }
        
        var results: [SavedProject] = []
        
        for folder in folders {
            guard (try? folder.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            
            let jsonURL = folder.appending(path: "metadata.json")
            guard let data = try? Data(contentsOf: jsonURL),
                  let codable = try? JSONDecoder().decode([ARCameraInfoCodableRepresentation].self, from: data)
            else { continue }

            guard let files = try? FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.isRegularFileKey]
            ),
                  let videoURL = files.first(where: { url in
                      let isRegularFile = (
                          try? url.resourceValues(
                              forKeys: [.isRegularFileKey]
                          )
                      )?.isRegularFile == true
                      
                      return isRegularFile
                      && ["mov", "mp4", "m4v"].contains(
                          url.pathExtension.lowercased()
                      )
                  })
            else { continue }
            
            let cameraInfo = codable.map(ARCameraInfo.init(from:))
            results.append(
                SavedProject(
                    name: folder.lastPathComponent,
                    videoURL: videoURL,
                    cameraInfo: cameraInfo
                )
            )
        }
        
        return results
    }
}

// MARK: - Delete
extension CameraInfoStore {
    public func deleteProject(
        named name: String
    ) throws {
        let projectPath = URL.documentsDirectory.appending(
            path: "\(folderName)/\(name)"
        )
        try FileManager.default.removeItem(at: projectPath)
    }
}

// MARK: - Create Base Directory
extension CameraInfoStore {
    private func createBaseDirIfNeeded() throws {
        let folder = URL.documentsDirectory.appending(path: folderName)
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: folder.path,
            isDirectory: &isDirectory
        )
        
        if exists && !isDirectory.boolValue {
            /// delete it and make a folder
            try FileManager.default.removeItem(at: folder)
        }
        
        /// if it doesnt exist or it exists but its not a directory,
        /// this lets the top fall through
        if !exists || (exists && !isDirectory.boolValue) {
            // Create the folder if it didn't exist, or if we just deleted a conflicting file
            try FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
}

// MARK: - Directory Exists
extension CameraInfoStore {
    public func directoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(
            atPath: url.path(),
            isDirectory: &isDirectory
        ) {
            /// this means it doesnt exist at all so just return false
            return false
        }
        return isDirectory.boolValue
    }
}
