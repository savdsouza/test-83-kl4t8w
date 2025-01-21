package com.dogwalking.booking.models;

// -------------------------------------------
// External Imports with Version Comments
// -------------------------------------------
// javax.persistence 2.2
import javax.persistence.Entity;
import javax.persistence.Table;
import javax.persistence.Id;
import javax.persistence.GeneratedValue;
import javax.persistence.Column;
import javax.persistence.Version;
import javax.persistence.PrePersist;
import javax.persistence.PreUpdate;
import javax.persistence.Enumerated;
import javax.persistence.EnumType;
// javax.validation.constraints 2.0.1
import javax.validation.constraints.NotNull;
import javax.validation.constraints.Future;
// java.util 17
import java.util.UUID;
import java.util.Date;
// java.math 17
import java.math.BigDecimal;

/**
 * Booking entity model that captures all relevant information for
 * a dog walking service booking, including scheduling, pricing, and
 * comprehensive walk tracking details. This class is annotated as a
 * JPA entity that maps to the "bookings" table in the database.
 *
 * <p>It leverages fields for start/end times (both scheduled and actual),
 * assigned participants (owner, walker, dog), location-based information,
 * financial calculations (price), and thorough status tracking with
 * service execution details (photos, notes, duration calculations).
 */
@Entity
@Table(name = "bookings")
public class Booking {

    /**
     * Enumeration describing the possible statuses of a booking.
     * This includes standard states that represent the entire
     * lifecycle of a dog walking booking.
     */
    public enum BookingStatus {
        REQUESTED,
        CONFIRMED,
        CANCELLED,
        COMPLETED
    }

    /**
     * Primary key for the booking record. This is a unique and
     * automatically generated identifier leveraging UUID.
     */
    @Id
    @GeneratedValue
    @Column(name = "id", updatable = false, nullable = false)
    private UUID id;

    /**
     * The ownerId references the user who created or requested
     * the dog walking service. Required field indicating the owner.
     */
    @NotNull
    @Column(name = "owner_id", nullable = false)
    private UUID ownerId;

    /**
     * The walkerId references the dog walker who accepted the
     * booking. Can be null when the booking is initially created
     * until a walker confirms or is assigned.
     */
    @Column(name = "walker_id")
    private UUID walkerId;

    /**
     * The dogId is the unique identifier of the dog for which this
     * walk is scheduled. Required for ensuring correct dog information.
     */
    @NotNull
    @Column(name = "dog_id", nullable = false)
    private UUID dogId;

    /**
     * The scheduled start time for the booking, indicating when
     * the walk is planned to begin. This value must be in the future
     * at the time of creation if the service is scheduled ahead.
     */
    @NotNull
    @Future
    @Column(name = "start_time", nullable = false)
    private Date startTime;

    /**
     * The scheduled end time for the booking, indicating when
     * the walk is expected to finish. This can also be a future
     * date, and may be adjusted as needed.
     */
    @Future
    @Column(name = "end_time")
    private Date endTime;

    /**
     * The actual start time recorded when the walk truly begins.
     * Useful for measuring actual duration and usage patterns.
     */
    @Column(name = "actual_start_time")
    private Date actualStartTime;

    /**
     * The actual end time recorded when the walk truly concludes.
     * Helps in calculating precise billing and completion status.
     */
    @Column(name = "actual_end_time")
    private Date actualEndTime;

    /**
     * The price for the dog walking service. Uses BigDecimal for
     * precision in financial calculations and to avoid floating
     * point inaccuracies.
     */
    @NotNull
    @Column(name = "price", precision = 10, scale = 2, nullable = false)
    private BigDecimal price;

    /**
     * The booking status, represented by the BookingStatus enum type.
     * String-based enumeration allows for more readable values in the DB.
     */
    @NotNull
    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    private BookingStatus status;

    /**
     * A textual representation of the walk's starting location.
     * Could be an address or coordinates stored as a string.
     */
    @Column(name = "start_location")
    private String startLocation;

    /**
     * A textual representation of the walk's ending location.
     * Initially, this can be unspecified until the walk is complete.
     */
    @Column(name = "end_location")
    private String endLocation;

