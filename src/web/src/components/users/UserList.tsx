import React, {
  FC,
  useState,
  useEffect,
  useCallback,
  useRef
} from 'react'; // react@^18.0.0
import { useNavigate } from 'react-router-dom'; // react-router-dom@^6.0.0
import { useVirtualizer } from 'react-virtual'; // react-virtual@^2.10.4

/**
 * Importing the reusable Table component for rendering
 * sortable, paginated data with accessibility features.
 */
import Table from '../common/Table'; // Internal import

/**
 * Importing user-related types including role enumeration
 * and data classification for secure handling of sensitive fields.
 */
import {
  User,
  UserRole,
  WalkerProfile,
  // Although WalkerProfile is present in the import, it may be used if we display walker-specific info
  DataClassification
} from '../../types/user.types';

/**
 * Importing the UserService which provides secure user data
 * operations, including real-time subscriptions and data fetching.
 */
import { UserService } from '../../services/user.service';

/**
 * Describes any additional props for the UserList component.
 * Could be extended to include user-defined filters, callbacks, etc.
 */
interface UserListProps {
  /**
   * Optional initial filter for roles. (e.g., 'ADMIN', 'OWNER', 'WALKER', 'ALL')
   * If omitted, the list defaults to showing all roles for which
   * the current user has permission to view.
   */
  initialRoleFilter?: UserRole | 'ALL';

  /**
   * Optional title or heading for the user list,
   * used in certain UI contexts.
   */
  title?: string;
}

/**
 * This component displays a secure and performant list of user profiles
 * with the following key capabilities:
 *  - Role-based filtering and data masking
 *  - Paginated and sortable table layout
 *  - Real-time updates via UserService subscription
 *  - Comprehensive security checks around data classification
 *  - Accessibility and consistent design system usage
 *
 * Implementation addresses the specifications:
 *    1) User Management for owners/walkers with verified roles
 *    2) User Interface Design with consistent, accessible components
 *    3) Data Security ensuring masked sensitive fields and access controls
 */
