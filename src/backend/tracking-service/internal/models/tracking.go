package models

import (
	// time for handling timestamps and durations (go1.21)
	"time"
	// json for JSON serialization (go1.21)
	"encoding/json"
	// sync for concurrency control in tracking sessions (standard library)
	"sync"
	// math for distance calculations (standard library)
	"math"
	// errors for error creation (standard library)
	"errors"
	// uuid for generating unique identifiers (github.com/google/uuid v1.3.0)
	"github.com/google/uuid"
)

// SessionStatusActive indicates an ongoing tracking session.
const SessionStatusActive = "active" // Status for ongoing tracking sessions

// SessionStatusPaused indicates a temporarily paused tracking session.
const SessionStatusPaused = "paused" // Status for temporarily paused sessions

// SessionStatusCompleted indicates that the tracking session is finished.
const SessionStatusCompleted = "completed" // Status for finished sessions

// MaxLocationHistorySize defines the maximum number of location points kept in memory.
const MaxLocationHistorySize = 1000 // Maximum number of location points to store in memory

// MinLocationAccuracy defines the minimum required GPS accuracy (in meters) for accepted locations.
const MinLocationAccuracy = 10.0 // Minimum required GPS accuracy in meters

// TrackingSession represents an active dog walking tracking session with
// location history, statistics, and enhanced validation. It is designed to be
// thread-safe, ensuring concurrent access is properly managed with a mutex.
type TrackingSession struct {
	// ID is a unique identifier for the tracking session.
	ID string

	// status indicates the current state of the session, e.g. "active", "paused", or "completed".
	status string

	// walkID references the dog walk that this tracking session is associated with.
	walkID string

	// walkerID references the user ID of the walker managing this session.
	walkerID string

	// dogID references the dog involved in this walking session.
	dogID string

	// startTime captures the timestamp when the session was initiated.
	startTime time.Time

	// endTime captures the timestamp when the session was completed.
	endTime time.Time

	// locationHistory maintains all successfully recorded locations for this session.
	locationHistory []Location

	// totalDistance tracks the cumulative distance covered (in meters).
	totalDistance float64

	// duration represents the total duration of this session.
	duration time.Duration

	// lastUpdateTime captures the most recent time at which the session was updated.
	lastUpdateTime time.Time

	// bufferSize defines an upper bound on how many location points may be stored.
	bufferSize int

	// isArchived indicates whether the session is prepared or marked for archival.
	isArchived bool

	// mutex provides concurrency control for critical operations.
	mutex *sync.Mutex
}

// TrackingStatistics contains comprehensive calculated statistics for a
// tracking session. Some fields are exposed for external usage, and others
// remain unexported for internal analysis.
type TrackingStatistics struct {
	// TotalDistance is the cumulative distance of the tracking session in meters.
	TotalDistance float64

	// AverageSpeed is the overall average speed (meters/second).
	AverageSpeed float64

	// Duration is the total session duration.
	Duration time.Duration

	// MaxSpeed is the maximum instantaneous speed (meters/second) observed.
	MaxSpeed float64

	// MinSpeed is the minimum instantaneous speed (meters/second) observed.
	MinSpeed float64

	locationPoints   int
	startTime        time.Time
	endTime          time.Time
	averageAccuracy  float64
	hasGaps          bool
}

// NewTrackingSession creates a new, thread-safe tracking session with initialized
// buffers and validated inputs. An error is returned if any validation fails.
//
// Steps:
//   1. Generate unique session ID using UUID v4
//   2. Initialize session with provided IDs
//   3. Set status to "active"
//   4. Set start time to current time
//   5. Initialize location history with specified buffer size
//   6. Set last update time to current time
//   7. Initialize mutex for thread-safe access
//   8. Validate all input parameters
//   9. Return error if validation fails
func NewTrackingSession(walkID, walkerID, dogID string, bufferSize int) (*TrackingSession, error) {
	if err := validateNewSessionInput(walkID, walkerID, dogID, bufferSize); err != nil {
		return nil, err
	}

	session := &TrackingSession{
		ID:             uuid.NewString(),
		status:         SessionStatusActive,
		walkID:         walkID,
		walkerID:       walkerID,
		dogID:          dogID,
		startTime:      time.Now().UTC(),
		endTime:        time.Time{}, // zero value until completed
		locationHistory: make([]Location, 0, 0),
		totalDistance:   0.0,
		duration:        0,
		lastUpdateTime:  time.Now().UTC(),
		bufferSize:      bufferSize,
		isArchived:      false,
		mutex:           &sync.Mutex{},
	}
	return session, nil
}

