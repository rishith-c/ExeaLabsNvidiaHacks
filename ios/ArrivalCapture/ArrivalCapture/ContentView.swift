import RoomPlan
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ScanStore
    @AppStorage("serverURL") private var serverURL = ""
    @AppStorage("roomName") private var roomName = "kitchen"
    @AppStorage("recordFrames") private var recordFrames = true
    @State private var capturing = false
    @State private var pendingDeletion: Scan?
    @State private var pingText: String?
    @State private var pinging = false

    var body: some View {
        NavigationStack {
            List {
                ArrivalFieldHeader()
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowSeparator(.hidden)

                Section {
                    LabeledContent("Room name") {
                        TextField("kitchen_a", text: $roomName)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityLabel("Room name")
                    }
                    Toggle("Record RGB-D frames", isOn: $recordFrames)
                    Button {
                        capturing = true
                    } label: {
                        HStack {
                            Label("Scan room", systemImage: "viewfinder")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(ArrivalTheme.signal)
                                .accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(ArrivalActionStyle(primary: true))
                    .disabled(!RoomCaptureSession.isSupported)
                } header: {
                    ArrivalSectionHeading(number: "01", title: "New survey")
                } footer: {
                    if RoomCaptureSession.isSupported {
                        Text("Saved as \(ScanStore.roomID(roomName)). Walk the room slowly and point at every wall, counter and appliance."
                             + (recordFrames ? " Frames are photos of the room: record only with the occupant's consent, and look through them for people, screens, documents and mail before sharing." : ""))
                    } else {
                        Text("RoomPlan needs a LiDAR device: iPhone 12 Pro or newer Pro, or iPad Pro 2020+.")
                    }
                }
                .listRowBackground(ArrivalTheme.panel)

                Section {
                    if store.scans.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: "square.dashed")
                                .font(.title2)
                                .foregroundStyle(ArrivalTheme.signalInk)
                                .accessibilityHidden(true)
                            Text("Your room starts here.")
                                .font(ArrivalTheme.heading(.title3))
                            Text("Saved surveys stay on this device. Open one to review, share or upload it.")
                                .font(.subheadline)
                                .foregroundStyle(ArrivalTheme.muted)
                        }
                        .padding(.vertical, 12)
                    }
                    ForEach(store.scans) { scan in
                        NavigationLink(value: scan.id) {
                            ScanRow(scan: scan)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", systemImage: "trash") {
                                pendingDeletion = scan
                            }
                            .tint(.red)
                        }
                    }
                } header: {
                    ArrivalSectionHeading(number: "02", title: "Saved surveys · \(store.scans.count)")
                }
                .listRowBackground(ArrivalTheme.panel)

                Section {
                    TextField("http://192.168.1.20:8000", text: $serverURL)
                        .font(ArrivalTheme.label(.subheadline))
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Arrival server URL")
                    Button {
                        Task { await ping() }
                    } label: {
                        HStack {
                            Text("Test connection")
                            Spacer()
                            if pinging {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.right")
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .buttonStyle(ArrivalActionStyle())
                    .disabled(serverURL.isEmpty || pinging)
                    if let pingText {
                        Text(pingText)
                            .font(.footnote)
                            .foregroundStyle(ArrivalTheme.muted)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                } header: {
                    ArrivalSectionHeading(number: "03", title: "Arrival server")
                } footer: {
                    Text("Connect when you're ready to turn a scan into a twin. On a Mac on the same Wi-Fi, run `python -m arrival serve --host 0.0.0.0` and `python -m arrival work`. The serve command prints this URL.")
                }
                .listRowBackground(ArrivalTheme.panel)
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(16)
            .scrollContentBackground(.hidden)
            .listRowSeparatorTint(ArrivalTheme.rule)
            .foregroundStyle(ArrivalTheme.ink)
            .background(ArrivalPaper())
            .tint(ArrivalTheme.signalInk)
            .navigationTitle("Field notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ArrivalTheme.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .alert("Delete saved survey?", isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ), presenting: pendingDeletion) { scan in
                Button("Delete survey", role: .destructive) {
                    store.delete(scan)
                    pendingDeletion = nil
                }
                Button("Cancel", role: .cancel) { pendingDeletion = nil }
            } message: { scan in
                Text("This permanently deletes \(scan.roomName) and its capture files from this device. Copies already shared or uploaded to a server remain there.")
            }
            .navigationDestination(for: String.self) { ScanDetailView(scanID: $0) }
            .fullScreenCover(isPresented: $capturing) {
                CaptureScreen(roomName: ScanStore.roomID(roomName), recordFrames: recordFrames)
                    .environmentObject(store)
            }
        }
        .tint(ArrivalTheme.signalInk)
    }

    private func ping() async {
        pinging = true
        defer { pinging = false }
        do {
            try await ArrivalAPI.ping(server: serverURL)
            pingText = "Connected."
        } catch {
            pingText = "Not reachable: \(error.localizedDescription) (the first try can fail while iOS asks for Local Network access)"
        }
    }
}

private struct ScanRow: View {
    let scan: Scan

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(scan.roomName).font(ArrivalTheme.heading(.headline))
            Text(scan.created.formatted(date: .abbreviated, time: .shortened))
                .font(ArrivalTheme.label())
                .foregroundStyle(ArrivalTheme.muted)
            if let status = scan.jobStatus {
                Text(status)
                    .font(ArrivalTheme.label())
                    .foregroundStyle(ArrivalTheme.signalInk)
            }
        }
    }
}

