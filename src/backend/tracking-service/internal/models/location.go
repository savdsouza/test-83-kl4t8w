package models

import (
	// time for handling timestamps and ensuring temporal accuracy in location records (go1.21)
	"time"
	// json package for efficient JSON serialization and deserialization of location data with error handling (go1.21)
	"encoding/json"
	// uuid package for generating UUID v4 (v1.3.0)
	"github.com/google/uuid"
)

// MinLatitude represents the minimum valid latitude coordinate.
const MinLatitude float64 = -90.0

// MaxLatitude represents the maximum valid latitude coordinate.
const MaxLatitude float64 = 90.0

// MinLongitude represents the minimum valid longitude coordinate.
const MinLongitude float64 = -180.0

// MaxLongitude represents the maximum valid longitude coordinate.
const MaxLongitude float64 = 180.0

// DefaultAccuracy defines the default GPS accuracy in meters.
const DefaultAccuracy float64 = 10.0

// MaxAccuracy defines the maximum acceptable GPS accuracy in meters.
const MaxAccuracy float64 = 100.0

// Location represents a single GPS location point with coordinates, timestamp,
// and accuracy metrics. It includes comprehensive validation, serialization,
// and data integrity checks for real-time tracking scenarios.
type Location struct {
	// ID is a unique identifier for the location point (UUID v4).
	ID string `json:"id"`

	// WalkID links this location to a specific dog walk session.
	WalkID string `json:"walkId"`

	// Latitude represents the latitude coordinate associated with this location.
	Latitude float64 `json:"latitude"`

	// Longitude represents the longitude coordinate associated with this location.
	Longitude float64 `json:"longitude"`

	// Accuracy indicates the positional accuracy in meters.
	Accuracy float64 `json:"accuracy"`

	// Altitude represents the height above sea level in meters.
	Altitude float64 `json:"altitude"`

	// Timestamp captures the exact time this location was recorded, in UTC.
	Timestamp time.Time `json:"timestamp"`

	// IsValid indicates whether the current location data has passed validation.
	IsValid bool `json:"isValid"`
}

// NewLocation creates a new Location instance with comprehensive validation
// and initialization. The function returns an error if any validation step fails.
func NewLocation(
	walkID string,
	latitude float64,
	longitude float64,
	accuracy float64,
	altitude float64,
) (Location, error) {

	var loc Location

	// Generate unique ID using UUID v4
	newID := uuid.NewString()
	loc.ID = newID

	// Assign WalkID, ensuring it is not empty
	loc.WalkID = walkID

	// Set latitude and longitude
	loc.Latitude = latitude
	loc.Longitude = longitude

	// Choose accuracy: if zero is provided, default to DefaultAccuracy
	if accuracy == 0 {
		loc.Accuracy = DefaultAccuracy
	} else {
		loc.Accuracy = accuracy
	}

	// Set altitude
	loc.Altitude = altitude

	// Set timestamp to current UTC time
	loc.Timestamp = time.Now().UTC()

	// Perform a full validation on the location
	if err := loc.Validate(); err != nil {
		return loc, err
	}

	// If all validation checks pass, IsValid will be true
	return loc, nil
}

// Validate performs comprehensive checks on the Location fields:
//  1. ID must be a valid UUID.
//  2. WalkID cannot be empty.
//  3. Latitude must be within [-90.0, 90.0].
//  4. Longitude must be within [-180.0, 180.0].
//  5. Accuracy must be within [0.0, MaxAccuracy].
//  6. Timestamp must be non-zero and not significantly in the future.
func (l *Location) Validate() error {
	// Verify ID is valid UUID
	if _, parseErr := uuid.Parse(l.ID); parseErr != nil {
		l.IsValid = false
		return parseErr
	}

	// Check that WalkID is not empty
	if l.WalkID == "" {
		l.IsValid = false
		return ErrInvalidWalkID("WalkID cannot be empty")
	}

	// Check latitude bounds
	if l.Latitude < MinLatitude || l.Latitude > MaxLatitude {
		l.IsValid = false
		return ErrOutOfRange("Latitude is out of valid range")
	}

	// Check longitude bounds
	if l.Longitude < MinLongitude || l.Longitude > MaxLongitude {
		l.IsValid = false
		return ErrOutOfRange("Longitude is out of valid range")
	}

	// Verify accuracy range
	if l.Accuracy < 0.0 || l.Accuracy > MaxAccuracy {
		l.IsValid = false
		return ErrOutOfRange("Accuracy is out of valid range")
	}

	// Ensure timestamp is not the zero value
	if l.Timestamp.IsZero() {
		l.IsValid = false
		return ErrInvalidTimestamp("Timestamp cannot be zero")
	}

	// Disallow timestamps significantly in the future
	nowUTC := time.Now().UTC()
	if l.Timestamp.After(nowUTC.Add(1 * time.Minute)) {
		l.IsValid = false
		return ErrInvalidTimestamp("Timestamp is set too far in the future")
	}

	// If all checks pass
	l.IsValid = true
	return nil
}

// ToJSON serializes the Location data into its JSON representation. If any
// validation step fails, an error will be returned instead of JSON data.
func (l *Location) ToJSON() ([]byte, error) {
	// Validate location data before serialization
	if err := l.Validate(); err != nil {
		return nil, err
	}

	// Marshal Location struct to JSON
	jsonData, err := json.Marshal(l)
	if err != nil {
		return nil, err
	}
	return jsonData, nil
}

// FromJSON creates a new Location instance from the provided JSON data,
// performs complete validation, and returns an error if any step fails.
func FromJSON(data []byte) (Location, error) {
	var loc Location

	// Unmarshal JSON data into a temporary Location struct
	if err := json.Unmarshal(data, &loc); err != nil {
		return loc, err
	}

	// Validate the newly populated fields
	if err := loc.Validate(); err != nil {
		return loc, err
	}

	return loc, nil
}

// ErrInvalidWalkID is returned when the provided WalkID is empty or invalid.
type ErrInvalidWalkID string

func (e ErrInvalidWalkID) Error() string {
	return string(e)
}

// ErrOutOfRange is returned when a numeric field such as latitude, longitude,
// or accuracy is outside of acceptable bounds.
type ErrOutOfRange string

func (e ErrOutOfRange) Error() string {
	return string(e)
}

// ErrInvalidTimestamp is returned when the timestamp field is invalid.
type ErrInvalidTimestamp string

func (e ErrInvalidTimestamp) Error() string {
	return string(e)
}