import SwiftUI

struct BackupSettingsView: View {
    @EnvironmentObject var wallpaperManager: WallpaperManager
    @State private var showingBackupAlert = false
    @State private var showingRestoreAlert = false
    @State private var showingDeleteAlert = false
    @State private var selectedBackup: Backup?
    @State private var backupError: Error?
    
    var body: some View {
        Form {
            Section(header: Text("Auto Backup")) {
                Toggle("Enable Auto Backup", isOn: $wallpaperManager.userSettings.backup.autoBackup)
                
                if wallpaperManager.userSettings.backup.autoBackup {
                    Picker("Backup Interval", selection: $wallpaperManager.userSettings.backup.backupInterval) {
                        Text("Daily").tag(TimeInterval(86400))
                        Text("Weekly").tag(TimeInterval(604800))
                        Text("Monthly").tag(TimeInterval(2592000))
                    }
                    
                    TextField("Backup Location", text: $wallpaperManager.userSettings.backup.backupLocation)
                    
                    Stepper("Max Backups: \(wallpaperManager.userSettings.backup.maxBackups)",
                           value: $wallpaperManager.userSettings.backup.maxBackups,
                           in: 1...10)
                }
            }
            
            Section(header: Text("Manual Backup")) {
                Button("Backup Now") {
                    do {
                        try wallpaperManager.createBackup()
                        showingBackupAlert = true
                    } catch {
                        backupError = error
                    }
                }
                
                Button("Restore from Backup...") {
                    showingRestoreAlert = true
                }
            }
            
            Section(header: Text("Backup History")) {
                List(wallpaperManager.getAvailableBackups()) { backup in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(backup.timestamp.formatted())
                            Text("\(backup.playlists.count) playlists, \(backup.wallpapers.count) wallpapers")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Restore") {
                            selectedBackup = backup
                            showingRestoreAlert = true
                        }
                        
                        Button("Delete") {
                            selectedBackup = backup
                            showingDeleteAlert = true
                        }
                    }
                }
            }
        }
        .padding()
        .alert("Backup Created", isPresented: $showingBackupAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your backup has been created successfully.")
        }
        .alert("Restore Backup", isPresented: $showingRestoreAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Restore") {
                if let backup = selectedBackup {
                    do {
                        try wallpaperManager.restoreFromBackup(id: backup.id)
                    } catch {
                        backupError = error
                    }
                }
            }
        } message: {
            if let backup = selectedBackup {
                Text("Are you sure you want to restore from the backup created on \(backup.timestamp.formatted())?")
            } else {
                Text("Please select a backup to restore from.")
            }
        }
        .alert("Delete Backup", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let backup = selectedBackup {
                    do {
                        try wallpaperManager.deleteBackup(id: backup.id)
                    } catch {
                        backupError = error
                    }
                }
            }
        } message: {
            if let backup = selectedBackup {
                Text("Are you sure you want to delete the backup created on \(backup.timestamp.formatted())?")
            }
        }
        .alert("Backup Error", isPresented: .constant(backupError != nil)) {
            Button("OK", role: .cancel) {
                backupError = nil
            }
        } message: {
            if let error = backupError {
                Text(error.localizedDescription)
            }
        }
    }
} 