    /**
     * Distance of the walk in some chosen unit (e.g., miles).
     * Calculated or updated once the walk is complete or in progress.
     */
    @Column(name = "walk_distance")
    private Double walkDistance;

    /**
     * An array of URLs corresponding to photos taken during the walk.
     * These photos may be stored in an external cloud storage, so only
     * the links are preserved here.
     *
     * Note: Database storage may vary based on the implementation.
     */
    @Column(name = "photo_urls")
    private String[] photoUrls;

    /**
     * Notes provided by the walker about the walk, dog behavior, or
     * any events during execution of the walk.
     */
    @Column(name = "walker_notes", length = 2000)
    private String walkerNotes;

    /**
     * Notes provided by the owner, such as special instructions,
     * feeding or medication details, or any constraints to watch out for.
     */
    @Column(name = "owner_notes", length = 2000)
    private String ownerNotes;

    /**
     * Used for optimistic locking, prevents simultaneous updates
     * from overwriting each other. Automatically managed by JPA.
     */
    @Version
    @Column(name = "version")
    private Integer version;

    /**
     * The identifier of the user or process that created this booking
     * record for audit purposes.
     */
    @Column(name = "created_by")
    private UUID createdBy;

    /**
     * The identifier of the user or process that last modified this
     * booking record, useful for traceability and auditing.
     */
    @Column(name = "last_modified_by")
    private UUID lastModifiedBy;

    /**
     * The timestamp indicating when this booking record was first
     * created and persisted to the database.
     */
    @Column(name = "created_at", updatable = false)
    private Date createdAt;

    /**
     * The timestamp indicating the most recent moment this booking
     * record was updated in the database.
     */
    @Column(name = "updated_at")
    private Date updatedAt;

    /**
     * Default constructor for JPA with enhanced initialization.
     * <ul>
     *   <li>Initialize empty booking object.</li>
     *   <li>Set default status to REQUESTED.</li>
     *   <li>Initialize empty collections or arrays.</li>
     * </ul>
     */
    public Booking() {
        this.status = BookingStatus.REQUESTED;
        this.photoUrls = new String[0];
    }

    /**
     * Lifecycle callback that is invoked before a new entity is persisted.
     * Automatically sets creation timestamp and can be used to set any
     * additional fields necessary for a brand-new record.
     */
    @PrePersist
    protected void onPrePersist() {
        Date now = new Date();
        if (this.createdAt == null) {
            this.createdAt = now;
        }
        if (this.id == null) {
            // In some cases, an assigned generator might be used, but we ensure a fallback:
            this.id = UUID.randomUUID();
        }
        this.updatedAt = now;
    }

    /**
     * Lifecycle callback that is invoked before an existing entity is updated.
     * Automatically updates the modification timestamp and can handle any
     * other tasks required before saving updated information.
     */
    @PreUpdate
    protected void onPreUpdate() {
        this.updatedAt = new Date();
    }

    /**
     * Retrieves the booking's unique identifier.
     *
     * @return The booking's id field as a UUID
     */
    public UUID getId() {
        return id;
    }

    /**
     * Updates the current booking status with basic validation and
     * triggers relevant side effects such as timestamp updates or
     * event notifications.
     *
     * @param newStatus The new status being applied to the booking
     */
    public void updateStatus(BookingStatus newStatus) {
        // Validate basic status transitions. For example, if booking is
        // CANCELLED or COMPLETED, do not allow further changes.
        if (this.status == BookingStatus.CANCELLED || this.status == BookingStatus.COMPLETED) {
            // In a production environment, we might throw an exception here.
            return;
        }

        // Example extension: further business logic to confirm or disallow transitions.
        this.status = newStatus;

        // Set the updatedAt timestamp to reflect the status change.
        this.updatedAt = new Date();

        // Trigger additional side effects or events (placeholder).
        // e.g., eventPublisher.publishStatusChange(this);
    }