const UserList: FC<UserListProps> = ({
  initialRoleFilter = 'ALL',
  title = 'User Management'
}) => {
  /**
   * The userService instance for secure operations. Typically, this
   * would be injected or obtained from a provider, but for demonstration
   * we create a local instance here.
   */
  const userServiceRef = useRef<UserService | null>(null);
  if (!userServiceRef.current) {
    userServiceRef.current = new UserService(/* Possibly pass needed ApiService */);
  }

  /**
   * The full set of user records fetched from the backend and
   * potentially masked based on the current viewer's role.
   */
  const [users, setUsers] = useState<User[]>([]);

  /**
   * A stateful variable indicating total user count used for pagination.
   * The Table component uses total items for pagination logic.
   */
  const [totalUsers, setTotalUsers] = useState<number>(0);

  /**
   * Loading states for the entire component, used to display
   * spinners or skeleton placeholders if needed.
   */
  const [isLoading, setIsLoading] = useState<boolean>(false);

  /**
   * An error state that captures any failure or exceptions during
   * fetch, helpful for user-facing error messages or logging.
   */
  const [error, setError] = useState<string | null>(null);

  /**
   * The current user's role, used to decide data access,
   * classification handling, and additional role-based filtering.
   */
  const [currentUserRole, setCurrentUserRole] = useState<UserRole | null>(null);

  /**
   * The role filter used to refine which user roles are visible in the table.
   * By default, it may be "ALL", or a single role if passed in props.
   */
  const [roleFilter, setRoleFilter] = useState<UserRole | 'ALL'>(initialRoleFilter);

  /**
   * Basic local pagination state, aligned with the Table component's
   * built-in pagination. The Table will request these values,
   * and modifications to page/pageSize can be handled here or in onSort.
   */
  const [page, setPage] = useState<number>(1);
  const [pageSize, setPageSize] = useState<number>(10);

  /**
   * Basic local sort state. The Table calls onSort with field/direction,
   * and we store it here. Then pass it back so the Table can reflect the
   * sorted column and direction visually.
   */
  const [sortField, setSortField] = useState<string>('');
  const [sortDirection, setSortDirection] = useState<'ASC' | 'DESC'>('ASC');

  /**
   * A reference to the table container for useVirtualizer if we want
   * to implement virtual scrolling (especially for large data sets).
   */
  const tableContainerRef = useRef<HTMLDivElement | null>(null);

  /**
   * A navigate function from react-router-dom for any button-driven
   * user detail navigations or advanced flows.
   */
  const navigate = useNavigate();

  /**
   * This function handles sensitive data masking based on user role
   * and each user's data classification. For example, if the viewer
   * is not an ADMIN, email might be partially masked for CRITICAL types.
   */
  const handleDataMasking = useCallback(
    (userArray: User[]): User[] => {
      // 1) Get current user role
      const viewerRole = currentUserRole;

      // 2) Check data access permissions. If viewerRole is null, assume minimal access.
      if (!viewerRole) {
        // We can either throw an error or return everything masked
        // For simplicity, we return masked for all fields
        console.log('[Audit] Viewer role unknown, applying maximum masking.');
        return userArray.map((u) => ({
          ...u,
          email: '********',
        }));
      }

      // 3) Apply masking rules based on classification for each user
      const maskedData = userArray.map((u) => {
        // Example logic for classification-based masking
        if (u.dataClassification === (('CRITICAL' as unknown) as DataClassification)) {
          // If the viewer is not ADMIN, mask critical fields
          if (viewerRole !== UserRole.ADMIN) {
            return {
              ...u,
              // Hide entire email
              email: 'Hidden for non-admin',
            };
          }
        } else if (u.dataClassification === (('SENSITIVE' as unknown) as DataClassification)) {
          // Partial email mask for non-admin
          if (viewerRole !== UserRole.ADMIN) {
            const maskedEmail = maskEmail(u.email, 3);
            return {
              ...u,
              email: maskedEmail,
            };
          }
        }
        return { ...u };
      });

      // 4) Log masking operations for audit (in a real environment, use a secure logger)
      console.log('[Audit] Data masking applied based on viewer role and classification.');

      // 5) Return masked data
      return maskedData;
    },
    [currentUserRole]
  );

  /**
   * A helper to partially mask an email. We mask everything after
   * a certain prefix length, preserving domain for demonstration.
   * (Production logic might differ.)
   */
  function maskEmail(email: string, prefixLength: number = 2): string {
    const [localPart, domainPart] = email.split('@');
    if (!domainPart) return '***@***';

    const prefix = localPart.slice(0, prefixLength);
    const masked = prefix.padEnd(localPart.length, '*');
    return `${masked}@${domainPart}`;
  }

  /**
   * This function securely fetches users from the backend, applying
   * the following steps:
   *  1) Set loading state to true
   *  2) Check user role and access permissions
   *  3) Apply additional data classification filters if needed
   *  4) Call userService to fetch user data
   *  5) Mask sensitive data based on user role
   *  6) Update user state with processed data
   *  7) Update total user count
   *  8) Log access attempt for audit
   *  9) Set loading to false
   * 10) Handle errors specifically
   */
  const fetchUsers = useCallback(async () => {
    setIsLoading(true);
    setError(null);

    try {
      // Step 2: We already have currentUserRole in state; check if non-null for logic
      if (!currentUserRole) {
        // Force fetch current user to determine role
        const me = await userServiceRef.current?.getCurrentUser();
        if (me) {
          setCurrentUserRole(me.role);
        }
        // If we still don't have a role, bail with an error
        if (!me || !me.role) {
          throw new Error('Unable to determine viewer role');
        }
      }

      // Step 3: Possibly refine role-based filters (like roleFilter) or limit data if not ADMIN
      // For demonstration, we share a basic approach.

      // Step 4: Call userService to fetch user data
      // (Note: Our example does not define getUserById for multiple user fetch, so we assume
      //  we have some getAllUsers method or a placeholder. If such method doesn't exist,
      //  we'd adapt the code or create a specialized fetch.)
      // Here, we illustrate a hypothetical approach. Replace as needed:
      const usersFetched: User[] = await mockFetchAllUsers(); // Replace with actual userService call

      // Step 5: Mask sensitive data
      const finalUsers = handleDataMasking(usersFetched);

      // Apply optional role filter
      let filteredUsers = finalUsers;
      if (roleFilter !== 'ALL') {
        filteredUsers = finalUsers.filter((u) => u.role === roleFilter);
      }

      // Step 6: Update users state
      setUsers(filteredUsers);

      // Step 7: Update total count for pagination if needed
      setTotalUsers(filteredUsers.length);

      // Step 8: Log access attempt (in real system, log to secure logging)
      console.log('[Audit] User list fetch attempt for role:', currentUserRole);

      // Step 9: Set loading to false
      setIsLoading(false);
    } catch (err: any) {
      // Step 10: Handle errors
      setIsLoading(false);
      setError(err.message || 'Error fetching users');
      console.error('[UserList] fetchUsers error:', err);
    }
  }, [currentUserRole, roleFilter, handleDataMasking]);

  /**
   * A mock function simulating user data retrieval. In production, you'd call
   * an actual userServiceRef.current?.someFetchMethod(...) or pass filters.
   * This is for demonstration only.
   */
  async function mockFetchAllUsers(): Promise<User[]> {
    // Simulate server data
    return [
      {
        id: '123',
        email: 'admin@example.com',
        role: UserRole.ADMIN,
        dataClassification: ('CRITICAL' as unknown) as DataClassification,
        firstName: 'System',
        lastName: 'Admin',
        phone: '555-1234',
        isVerified: true,
        isActive: true,
        lastLoginAt: new Date(),
        createdAt: new Date(),
        updatedAt: new Date()
      },
      {
        id: '456',
        email: 'owner@example.com',
        role: UserRole.OWNER,
        dataClassification: ('SENSITIVE' as unknown) as DataClassification,
        firstName: 'Pet',
        lastName: 'Owner',
        phone: '555-4567',
        isVerified: true,
        isActive: true,
        lastLoginAt: new Date(),
        createdAt: new Date(),
        updatedAt: new Date()
      },
      {
        id: '789',
        email: 'walker@example.com',
        role: UserRole.WALKER,
        dataClassification: ('INTERNAL' as unknown) as DataClassification,
        firstName: 'Dog',
        lastName: 'Walker',
        phone: '555-7890',
        isVerified: true,
        isActive: true,
        lastLoginAt: new Date(),
        createdAt: new Date(),
        updatedAt: new Date()
      }
    ];
  }

  /**
   * Effect to initialize the current user role on mount
   * (so we can apply correct data filtering ASAP).
   */
  useEffect(() => {
    (async () => {
      try {
        const me = await userServiceRef.current?.getCurrentUser();
        if (me && me.role) {
          setCurrentUserRole(me.role);
        }
      } catch (error) {
        console.error('[UserList] Unable to fetch current user role:', error);
      }
    })();
  }, []);

  /**
   * Effect to fetch user data on component mount, or whenever roleFilter
   * changes (or the user role changes, so we re-check permissions).
   */
  useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

  /**
   * Subscription to real-time user updates. For example, userService
   * might provide a callback-based method that notifies changes
   * to user data. We'll respond by re-fetching or patching local data.
   */
  useEffect(() => {
    let unsubscribe: (() => void) | undefined;
    if (userServiceRef.current) {
      unsubscribe = userServiceRef.current.subscribeToUserUpdates((updated: User) => {
        // Real-time update applied. For demonstration, we do a quick approach:
        setUsers((prev) => {
          const idx = prev.findIndex((u) => u.id === updated.id);
          if (idx >= 0) {
            // Merge changes
            const updatedList = [...prev];
            updatedList[idx] = {
              ...updatedList[idx],
              ...updated
            };
            // Reapply masking
            return handleDataMasking(updatedList);
          }
          return prev;
        });
      });
    }
    return () => {
      // Cleanup subscription
      if (unsubscribe) {
        unsubscribe();
      }
    };
  }, [handleDataMasking]);

  /**
   * onSort callback provided to the Table to handle changes in sorting.
   * We store the sortField and direction, then potentially re-fetch
   * from the server or re-sort locally. For now, we simulate local sorting.
   */
  function handleSort(params: { field: string; direction: 'ASC' | 'DESC' }) {
    setSortField(params.field);
    setSortDirection(params.direction);

    // If we want to do local sorting:
    setUsers((prevUsers) => {
      const sorted = [...prevUsers].sort((a, b) => {
        // Example: sorting by 'email', 'role', or 'id'
        const valA = (a as any)[params.field];
        const valB = (b as any)[params.field];
        if (valA < valB) return params.direction === 'ASC' ? -1 : 1;
        if (valA > valB) return params.direction === 'ASC' ? 1 : -1;
        return 0;
      });
      return sorted;
    });
  }

  /**
   * The column definitions for our Table component. This array
   * describes how each column is rendered, sorted, or hidden.
   */
  const columns = [
    {
      id: 'id',
      header: 'User ID',
      accessor: (row: User) => row.id,
      sortField: 'id',
      isSortable: true
    },
    {
      id: 'email',
      header: 'Email',
      accessor: (row: User) => row.email,
      sortField: 'email',
      isSortable: true
    },
    {
      id: 'role',
      header: 'Role',
      accessor: (row: User) => row.role,
      sortField: 'role',
      isSortable: true
    }
  ];

  /**
   * The table's pagination object. We rely on the custom Table approach:
   *   totalItems: totalUsers
   *   page: page
   *   pageSize: pageSize
   *   totalPages: computed from totalUsers / pageSize
   */
  const totalPages = Math.ceil(totalUsers / pageSize);

  const pagination = {
    page,
    pageSize,
    totalItems: totalUsers,
    totalPages: totalPages
  };

  /**
   * Handler for page changes. The Table calls these methods through
   * on the pagination footer. We then might do a local re-slice or
   * a server call for that page of data.
   */
  function handlePageChange(newPage: number) {
    setPage(newPage);
    // Potentially re-fetch data if server side
  }
  function handlePageSizeChange(newSize: number) {
    setPageSize(newSize);
    setPage(1); // Reset to first page if pageSize changes
  }

  /**
   * Renders any error states or a typical message if something goes wrong,
   * optionally re-tried by a button or some advanced flow.
   */
  function renderErrorState() {
    if (!error) return null;
    return (
      <div className="user-list__error">
        <p>Error: {error}</p>
      </div>
    );
  }

  return (
    <div className="user-list__container" ref={tableContainerRef}>
      <h2 className="user-list__title">{title}</h2>

      {/* If there's a filter dropdown for role-based filtering, we can provide it here */}
      <div className="user-list__filters">
        <label htmlFor="roleFilterSelect">Filter by Role:</label>
        <select
          id="roleFilterSelect"
          value={roleFilter}
          onChange={(e) => setRoleFilter(e.target.value as UserRole | 'ALL')}
        >
          <option value="ALL">All Roles</option>
          <option value={UserRole.ADMIN}>Admin</option>
          <option value={UserRole.OWNER}>Owner</option>
          <option value={UserRole.WALKER}>Walker</option>
        </select>
      </div>

      {renderErrorState()}

      <Table<User>
        data={users}
        columns={columns}
        onSort={(sortParams) => handleSort(sortParams)}
        pagination={pagination}
        isLoading={isLoading}
        columnVisibility={{
          // For demonstration, all columns are visible
          id: true,
          email: true,
          role: true
        }}
      />

      {/* The Table handles pagination UI, but we might implement a custom or additional pager */}
      <div className="user-list__pagination-controls">
        <button
          type="button"
          disabled={page <= 1}
          onClick={() => handlePageChange(page - 1)}
        >
          Previous
        </button>
        <span>
          Page {page} of {totalPages}
        </span>
        <button
          type="button"
          disabled={page >= totalPages}
          onClick={() => handlePageChange(page + 1)}
        >
          Next
        </button>
        <label htmlFor="pageSizeSelect">Items per page:</label>
        <select
          id="pageSizeSelect"
          value={pageSize}
          onChange={(e) => handlePageSizeChange(parseInt(e.target.value, 10))}
        >
          <option value={5}>5</option>
          <option value={10}>10</option>
          <option value={20}>20</option>
          <option value={50}>50</option>
        </select>
      </div>
    </div>
  );
};

export default UserList;