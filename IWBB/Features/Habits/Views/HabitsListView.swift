import SwiftUI

// MARK: - HabitsListView

struct HabitsListView: View {
    @State private var viewModel: HabitsListViewModel
    @Environment(\.services) private var services
    
    init() {
        // This will be properly initialized via dependency injection
        self._viewModel = State(initialValue: HabitsListViewModel(
            habitService: ServiceContainer().habitService,
            errorHandlingService: ServiceContainer().errorHandlingService
        ))
    }
    
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Привычки")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Menu {
                            filterMenu
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack {
                            Menu {
                                viewModeMenu
                            } label: {
                                Image(systemName: viewModel.state.viewMode.icon)
                            }
                            
                            Button {
                                viewModel.send(.createHabitTapped)
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
                .searchable(
                    text: Binding(
                        get: { viewModel.state.searchText },
                        set: { viewModel.send(.searchTextChanged($0)) }
                    ),
                    prompt: "Поиск привычек"
                )
                .refreshable {
                    viewModel.send(.refreshHabits)
                }
        }
        .task {
            viewModel.send(.loadHabits)
        }
        .sheet(isPresented: .constant(viewModel.state.showingCreateHabit)) {
            CreateHabitView(isPresented: .constant(viewModel.state.showingCreateHabit))
        }
        .alert("Удалить привычку?", isPresented: .constant(viewModel.state.showingDeleteAlert)) {
            Button("Удалить", role: .destructive) {
                viewModel.send(.confirmDelete)
            }
            Button("Отмена", role: .cancel) {
                viewModel.send(.cancelDelete)
            }
        } message: {
            if let habit = viewModel.state.habitToDelete {
                Text("Привычка \"\(habit.name)\" будет удалена навсегда.")
            }
        }
        .errorAlert(
            error: viewModel.state.error,
            isPresented: .constant(viewModel.state.error != nil)
        ) {
            viewModel.send(.dismissError)
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if viewModel.state.isLoading && viewModel.state.habits.isEmpty {
            loadingView
        } else if viewModel.showEmptyState {
            emptyStateView
        } else {
            mainContent
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            headerStatsView
            
            habitsList
        }
    }
    
    // MARK: - Header Stats
    
    private var headerStatsView: some View {
        let stats = viewModel.headerStats
        
        return VStack(spacing: 12) {
            HStack(spacing: 16) {
                StatCard(
                    title: "Сегодня",
                    value: "\(stats.todayCompleted)/\(stats.todayTotal)",
                    color: .blue,
                    icon: "calendar"
                )
                
                StatCard(
                    title: "Процент",
                    value: "\(Int(stats.completionRate * 100))%",
                    color: .green,
                    icon: "percent"
                )
                
                StatCard(
                    title: "Серии",
                    value: "\(stats.totalStreak)",
                    color: .orange,
                    icon: "flame.fill"
                )
            }
            
            if stats.todayTotal > 0 {
                ProgressView(value: stats.completionRate)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(y: 2)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    // MARK: - Habits List
    
    @ViewBuilder
    private var habitsList: some View {
        switch viewModel.state.viewMode {
        case .list:
            listView
        case .grid:
            gridView
        }
    }
    
    private var listView: some View {
        List {
            ForEach(viewModel.state.filteredHabits, id: \.id) { habit in
                HabitListCardView(
                    habit: habit,
                    onToggle: {
                        viewModel.send(.toggleHabitCompletion(habit))
                    },
                    onEdit: {
                        viewModel.send(.editHabitTapped(habit))
                    },
                    onDelete: {
                        viewModel.send(.deleteHabitTapped(habit))
                    }
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .onTapGesture {
                    viewModel.send(.habitSelected(habit))
                }
            }
        }
        .listStyle(.plain)
        .scrollIndicators(.hidden)
    }
    
    private var gridView: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
                spacing: 12
            ) {
                ForEach(viewModel.state.filteredHabits, id: \.id) { habit in
                    HabitGridCardView(
                        habit: habit,
                        onToggle: {
                            viewModel.send(.toggleHabitCompletion(habit))
                        },
                        onTap: {
                            viewModel.send(.habitSelected(habit))
                        }
                    )
                    .frame(height: 160)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Loading State
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Загрузка привычек...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 60))
                .foregroundStyle(.gray.opacity(0.5))
            
            VStack(spacing: 8) {
                Text(viewModel.emptyStateMessage)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text("Создайте свою первую привычку")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            
            Button("Создать привычку") {
                viewModel.send(.createHabitTapped)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Menu Content
    
    private var filterMenu: some View {
        VStack {
            ForEach(HabitFilter.allCases, id: \.self) { filter in
                Button {
                    viewModel.send(.filterChanged(filter))
                } label: {
                    Label(filter.title, systemImage: filter.icon)
                }
            }
            
            Divider()
            
            ForEach(HabitSort.allCases, id: \.self) { sort in
                Button {
                    viewModel.send(.sortChanged(sort))
                } label: {
                    Label(sort.title, systemImage: sort.icon)
                }
            }
            
            Divider()
            
            Button {
                viewModel.send(.toggleShowCompleted)
            } label: {
                Label(
                    viewModel.state.showCompletedHabits ? "Скрыть выполненные" : "Показать выполненные",
                    systemImage: viewModel.state.showCompletedHabits ? "eye.slash" : "eye"
                )
            }
        }
    }
    
    private var viewModeMenu: some View {
        VStack {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button {
                    viewModel.send(.viewModeChanged(mode))
                } label: {
                    Label(mode.title, systemImage: mode.icon)
                }
            }
        }
    }
}

// MARK: - StatCard

private struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        }
    }
}

// MARK: - Error Alert ViewModifier

private struct ErrorAlertModifier: ViewModifier {
    let error: AppError?
    let isPresented: Binding<Bool>
    let onDismiss: () -> Void
    
    func body(content: Content) -> some View {
        content
            .alert("Ошибка", isPresented: isPresented) {
                Button("OK") {
                    onDismiss()
                }
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
    }
}

extension View {
    func errorAlert(
        error: AppError?,
        isPresented: Binding<Bool>,
        onDismiss: @escaping () -> Void = {}
    ) -> some View {
        self.modifier(ErrorAlertModifier(
            error: error,
            isPresented: isPresented,
            onDismiss: onDismiss
        ))
    }
}

// MARK: - Create Habit View Placeholder

private struct CreateHabitView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Создание привычки")
                    .font(.title)
                    .padding()
                
                Text("Здесь будет форма создания привычки")
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button("Закрыть") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Новая привычка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    HabitsListView()
        .withServices(ServiceContainer.preview())
} 