// AddLocation adds a new location point to the session history with validation
// and thread safety.
//
// Steps:
//   1. Acquire mutex lock
//   2. Validate location data accuracy against MinLocationAccuracy
//   3. Check if session status is "active"
//   4. Verify that buffer capacity has not been exceeded
//   5. Append the new location to the history
//   6. Update total distance based on the last location (if any)
//   7. Update last update time
//   8. Release mutex lock
//   9. Return nil if successful
func (s *TrackingSession) AddLocation(loc *Location) error {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	// Ensure location has acceptable accuracy (less than or equal to MinLocationAccuracy).
	if loc.Accuracy > MinLocationAccuracy {
		return errors.New("location accuracy is too low to be added")
	}

	// Check if the session is active.
	if s.status != SessionStatusActive {
		return errors.New("cannot add location because session is not active")
	}

	// If bufferSize is set and we have reached capacity, return an error.
	if s.bufferSize > 0 && len(s.locationHistory) >= s.bufferSize {
		return errors.New("location buffer is full, cannot add more points")
	}

	// Append the location record to history.
	s.locationHistory = append(s.locationHistory, *loc)

	// If we have a previous location, compute the distance increment.
	currLen := len(s.locationHistory)
	if currLen > 1 {
		prev := s.locationHistory[currLen-2]
		dist := distanceBetweenPoints(
			prev.Latitude,
			prev.Longitude,
			loc.Latitude,
			loc.Longitude,
		)
		s.totalDistance += dist
	}

	// Update the session duration based on StartTime and new location timestamp if valid.
	if !loc.Timestamp.IsZero() && loc.Timestamp.After(s.startTime) {
		s.duration = loc.Timestamp.Sub(s.startTime)
	}

	// Update the last update time.
	s.lastUpdateTime = time.Now().UTC()

	return nil
}

// CalculateStatistics calculates comprehensive session metrics in a thread-safe
// manner, returning a pointer to TrackingStatistics or an error if the
// calculation fails.
//
// Steps:
//   1. Acquire mutex lock
//   2. Calculate total distance from session data
//   3. Calculate duration based on session times
//   4. Compute average speed = totalDistance / duration
//   5. Iterate over location history to find min/max speed, detect gaps, compute accuracy
//   6. Release mutex lock
//   7. Return the calculated statistics
func (s *TrackingSession) CalculateStatistics() (*TrackingStatistics, error) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	// If no location history, return minimal stats.
	if len(s.locationHistory) == 0 {
		return &TrackingStatistics{}, nil
	}

	stats := &TrackingStatistics{
		TotalDistance: s.totalDistance,
		Duration:      s.duration,
		locationPoints: len(s.locationHistory),
		startTime:     s.startTime,
		endTime:       s.endTime,
	}

	// If the session has no recorded endTime, we assume "now" if it is still active.
	var effectiveEnd time.Time
	if s.endTime.IsZero() && s.status == SessionStatusActive {
		effectiveEnd = time.Now().UTC()
	} else if !s.endTime.IsZero() {
		effectiveEnd = s.endTime
	} else {
		// If paused or other states, fallback to the last update time or now
		effectiveEnd = s.lastUpdateTime
	}
	// Update stats.Duration if needed.
	if effectiveEnd.After(s.startTime) {
		stats.Duration = effectiveEnd.Sub(s.startTime)
	}

	// Compute average speed (m/s).
	if stats.Duration.Seconds() > 0 {
		stats.AverageSpeed = stats.TotalDistance / stats.Duration.Seconds()
	}

	// Initialize for min/max speed calculations.
	var minSp float64 = -1
	var maxSp float64
	var totalAccuracy float64
	stats.hasGaps = false

	// We'll detect large time gaps (e.g., > 5 minutes) as "gaps".
	const gapThreshold = 5 * 60.0

	for i := 1; i < len(s.locationHistory); i++ {
		currLoc := s.locationHistory[i]
		prevLoc := s.locationHistory[i-1]

		// Accumulate accuracy for average.
		totalAccuracy += currLoc.Accuracy

		// Calculate the distance between consecutive points.
		dist := distanceBetweenPoints(
			prevLoc.Latitude,
			prevLoc.Longitude,
			currLoc.Latitude,
			currLoc.Longitude,
		)
		timeDiff := currLoc.Timestamp.Sub(prevLoc.Timestamp).Seconds()

		if timeDiff > 0 {
			speed := dist / timeDiff
			if minSp < 0 || speed < minSp {
				minSp = speed
			}
			if speed > maxSp {
				maxSp = speed
			}
		}

		// Check for time gap.
		if timeDiff > gapThreshold {
			stats.hasGaps = true
		}
	}

	// Also account for the first location's accuracy.
	if len(s.locationHistory) > 0 {
		totalAccuracy += s.locationHistory[0].Accuracy
	}

	// Populate final metrics.
	if minSp < 0 {
		// If there was only one location or we couldn't compute speed at all.
		minSp = 0
	}
	stats.MinSpeed = minSp
	stats.MaxSpeed = maxSp
	if len(s.locationHistory) > 0 {
		stats.averageAccuracy = totalAccuracy / float64(len(s.locationHistory))
	}

	return stats, nil
}