    /**
     * Adds a new photo URL to the booking's photo list after validating
     * basic URL format. Also updates the modification timestamp.
     *
     * @param photoUrl A string URL referencing the photo location
     */
    public void addPhoto(String photoUrl) {
        // Very basic sanity check for demonstration; in a real system,
        // URL validation would be more sophisticated.
        if (photoUrl == null || !photoUrl.startsWith("http")) {
            return;
        }

        // Grow array size by 1 and add the new photo URL.
        int currentSize = this.photoUrls.length;
        String[] newArray = new String[currentSize + 1];
        System.arraycopy(this.photoUrls, 0, newArray, 0, currentSize);
        newArray[currentSize] = photoUrl;
        this.photoUrls = newArray;

        // Update the 'updatedAt' with the new modification time.
        this.updatedAt = new Date();
    }

    /**
     * Calculates the actual duration of the walk in minutes, based on
     * the recorded actualStartTime and actualEndTime. Returns 0 if
     * either is not set or if the end time precedes the start time.
     *
     * @return Long value representing the duration of the walk in minutes
     */
    public Long calculateDuration() {
        if (this.actualStartTime == null || this.actualEndTime == null) {
            return 0L;
        }
        long diff = this.actualEndTime.getTime() - this.actualStartTime.getTime();
        return diff > 0 ? diff / (1000 * 60) : 0L;
    }

    // ----------------------------------------------------------------
    // Below are additional getters and setters to fulfill typical
    // enterprise-level access requirements. They can be expanded or
    // restricted as necessary for business security considerations.
    // ----------------------------------------------------------------

    public void setId(UUID id) {
        this.id = id;
    }

    public UUID getOwnerId() {
        return ownerId;
    }

    public void setOwnerId(UUID ownerId) {
        this.ownerId = ownerId;
    }

    public UUID getWalkerId() {
        return walkerId;
    }

    public void setWalkerId(UUID walkerId) {
        this.walkerId = walkerId;
    }

    public UUID getDogId() {
        return dogId;
    }

    public void setDogId(UUID dogId) {
        this.dogId = dogId;
    }

    public Date getStartTime() {
        return startTime;
    }

    public void setStartTime(Date startTime) {
        this.startTime = startTime;
    }

    public Date getEndTime() {
        return endTime;
    }

    public void setEndTime(Date endTime) {
        this.endTime = endTime;
    }

    public Date getActualStartTime() {
        return actualStartTime;
    }

    public void setActualStartTime(Date actualStartTime) {
        this.actualStartTime = actualStartTime;
    }

    public Date getActualEndTime() {
        return actualEndTime;
    }

    public void setActualEndTime(Date actualEndTime) {
        this.actualEndTime = actualEndTime;
    }

    public BigDecimal getPrice() {
        return price;
    }

    public void setPrice(BigDecimal price) {
        this.price = price;
    }

    public BookingStatus getStatus() {
        return status;
    }

    public String getStartLocation() {
        return startLocation;
    }

    public void setStartLocation(String startLocation) {
        this.startLocation = startLocation;
    }

    public String getEndLocation() {
        return endLocation;
    }

    public void setEndLocation(String endLocation) {
        this.endLocation = endLocation;
    }

    public Double getWalkDistance() {
        return walkDistance;
    }

    public void setWalkDistance(Double walkDistance) {
        this.walkDistance = walkDistance;
    }

    public String[] getPhotoUrls() {
        return photoUrls;
    }

    public void setPhotoUrls(String[] photoUrls) {
        this.photoUrls = photoUrls;
    }

    public String getWalkerNotes() {
        return walkerNotes;
    }

    public void setWalkerNotes(String walkerNotes) {
        this.walkerNotes = walkerNotes;
    }

    public String getOwnerNotes() {
        return ownerNotes;
    }

    public void setOwnerNotes(String ownerNotes) {
        this.ownerNotes = ownerNotes;
    }

    public Integer getVersion() {
        return version;
    }

    public void setVersion(Integer version) {
        this.version = version;
    }

    public UUID getCreatedBy() {
        return createdBy;
    }

    public void setCreatedBy(UUID createdBy) {
        this.createdBy = createdBy;
    }

    public UUID getLastModifiedBy() {
        return lastModifiedBy;
    }

    public void setLastModifiedBy(UUID lastModifiedBy) {
        this.lastModifiedBy = lastModifiedBy;
    }

    public Date getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Date createdAt) {
        this.createdAt = createdAt;
    }

    public Date getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(Date updatedAt) {
        this.updatedAt = updatedAt;
    }
}