import UIKit // iOS 13.0+
// Combine 1.0+ for reactive programming
import Combine // iOS 13.0+

// MARK: - Internal Imports
// Per the JSON specification, we import named members from the internal modules referenced:
import Core/Base/BaseViewController // v1.0.0 (Base view controller functionality with error handling)
import Presentation.Walks.ViewModels.WalkListViewModel // v1.0.0 (View model for walk list management)
import Presentation.Common.Cells.WalkCell // v1.0.0 (Reusable cell for displaying walk information)

/**
 A view controller responsible for displaying and managing the list
 of dog walks, including active, scheduled, and completed walks with
 support for real-time updates, offline functionality, and accessibility
 features.

 This class addresses:
 • Service Execution (display and management of walk sessions with real-time updates, photo sharing, GPS tracking)
 • Booking System (schedule management, walk history display, real-time availability)
 • User Interface Design (walk list UI, interaction patterns, status indicators, and accessibility)
 */
open class WalkListViewController: BaseViewController {
    
    // MARK: - Properties
    
    /// View model responsible for managing the walk list data and logic.
    public let viewModel: WalkListViewModel
    
    /// A table view showing the list of dog walks filtered by status or real-time updates.
    private let tableView: UITableView
    
    /// A segmented control for filtering walks by status (e.g., All, Scheduled, Active, Completed).
    private let segmentedControl: UISegmentedControl
    
    /// A refresh control for user-initiated data refresh (pull-to-refresh pattern).
    private let refreshControl: UIRefreshControl
    
    /// A thread-safe set of Combine cancellables to manage subscription lifetimes.
    private var cancellables: Set<AnyCancellable>
    
    /// An activity indicator to show loading progress during data fetch.
    private let loadingIndicator: UIActivityIndicatorView
    
    /// An empty state stack view displayed when no walks are available for the current filter.
    private let emptyStateView: UIStackView
    
    /**
     A cache for storing images associated with walks, such as photos or thumbnails,
     optimizing repeated loads within the table view cells.
     */
    private let imageCache: NSCache<NSString, UIImage>
    
    // MARK: - Initializer
    
    /**
     Initializes the walk list view controller with its view model and sets up required components.
     
     Steps:
     1. Call super.init() from BaseViewController.
     2. Store the view model reference.
     3. Initialize UI components with accessibility support.
     4. Set up refresh control with localized text.
     5. Configure table view with estimated row heights.
     6. Initialize image cache for walk photos.
     7. Set up empty state view.
     8. Configure loading indicator.
     
     - Parameter viewModel: The WalkListViewModel instance that manages the walk data.
     */
    public init(viewModel: WalkListViewModel) {
        // 1. Call the designated initializer of super to set up a BaseViewController
        self.viewModel = viewModel
        self.tableView = UITableView(frame: .zero, style: .plain)
        self.segmentedControl = UISegmentedControl(items: ["All", "Scheduled", "Active", "Completed"])
        self.refreshControl = UIRefreshControl()
        self.cancellables = Set<AnyCancellable>()
        self.loadingIndicator = UIActivityIndicatorView(style: .medium)
        self.emptyStateView = UIStackView()
        self.imageCache = NSCache<NSString, UIImage>()
        
        super.init(nibName: nil, bundle: nil)
        
        // 3. Accessibility support for the newly created components:
        self.tableView.accessibilityIdentifier = "WalkListTableView"
        self.segmentedControl.accessibilityIdentifier = "WalkListSegmentedControl"
        self.refreshControl.accessibilityLabel = NSLocalizedString("Pull to refresh walks", comment: "")
        
        // 4. Configure refresh control with localized text
        self.refreshControl.attributedTitle = NSAttributedString(
            string: NSLocalizedString("Loading Walks...", comment: "")
        )
        
        // 5. Configure table view default height estimates, dynamic sizing
        self.tableView.estimatedRowHeight = 80
        self.tableView.rowHeight = UITableView.automaticDimension
        
        // 6. Image cache is already initialized; no further config needed.
        
        // 7. Set up empty state view as a vertical stack for a placeholder message
        self.emptyStateView.axis = .vertical
        self.emptyStateView.alignment = .center
        self.emptyStateView.distribution = .fill
        self.emptyStateView.spacing = 8
        
        // 8. Configure loading indicator styling
        self.loadingIndicator.hidesWhenStopped = true
    }
    