// Complete marks the tracking session as completed and prepares it for archival.
// Steps:
//   1. Acquire mutex lock
//   2. Verify session can be completed
//   3. Set end time to current time
//   4. Calculate final statistics
//   5. Set status to "completed"
//   6. Prepare for archival
//   7. Release mutex lock
//   8. Return nil if successful
func (s *TrackingSession) Complete() error {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	if s.status != SessionStatusActive && s.status != SessionStatusPaused {
		return errors.New("session cannot be completed in its current state")
	}

	// Mark the session's official end time.
	s.endTime = time.Now().UTC()

	// Calculate final stats (ignoring errors).
	_, _ = s.CalculateStatistics()

	// Update the session status to completed.
	s.status = SessionStatusCompleted

	// Prepare for archival.
	s.isArchived = false

	return nil
}

// ID returns the unique identifier for this session.
func (s *TrackingSession) IDValue() string {
	return s.ID
}

// Status returns the current status of the session.
func (s *TrackingSession) Status() string {
	return s.status
}

// MarshalJSON provides a custom JSON representation of TrackingSession with
// necessary fields. The location history is omitted to reduce payload size
// unless needed in specialized endpoints.
func (s *TrackingSession) MarshalJSON() ([]byte, error) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	type alias TrackingSession
	temp := struct {
		ID            string    `json:"id"`
		Status        string    `json:"status"`
		WalkID        string    `json:"walkId"`
		WalkerID      string    `json:"walkerId"`
		DogID         string    `json:"dogId"`
		StartTime     time.Time `json:"startTime"`
		EndTime       time.Time `json:"endTime"`
		TotalDistance float64   `json:"totalDistance"`
		Duration      float64   `json:"durationSeconds"`
		LastUpdate    time.Time `json:"lastUpdateTime"`
		IsArchived    bool      `json:"isArchived"`
	}{
		ID:            s.ID,
		Status:        s.status,
		WalkID:        s.walkID,
		WalkerID:      s.walkerID,
		DogID:         s.dogID,
		StartTime:     s.startTime,
		EndTime:       s.endTime,
		TotalDistance: s.totalDistance,
		// Export duration in seconds to keep it simpler in JSON.
		Duration:   s.duration.Seconds(),
		LastUpdate: s.lastUpdateTime,
		IsArchived: s.isArchived,
	}

	return json.Marshal(temp)
}

// validateNewSessionInput checks basic requirements for creating a session.
func validateNewSessionInput(walkID, walkerID, dogID string, bufferSize int) error {
	if walkID == "" {
		return errors.New("walkID must not be empty")
	}
	if walkerID == "" {
		return errors.New("walkerID must not be empty")
	}
	if dogID == "" {
		return errors.New("dogID must not be empty")
	}
	if bufferSize < 0 || bufferSize > MaxLocationHistorySize {
		return errors.New("bufferSize must be between 0 and MaxLocationHistorySize")
	}
	return nil
}

// distanceBetweenPoints calculates the approximate distance (in meters) between
// two latitude-longitude points using the Haversine formula.
func distanceBetweenPoints(lat1, lon1, lat2, lon2 float64) float64 {
	const earthRadius = 6371000.0 // Earth radius in meters

	// Convert degrees to radians.
	rlat1 := lat1 * math.Pi / 180.0
	rlat2 := lat2 * math.Pi / 180.0
	dlat := (lat2 - lat1) * math.Pi / 180.0
	dlon := (lon2 - lon1) * math.Pi / 180.0

	a := math.Sin(dlat/2)*math.Sin(dlat/2) +
		math.Cos(rlat1)*math.Cos(rlat2)*math.Sin(dlon/2)*math.Sin(dlon/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))

	return earthRadius * c
}