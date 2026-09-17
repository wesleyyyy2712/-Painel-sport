import SwiftUI
import UniformTypeIdentifiers

private enum HomePatchPickerPolicy {
    static let allowedContentTypes: [UTType] = [
        UTType(filenameExtension: "3105") ?? .data,
        .data
    ]
}

struct RepositoryHomeView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: PackageRepositoryStore
    @EnvironmentObject private var patchStore: PatchProjectStore
    @State private var showPatchImporter = false

    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void
    let onOpenInject: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                Image("HomeBackground")
                    .resizable()
                    .scaledToFit()
                    .overlay(Color.black.opacity(0.18))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        statusSection
                        resourcesSection
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .refreshable {
                await store.refreshAllAndWait()
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                AppUtilityToolbar(
                    language: language,
                    onOpenSettings: onOpenSettings,
                    onOpenLogs: onOpenLogs
                )
            }
            .onAppear {
                store.refreshAllIfNeeded()
                appState.detectSupport()
            }
            .sheet(isPresented: $showPatchImporter) {
                FileDocumentPicker(
                    allowedContentTypes: HomePatchPickerPolicy.allowedContentTypes,
                    copiesSelectedDocument: true,
                    allowsMultipleSelection: false,
                    onSelection: { result in
                        showPatchImporter = false
                        guard case .success(let urls) = result,
                              let url = urls.first else { return }
                        patchStore.importPackage(at: url)
                    },
                    onCancel: {
                        showPatchImporter = false
                    }
                )
                .ignoresSafeArea()
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("STATUS")
            Text("Seu dispositivo")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Button(action: onOpenSettings) {
                HStack(spacing: 14) {
                    AppRowIcon(systemName: "iphone", tint: AppTheme.accent, symbolSize: 19, frameSize: 48)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(AppInfo.hardwareDisplayName) compatível")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("iOS \(AppInfo.osVersion) · acesso disponível")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    Spacer(minLength: 8)
                    VStack(spacing: 5) {
                        Circle()
                            .fill(appState.isSupported ? Color.green : AppTheme.accent)
                            .frame(width: 12, height: 12)
                        Text(appState.isSupported ? "OK" : "—")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
                .padding(AppTheme.contentCardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(GlassCardBackground())
            .overlay { GlassCardBorder() }
        }
    }

    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("RECURSOS")
            Text("Acesso rápido")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Button { showPatchImporter = true } label: {
                HStack(spacing: 14) {
                    AppRowIcon(systemName: "square.and.arrow.down", tint: AppTheme.accent, symbolSize: 18, frameSize: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Importar arquivo .3105").font(.headline).foregroundStyle(.white)
                        Text("Adicione um pacote pelo app Arquivos").font(.subheadline).foregroundStyle(.white.opacity(0.72))
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").foregroundStyle(AppTheme.accent)
                }
                .padding(AppTheme.contentCardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(GlassCardBackground())
            .overlay { GlassCardBorder() }

            Button(action: onOpenInject) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 14) {
                        AppRowIcon(systemName: "shippingbox", tint: AppTheme.accent, symbolSize: 19, frameSize: 40)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Arquivos instalados").font(.headline).foregroundStyle(.white)
                            Text("Ative, desative e restaure seus arquivos").font(.subheadline).foregroundStyle(.white.opacity(0.72))
                        }
                    }
                    Text("Abrir Injetar para gerenciar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.leading, 54)
                        .padding(.top, 8)
                }
                .padding(AppTheme.contentCardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(GlassCardBackground())
            .overlay { GlassCardBorder() }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .tracking(3)
            .foregroundStyle(AppTheme.accent)
    }
}

struct RepositoryNewView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var store: PackageRepositoryStore
    @State private var packages: [RepositoryPackageRecord] = []
    @State private var showSimulatedPackageDetail = false
    @State private var simulatedPackageDetailGate = OneShotPresentationGate()

    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if packages.isEmpty {
                    Section {
                        emptyState
                    }
                } else {
                    Section {
                        ForEach(packages) { record in
                            NavigationLink(value: record) {
                                RepositoryNewPackageRow(record: record)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(language.text("tab.new"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                AppUtilityToolbar(
                    language: language,
                    onOpenSettings: onOpenSettings,
                    onOpenLogs: onOpenLogs
                )
            }
            .navigationDestination(for: RepositoryPackageRecord.self) { record in
                RepositoryPackageDetailView(record: record)
            }
            .navigationDestination(isPresented: $showSimulatedPackageDetail) {
                if let record = packages.first {
                    RepositoryPackageDetailView(record: record)
                }
            }
            .refreshable {
                await store.refreshAllAndWait()
                rebuildPackages()
            }
            .onAppear {
                store.refreshAllIfNeeded()
                rebuildPackages()
                openSimulatedPackageDetailIfNeeded()
            }
            .onChange(of: store.packages) { _ in
                rebuildPackages()
                openSimulatedPackageDetailIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if store.isRefreshing && !store.sources.isEmpty {
            HStack(spacing: 10) {
                ProgressView()
                Text(language.text("repository.refreshing"))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else {
            VStack(spacing: 12) {
                Image(systemName: store.sources.isEmpty ? "shippingbox" : "clock")
                    .font(.system(size: AppTheme.emptyIconSize, weight: .light))
                    .foregroundStyle(AppTheme.accent)
                Text(language.text(
                    store.sources.isEmpty
                        ? "repository.no_sources_title"
                        : "repository.new_empty_title"
                ))
                .font(.headline)
                Text(language.text(
                    store.sources.isEmpty
                        ? "repository.no_sources_message"
                        : "repository.new_empty_message"
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
        }
    }

    private func rebuildPackages() {
        packages = PackageRepositoryFeedPolicy.newest(store.packages)
    }

    private func openSimulatedPackageDetailIfNeeded() {
#if targetEnvironment(simulator)
        guard ProcessInfo.processInfo.arguments.contains(
            "--simulate-package-detail"
        ), !packages.isEmpty, simulatedPackageDetailGate.claim() else {
            return
        }
        DispatchQueue.main.async {
            showSimulatedPackageDetail = true
        }
#endif
    }
}

struct RepositorySearchView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var store: PackageRepositoryStore
    @State private var searchText = ""

    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var results: [RepositoryPackageRecord] {
        guard !query.isEmpty else { return [] }
        return store.packages.filter { record in
            let package = record.package
            return package.name.localizedCaseInsensitiveContains(query)
                || package.author.localizedCaseInsensitiveContains(query)
                || package.summary.localizedCaseInsensitiveContains(query)
                || package.identifier.localizedCaseInsensitiveContains(query)
                || record.sourceName.localizedCaseInsensitiveContains(query)
                || (package.category?.localizedCaseInsensitiveContains(query) ?? false)
                || package.tags.contains {
                    $0.localizedCaseInsensitiveContains(query)
                }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppSearchField(
                    text: $searchText,
                    prompt: language.text("repository.search_prompt"),
                    clearLabel: language.text("common.clear")
                )
                Divider()
                List {
                    if query.isEmpty {
                        searchPrompt
                            .listRowSeparator(.hidden)
                    } else if results.isEmpty {
                        searchEmpty
                            .listRowSeparator(.hidden)
                    } else {
                        Section(language.text(
                            "repository.search_results",
                            Int64(results.count)
                        )) {
                            ForEach(results) { record in
                                NavigationLink(value: record) {
                                    RepositoryPackageRow(record: record)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollDismissesKeyboard(.interactively)
                .refreshable {
                    await store.refreshAllAndWait()
                }
            }
            .navigationTitle(language.text("repository.search"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                AppUtilityToolbar(
                    language: language,
                    onOpenSettings: onOpenSettings,
                    onOpenLogs: onOpenLogs
                )
            }
            .navigationDestination(for: RepositoryPackageRecord.self) { record in
                RepositoryPackageDetailView(record: record)
            }
            .onAppear {
                store.refreshAllIfNeeded()
            }
        }
    }

    private var searchPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: AppTheme.emptyIconSize, weight: .light))
                .foregroundStyle(AppTheme.accent)
            Text(language.text("repository.search_title"))
                .font(.headline)
            Text(language.text("repository.search_message"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }

    private var searchEmpty: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: AppTheme.emptyIconSize, weight: .light))
                .foregroundStyle(.secondary)
            Text(language.text("repository.search_empty"))
                .font(.headline)
            Text(language.text("repository.search_empty_message"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }
}

private struct RepositoryFeaturedCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var imageLoader = RepositoryImageLoader()
    let record: RepositoryPackageRecord
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            artwork

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.28),
                    .init(color: .black.opacity(0.16), location: 0.56),
                    .init(color: .black.opacity(0.78), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(record.package.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)

                Text(record.package.author)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .shadow(color: .black.opacity(0.42), radius: 1, y: 1)
        }
        .frame(width: width, height: height, alignment: .bottomLeading)
        .background(Color(uiColor: .secondarySystemFill))
        .clipShape(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    Color(uiColor: .separator).opacity(0.24),
                    lineWidth: 0.5
                )
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .task(id: record.package.iconURL) {
            guard let iconURL = record.package.iconURL else { return }
            await imageLoader.load(url: iconURL, maximumPixelSize: 640)
        }
    }

    private var artwork: some View {
        Rectangle()
            .fill(Color(uiColor: .secondarySystemFill))
            .overlay {
                if let image = imageLoader.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if imageLoader.didFail {
                    placeholder
                } else if record.package.iconURL == nil {
                    placeholder
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Image(systemName: record.package.kind == .wallpaper
            ? "photo.fill"
            : "shippingbox.fill")
            .font(.system(size: 30, weight: .medium))
            .foregroundStyle(.white.opacity(0.82))
    }
}

private struct RepositoryCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}

private struct RepositoryNewPackageRow: View {
    @Environment(\.appLanguage) private var language
    let record: RepositoryPackageRecord

    var body: some View {
        HStack(spacing: 12) {
            RepositoryPackageIcon(package: record.package, size: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(record.package.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(language.text(
                    "repository.home_package_meta",
                    record.package.author,
                    record.sourceName
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let publishedAt = record.package.publishedAt {
                Text(
                    publishedAt,
                    format: .dateTime.day().month(.abbreviated)
                )
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}