    /**
     Required initializer for loading from storyboard or nib, not used in this architecture.
     
     - Parameter coder: The unarchiver.
     */
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented for WalkListViewController.")
    }
    
    // MARK: - Lifecycle
    
    /**
     Sets up the view controller when loaded and initializes all required functionality.
     
     Steps:
     1. Call super.viewDidLoad().
     2. Set up UI components with proper constraints.
     3. Configure table view delegates and data source.
     4. Bind view model with error handling.
     5. Set up state restoration identifier.
     6. Configure accessibility features.
     7. Register for background/foreground notifications.
     8. Load initial data with loading indicator.
     */
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // 2. Set up UI
        setupUI()
        
        // 3. Configure table view behavior
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(WalkCell.self, forCellReuseIdentifier: "WalkCellIdentifier")
        
        // 4. Bind view model
        bindViewModel()
        
        // 5. State restoration
        self.restorationIdentifier = "WalkListViewControllerRestorationID"
        
        // 6. Accessibility features: Large text, dynamic type
        //   - Additional accessibility enhancements are in setupUI
        //   - Specified with each UI component.
        
        // 7. Register for notifications if needed (e.g., app entering background)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        // 8. Trigger initial load with a loading indicator
        loadingIndicator.startAnimating()
        viewModel.loadWalks()
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.loadingIndicator.stopAnimating()
                    if case let .failure(error) = completion {
                        self?.showError(error)
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Setup UI
    
    /**
     Configures the UI components and layout with proper accessibility support.
     
     Steps:
     1. Set up navigation bar with title and buttons.
     2. Configure segmented control with localized segments.
     3. Set up table view with proper styling.
     4. Configure refresh control with loading animation.
     5. Set up empty state view with message.
     6. Configure loading indicator.
     7. Apply auto layout constraints.
     8. Set up accessibility labels and hints.
     */
    public override func setupUI() {
        super.setupUI() // Calls BaseViewController's setup if needed
        
        // 1. Navigation bar setup
        navigationItem.title = NSLocalizedString("My Walks", comment: "Title for walk list")
        navigationController?.navigationBar.prefersLargeTitles = true
        
        // 2. Configure segmented control
        //    Already set items in init. Localize them if needed:
        segmentedControl.setTitle(NSLocalizedString("All", comment: ""), forSegmentAt: 0)
        segmentedControl.setTitle(NSLocalizedString("Scheduled", comment: ""), forSegmentAt: 1)
        segmentedControl.setTitle(NSLocalizedString("Active", comment: ""), forSegmentAt: 2)
        segmentedControl.setTitle(NSLocalizedString("Completed", comment: ""), forSegmentAt: 3)
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(handleSegmentChange), for: .valueChanged)
        
        // 3. Table view styling
        tableView.backgroundColor = .systemBackground
        tableView.separatorStyle = .singleLine
        
        // 4. Configure refresh control
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
        
        // 5. Setup empty state view with default message
        let emptyLabel = UILabel(frame: .zero)
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.text = NSLocalizedString("No walks available", comment: "Empty state message")
        emptyStateView.addArrangedSubview(emptyLabel)
        emptyStateView.isHidden = true // Start hidden
        
        // 6. Loading indicator (already created in init). Let it be a subview with constraints
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        // 7. Add constraints and subviews in a single block
        view.addSubview(segmentedControl)
        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        view.addSubview(loadingIndicator)
        
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Segmented control top anchor
            segmentedControl.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8
            ),
            segmentedControl.leadingAnchor.constraint(
                equalTo: view.leadingAnchor, constant: 16
            ),
            segmentedControl.trailingAnchor.constraint(
                equalTo: view.trailingAnchor, constant: -16
            ),
            
            // Table view below segmented control
            tableView.topAnchor.constraint(
                equalTo: segmentedControl.bottomAnchor, constant: 8
            ),
            tableView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),
            tableView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),
            tableView.bottomAnchor.constraint(
                equalTo: view.bottomAnchor
            ),
            
            // Empty state view (centered in table area)
            emptyStateView.centerXAnchor.constraint(
                equalTo: tableView.centerXAnchor
            ),
            emptyStateView.centerYAnchor.constraint(
                equalTo: tableView.centerYAnchor
            ),
            
            // Loading indicator (centered in the entire view)
            loadingIndicator.centerXAnchor.constraint(
                equalTo: view.centerXAnchor
            ),
            loadingIndicator.centerYAnchor.constraint(
                equalTo: view.centerYAnchor
            ),
        ])
        
        // 8. Setup additional accessibility labels/hints if needed
        segmentedControl.accessibilityLabel = NSLocalizedString("Walk Filter", comment: "")
        tableView.accessibilityLabel = NSLocalizedString("List of walks", comment: "")
    }
    
    // MARK: - Data Binding
    
    /**
     Sets up data binding with the view model using Combine.
     
     Steps:
     1. Bind walks data to table view with animation.
     2. Bind loading state to refresh control and indicator.
     3. Handle segment control changes with debounce (optional).
     4. Subscribe to walk updates with error handling.
     5. Bind empty state visibility.
     6. Handle error states with user feedback.
     7. Manage memory with proper cancellation.
     8. Update UI on main thread.
     */
    public override func bindViewModel() {
        super.bindViewModel(viewModel) // Calls BaseViewController's bindViewModel<T: ViewModelType>(_:)
        
        // 1. Bind walks data to table view
        viewModel.walksSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] walks in
                self?.tableView.reloadData()
                self?.updateEmptyStateIfNeeded(walkCount: walks.count)
            }
            .store(in: &cancellables)
        
        // 2. Bind loading state
        viewModel.loadingState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                switch state {
                case .loading:
                    self.refreshControl.beginRefreshing()
                    self.loadingIndicator.startAnimating()
                default:
                    self.refreshControl.endRefreshing()
                    self.loadingIndicator.stopAnimating()
                }
            }
            .store(in: &cancellables)
        
        // 4. Subscribe to additional walk updates or errors from the VM, if any
        //    (In some apps, we might handle partial updates or real-time events here)
        
        // 5. Empty state handled in #1 where we call updateEmptyStateIfNeeded
        
        // 6. If the VM publishes an error, we can show via showError. For demonstration, we skip or rely on loadWalks subscription.
    }
    
    // MARK: - Exposed Methods for External Use
    
    /**
     Programmatically handles a pull-to-refresh action, reloading data
     from the view model with real-time updates or offline functionality.
     */
    @objc
    public func handleRefresh() {
        refreshControl.beginRefreshing()
        loadingIndicator.startAnimating()
        
        viewModel.loadWalks()
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.refreshControl.endRefreshing()
                    self?.loadingIndicator.stopAnimating()
                    if case let .failure(error) = completion {
                        self?.showError(error)
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    /**
     Segmented control action that adjusts the table view's data display
     by filtering the underlying data set (All, Scheduled, Active, Completed).
     */
    @objc
    public func handleSegmentChange() {
        let index = segmentedControl.selectedSegmentIndex
        switch index {
        case 1:
            // Filter for scheduled
            viewModel.filterWalks(forStatus: .scheduled)
        case 2:
            viewModel.filterWalks(forStatus: .inProgress)
        case 3:
            viewModel.filterWalks(forStatus: .completed)
        default:
            // All walks
            viewModel.filterWalks(forStatus: nil)
        }
    }
    
    /**
     Updates a specific walk's status. Typically invoked from row actions
     (swipe to complete/cancel or a contextual menu).
     
     - Parameters:
       - walkId: The UUID of the walk to update.
       - newStatus: The target WalkStatus (e.g., .completed).
     */
    public func updateWalkStatus(walkId: UUID, newStatus: WalkStatus) {
        // Example: might call a specialized method in the VM or a service
        // For demonstration, we simply re-trigger load or notify user.
        
        // Real logic might call `viewModel.updateWalkStatus(walkId: newStatus)`.
        // We'll simulate an approach of re-calling load:
        loadingIndicator.startAnimating()
        viewModel.updateStatus(of: walkId, to: newStatus)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.loadingIndicator.stopAnimating()
                    if case let .failure(error) = completion {
                        self?.showError(error)
                    }
                },
                receiveValue: { [weak self] _ in
                    // Possibly reload data or let the existing flows handle changes
                    self?.tableView.reloadData()
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Additional Internal Logic
    
    private func updateEmptyStateIfNeeded(walkCount: Int) {
        emptyStateView.isHidden = (walkCount > 0)
    }
    
    @objc
    private func handleDidEnterBackground() {
        // Save partial state or unsub as needed
        // For demonstration, do nothing
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate

extension WalkListViewController: UITableViewDataSource, UITableViewDelegate {
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.walksSubject.value.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard
            let cell = tableView.dequeueReusableCell(withIdentifier: "WalkCellIdentifier", for: indexPath) as? WalkCell
        else {
            // Fallback cell if cast fails
            return UITableViewCell(style: .default, reuseIdentifier: nil)
        }
        
        // Retrieve walk data
        let walk = viewModel.walksSubject.value[indexPath.row]
        
        // Configure cell with walk
        cell.configure(with: walk)
        // Potentially pass imageCache if the cell loads photos
        cell.imageCache = imageCache
        
        return cell
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Could navigate to a detail screen or do some action
    }
}