struct ScanDetailView: View {
    let scanID: String

    @EnvironmentObject private var store: ScanStore
    @AppStorage("serverURL") private var serverURL = ""
    @State private var uploading = false
    @State private var errorText: String?
    @State private var includeFrames = true
    @State private var zipping = false

    var body: some View {
        if let scan = store.scans.first(where: { $0.id == scanID }) {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SURVEY RECORD")
                            .font(ArrivalTheme.label())
                            .tracking(1.5)
                            .foregroundStyle(ArrivalTheme.signalInk)
                        Text(scan.roomName)
                            .font(ArrivalTheme.heading(.largeTitle))
                        Text("A room captured. A twin to build.")
                            .font(.subheadline)
                            .foregroundStyle(ArrivalTheme.muted)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                Section {
                    LabeledContent("Room", value: scan.roomName)
                    LabeledContent("Scanned", value: scan.created.formatted(date: .abbreviated, time: .shortened))
                    ForEach(store.files(scan), id: \.self) { url in
                        LabeledContent(url.lastPathComponent, value: fileSize(url))
                    }
                    if let n = scan.frameCount {
                        LabeledContent("RGB-D frames", value: "\(n) (\(scan.heldoutCount ?? 0) held out)")
                    } else if let note = scan.framesNote {
                        Text(note).font(.footnote).foregroundStyle(.secondary)
                    }
                    if zipping {
                        HStack { Text("Zipping frames"); Spacer(); ProgressView() }
                    }
                    ShareLink(items: store.files(scan)) {
                        Label("Share / AirDrop", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(ArrivalActionStyle())
                    .disabled(zipping || (store.hasFrames(scan)
                        && !FileManager.default.fileExists(atPath: store.framesZipURL(scan).path)))
                } header: {
                    ArrivalSectionHeading(number: "01", title: "Capture files")
                }
                .listRowBackground(ArrivalTheme.panel)

                Section {
                    if store.hasFrames(scan) {
                        Toggle("Include RGB-D frames", isOn: $includeFrames)
                    }
                    Button {
                        Task { await upload(scan) }
                    } label: {
                        HStack {
                            Label(scan.jobID == nil ? "Upload to server" : "Upload again", systemImage: "arrow.up.circle")
                            if uploading { Spacer(); ProgressView() }
                        }
                    }
                    .buttonStyle(ArrivalActionStyle(primary: true))
                    .disabled(uploading || zipping || serverURL.isEmpty)
                    if let jobID = scan.jobID {
                        LabeledContent("Job", value: jobID)
                        LabeledContent("Status", value: statusLine(scan))
                        if let error = scan.jobError {
                            Text(error).font(.footnote).foregroundStyle(.red)
                        }
                        if scan.jobStatus == "done", let server = scan.uploadedTo,
                           let url = ArrivalAPI.downloadURL(jobID: jobID, server: server) {
                            Link(destination: url) {
                                Label("Download dataset.zip", systemImage: "arrow.down.circle")
                            }
                        }
                    }
                    if let errorText {
                        Text(errorText).font(.footnote).foregroundStyle(.red)
                    }
                } header: {
                    ArrivalSectionHeading(number: "02", title: "Build the twin")
                } footer: {
                    if serverURL.isEmpty {
                        Text("Set the server URL on the first screen.")
                    } else {
                        Text("Uploads roomplan.json as \(scan.roomName).json"
                             + (store.hasFrames(scan) && includeFrames ? ", with frames.zip; held-out frames are compared with the twin" : "")
                             + ". The worker builds the twin, runs the sim and zips the dataset.")
                    }
                }
                .listRowBackground(ArrivalTheme.panel)
            }
            .scrollContentBackground(.hidden)
            .background(ArrivalPaper())
            .foregroundStyle(ArrivalTheme.ink)
            .tint(ArrivalTheme.signalInk)
            .listRowSeparatorTint(ArrivalTheme.rule)
            .navigationTitle("Survey details")
            .toolbarBackground(ArrivalTheme.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .task(id: scan.jobID) { await poll() }
            .task { await makeFramesZip(scan) }
        } else {
            ContentUnavailableView("Scan deleted", systemImage: "trash")
        }
    }

    private func statusLine(_ scan: Scan) -> String {
        [scan.jobStatus, scan.jobStage.map { "stage \($0)" }].compactMap { $0 }.joined(separator: ", ")
    }

    private func fileSize(_ url: URL) -> String {
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return Int64(bytes).formatted(.byteCount(style: .file))
    }

    private func upload(_ scan: Scan) async {
        uploading = true
        errorText = nil
        defer { uploading = false }
        do {
            let frames = includeFrames ? try store.framesZip(scan) : nil
            let job = try await ArrivalAPI.upload(fileURL: store.jsonURL(scan), filename: "\(scan.roomName).json",
                                                  framesZip: frames, server: serverURL)
            var updated = scan
            updated.jobID = job.id
            updated.jobStatus = job.status
            updated.jobStage = nil
            updated.jobError = nil
            updated.uploadedTo = serverURL
            store.update(updated)
        } catch {
            errorText = error.localizedDescription
        }
    }

    /// Builds frames.zip off the main thread so it shows up in the share sheet and is ready to upload.
    private func makeFramesZip(_ scan: Scan) async {
        guard store.hasFrames(scan), !FileManager.default.fileExists(atPath: store.framesZipURL(scan).path) else { return }
        zipping = true
        defer { zipping = false }
        let folder = store.framesURL(scan), zip = store.framesZipURL(scan)
        do {
            try await Task.detached(priority: .utility) { try ZipWriter.zip(folder: folder, to: zip) }.value
            store.update(scan)  // republish so the share sheet lists the zip
        } catch {
            errorText = "Could not zip the frames: \(error.localizedDescription)"
        }
    }

    /// Polls `GET /jobs/<id>` every 2 s while this screen is open and the job is not finished.
    private func poll() async {
        while !Task.isCancelled {
            guard let scan = store.scans.first(where: { $0.id == scanID }),
                  let jobID = scan.jobID, let server = scan.uploadedTo, !scan.isJobFinished else { return }
            if let status = try? await ArrivalAPI.status(jobID: jobID, server: server) {
                var updated = scan
                updated.jobStatus = status.status
                updated.jobStage = status.stage
                updated.jobError = status.error
                store.update(updated)
                if updated.isJobFinished { return }
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    }
}
