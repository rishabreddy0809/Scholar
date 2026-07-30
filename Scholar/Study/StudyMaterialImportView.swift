//
//  StudyMaterialImportView.swift
//  Scholar
//

import PhotosUI
import SwiftUI

struct StudyMaterialImportView: View {
    /// Called with the finished material so the caller can focus the feed on it.
    var onImported: (StudyMaterial) -> Void

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var showFileImporter = false
    @State private var photoItem: PhotosPickerItem?
    @State private var typedText = ""
    @State private var isWorking = false
    @State private var status = ""
    @State private var failure: String?
    @State private var preview: StudyMaterial?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let preview {
                        result(preview)
                    } else {
                        prompt
                        if isWorking { working } else { options }
                        if let failure { errorBanner(failure) }
                        typeItOut
                        privacyNote
                    }
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .background(Theme.bg)
            .navigationTitle(preview == nil ? "Study material" : "Ready")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.textDim)
                }
            }
        }
        .preferredColorScheme(.dark)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: MaterialImporter.readableTypes,
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            run { try await MaterialImporter.material(fromFileAt: url) }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            run {
                status = "Reading the image…"
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw ImportError.unreadable
                }
                return try await MaterialImporter.material(fromImageData: data)
            }
        }
    }

    // MARK: - Prompt

    private var prompt: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What are you studying?")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Theme.text)
            Text("Drop in a lecture PDF, a photo of your notes, or paste the text. Your feed switches to cover only that.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textDim)
        }
    }

    private var options: some View {
        VStack(spacing: 10) {
            Button { showFileImporter = true } label: {
                optionRow("doc.text.fill", "Upload a document",
                          "PDF, plain text, or rich text", Theme.accent)
            }
            .buttonStyle(.plain)

            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                optionRow("photo.fill", "Photo of your notes",
                          "Slides, textbook pages, handwriting", Color(hex: 0x4ADE80))
            }
            .buttonStyle(.plain)
        }
    }

    private func optionRow(_ icon: String, _ title: String,
                           _ detail: String, _ tint: Color) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(tint.opacity(0.16), in: .rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textDim)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textFaint)
        }
        .padding(13)
        .cardSurface(16)
    }

    private var working: some View {
        HStack(spacing: 12) {
            ProgressView().tint(Theme.accentSoft)
            Text(status)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .cardSurface(16)
    }

    private var typeItOut: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("OR PASTE IT")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.textFaint)
                .tracking(0.8)

            TextEditor(text: $typedText)
                .font(.system(size: 14))
                .foregroundStyle(Theme.text)
                .scrollContentBackground(.hidden)
                .frame(height: 130)
                .padding(10)
                .cardSurface(14)
                .overlay(alignment: .topLeading) {
                    if typedText.isEmpty {
                        Text("Paste your syllabus, revision notes, or an exam topic list…")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textFaint)
                            .padding(18)
                            .allowsHitTesting(false)
                    }
                }

            Button {
                let text = typedText
                run { try await MaterialImporter.material(fromTypedText: text) }
            } label: {
                Text("Build my feed from this")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(canSubmitText ? Theme.accent : Theme.surfaceHi,
                                in: .rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(!canSubmitText || isWorking)
        }
    }

    private var canSubmitText: Bool {
        typedText.split { $0.isWhitespace }.count >= 12
    }

    @ViewBuilder
    private var privacyNote: some View {
        let usesModel = Intelligence.isReady

        VStack(alignment: .leading, spacing: 8) {
            Label(usesModel
                  ? "Your files never leave the device — text extraction, keywording and Apple Intelligence all run locally."
                  : "Your files never leave the device — text extraction and keywording both run locally.",
                  systemImage: "lock.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textDim)

            // Only worth explaining when it changes what the user gets. On a
            // device that simply can't run the model, saying so once is honest;
            // nagging about it on every screen is not.
            if let hint = Intelligence.availability.hint {
                Label(hint, systemImage: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textFaint)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(12)
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundStyle(Theme.down)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.down.opacity(0.12), in: .rect(cornerRadius: 12))
    }

    // MARK: - Result

    private func result(_ material: StudyMaterial) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Label(material.kind.label, systemImage: material.kind.symbol)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.accentSoft)
                Text(material.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("\(material.wordCount) words read · \(material.keywords.count) key topics found")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textDim)
                if let summary = material.summary {
                    Text(summary)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textDim)
                        .padding(.top, 4)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("YOUR FEED WILL COVER")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textFaint)
                    .tracking(0.8)
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(material.keywords.prefix(12), id: \.term) { keyword in
                        TagChip(text: keyword.term, tint: Theme.accent)
                    }
                }
            }

            if !material.interests.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("PULLING FROM")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.textFaint)
                        .tracking(0.8)
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(material.interests) { interest in
                            TagChip(text: interest.name, emoji: interest.emoji,
                                    tint: interest.tint, isOn: true)
                        }
                    }
                    Text(material.channels.prefix(6).map(\.name).joined(separator: " · "))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textDim)
                }
            }

            Button {
                store.addMaterial(material)
                store.activeMaterialID = material.id
                onImported(material)
                dismiss()
            } label: {
                Label("Start studying this", systemImage: "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Theme.accent, in: .rect(cornerRadius: 15))
            }
            .buttonStyle(.plain)

            Button("Pick something else") {
                withAnimation { preview = nil }
                typedText = ""
                photoItem = nil
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.textDim)
            .frame(maxWidth: .infinity)
            .buttonStyle(.plain)
        }
    }

    // MARK: - Work

    private func run(_ work: @escaping () async throws -> StudyMaterial) {
        guard !isWorking else { return }
        isWorking = true
        failure = nil
        if status.isEmpty { status = "Reading your material…" }

        Task {
            do {
                let material = try await work()
                await MainActor.run {
                    isWorking = false
                    status = ""
                    withAnimation(.easeOut(duration: 0.25)) { preview = material }
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    status = ""
                    photoItem = nil
                    failure = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }
}
