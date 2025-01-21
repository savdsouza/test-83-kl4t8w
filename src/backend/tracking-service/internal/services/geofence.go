package services

import (
	// time for handling timestamps in geofence operations and tracking creation/modification times (go1.21)
	"time"

	// errors for comprehensive error handling throughout geofence validations and updates (go1.21)
	"errors"

	// math for rounding operations in parameter validation and potential coordinate clamping
	"math"

	// fmt for formatting error messages, when needed
	"fmt"

	// uuid for generating unique V4 UUIDs for geofence IDs (v1.3.0)
	"github.com/google/uuid"

	// models provides the Location struct used for real-time GPS coordinate representations
	"src/backend/tracking-service/internal/models"

	// utils provides the CalculateDistance function for haversine-based distance calculations
	"src/backend/tracking-service/internal/utils"
)

// DefaultRadius is the default geofence radius in kilometers for standard walking zones.
const DefaultRadius = 0.5 // Default geofence radius in kilometers for standard walking zones

// MaxRadius is the maximum allowed geofence radius in kilometers to ensure safety and performance.
const MaxRadius = 5.0 // Maximum allowed geofence radius in kilometers for safety and performance

// MinRadius is the minimum allowed geofence radius in kilometers to ensure meaningful boundaries.
const MinRadius = 0.1 // Minimum allowed geofence radius in kilometers to ensure meaningful boundaries

// Geofence represents a circular geofence boundary for a dog walk with real-time containment checks
// and dynamic radius management. It includes tracking of boundary violations, activation state, and
// creation/update timestamps. The struct is designed to be used in conjunction with location data
// to ensure safe and contained dog walking sessions.
type Geofence struct {
	// ID is a unique identifier for the geofence, generated as a UUIDv4 at creation.
	ID string

	// WalkID links this geofence to a particular walk session, providing context for containment checks.
	WalkID string

	// CenterLatitude is the geofence center's latitude in degrees.
	CenterLatitude float64

	// CenterLongitude is the geofence center's longitude in degrees.
	CenterLongitude float64

	// RadiusKm represents the current radius of the geofence in kilometers. It must be between
	// MinRadius and MaxRadius values and can be updated dynamically if the geofence remains active.
	RadiusKm float64

	// CreatedAt captures the timestamp of when this geofence was initially created.
	CreatedAt time.Time

	// UpdatedAt captures the timestamp of the most recent update to this geofence.
	UpdatedAt time.Time

	// Active indicates whether the geofence is currently active. Once deactivated, it should not be updated further.
	Active bool

	// BoundaryViolations counts how many times a provided point was found to be outside this geofence boundary.
	BoundaryViolations int
}

// ValidateGeofenceParameters performs comprehensive validation for latitude, longitude, and radius
// parameters supplied during geofence creation or updates. It ensures:
//   1. Latitude is within [-90.0, 90.0].
//   2. Longitude is within [-180.0, 180.0].
//   3. Radius is within [MinRadius, MaxRadius].
//   4. Coordinate precision is validated by checking for NaN/Infinity.
//
// Returns an error if any parameter is invalid, or nil on success.
func ValidateGeofenceParameters(latitude, longitude, radius float64) error {
	// Check for non-finite coordinate values (NaN or ±Inf)
	if math.IsNaN(latitude) || math.IsNaN(longitude) || math.IsNaN(radius) {
		return errors.New("geofence parameter validation failed: parameter is NaN")
	}
	if math.IsInf(latitude, 0) || math.IsInf(longitude, 0) || math.IsInf(radius, 0) {
		return errors.New("geofence parameter validation failed: parameter is infinite")
	}

	// Latitude range check
	if latitude < models.MinLatitude || latitude > models.MaxLatitude {
		return fmt.Errorf("geofence parameter validation failed: latitude %.6f out of range", latitude)
	}

	// Longitude range check
	if longitude < models.MinLongitude || longitude > models.MaxLongitude {
		return fmt.Errorf("geofence parameter validation failed: longitude %.6f out of range", longitude)
	}

	// Radius range check
	if radius < MinRadius || radius > MaxRadius {
		return fmt.Errorf("geofence parameter validation failed: radius %.3f out of range [%.3f, %.3f]", radius, MinRadius, MaxRadius)
	}

	// If all checks pass, return nil indicating valid parameters
	return nil
}

// NewGeofence creates a new Geofence instance using the provided walkID, latitude, longitude, and radiusKm.
// It performs complete input parameter validation, applies clamping for the radius if out of range, and
// initializes the geofence in an active state with zero boundary violations. If validation fails, an error is returned.
//
// Steps:
//  1. Generate a unique geofence ID using UUID v4.
//  2. Validate input parameters using ValidateGeofenceParameters.
//  3. Clamp radius between MinRadius and MaxRadius if necessary.
//  4. Initialize creation and update timestamps to the current UTC time.
//  5. Mark the geofence as active and set boundary violations to zero.
//  6. Return the constructed Geofence and any error if present.
func NewGeofence(walkID string, latitude, longitude, radiusKm float64) (*Geofence, error) {
	// Generate unique geofence ID
	newID := uuid.NewString()

	// Validate input parameters
	if err := ValidateGeofenceParameters(latitude, longitude, radiusKm); err != nil {
		return nil, err
	}

	// Clamp the radius if out of configured min/max range
	finalRadius := radiusKm
	if radiusKm < MinRadius {
		finalRadius = MinRadius
	} else if radiusKm > MaxRadius {
		finalRadius = MaxRadius
	}

	// Prepare and initialize the Geofence struct
	nowUTC := time.Now().UTC()
	gf := &Geofence{
		ID:                newID,
		WalkID:            walkID,
		CenterLatitude:    latitude,
		CenterLongitude:   longitude,
		RadiusKm:          finalRadius,
		CreatedAt:         nowUTC,
		UpdatedAt:         nowUTC,
		Active:            true,
		BoundaryViolations: 0,
	}

	return gf, nil
}

// ContainsPoint checks if the given Location point lies within the geofence boundary.
// It performs the following steps:
//   1. Verifies that the geofence is currently active; returns an error if inactive.
//   2. Validates the input point, ensuring it meets location constraints.
//   3. Calculates the distance between the geofence center and the point using the haversine formula
//      via the CalculateDistance function.
//   4. Compares the distance to the RadiusKm of the geofence.
//   5. If the point is outside the boundary, increments the BoundaryViolations counter.
//   6. Returns a boolean indicating containment (true) or exclusion (false), along with any error.
//
// Returns (true, nil) if the point is within the geofence,
// Returns (false, nil) if the point is outside the geofence,
// or returns an error if the geofence is inactive or if any validation fails.
func (g *Geofence) ContainsPoint(point *models.Location) (bool, error) {
	// Check if geofence is active
	if !g.Active {
		return false, errors.New("containsPoint error: geofence is inactive")
	}

	// Validate the input Location
	if point == nil {
		return false, errors.New("containsPoint error: nil location provided")
	}
	if err := point.Validate(); err != nil {
		return false, fmt.Errorf("containsPoint error: invalid location data: %w", err)
	}

	// Build a temporary Location struct to represent the geofence center
	center := &models.Location{
		ID:        "", // not relevant for distance calculation
		WalkID:    g.WalkID,
		Latitude:  g.CenterLatitude,
		Longitude: g.CenterLongitude,
		// other fields can remain zeroed out
	}

	// Calculate distance from geofence center to the provided point
	distance, err := utils.CalculateDistance(center, point)
	if err != nil {
		return false, fmt.Errorf("containsPoint error: distance calculation failed: %w", err)
	}

	// Check if the distance is within the geofence radius
	if distance <= g.RadiusKm {
		// Point is inside the boundary
		return true, nil
	}

	// If point is outside, increment boundary violation counter
	g.BoundaryViolations++
	return false, nil
}

// UpdateRadius attempts to update the geofence's RadiusKm to the newRadius specified,
// applying the same parameter validation rules used at creation. Clamping is also enforced.
// If the geofence is inactive, or validation fails, an error is returned.
//
// Steps:
//  1. Check if the geofence is active; return an error if inactive.
//  2. Validate newRadius using ValidateGeofenceParameters (only radius constraints are critical here).
//  3. Clamp newRadius if it is out of the allowed [MinRadius, MaxRadius] range.
//  4. Update the geofence's RadiusKm and record the UpdatedAt time.
//  5. Return an error if any validation fails, otherwise nil.
func (g *Geofence) UpdateRadius(newRadius float64) error {
	// Ensure geofence is active
	if !g.Active {
		return errors.New("updateRadius error: cannot update an inactive geofence")
	}

	// Validate geofence parameters using the current center and proposed new radius
	if err := ValidateGeofenceParameters(g.CenterLatitude, g.CenterLongitude, newRadius); err != nil {
		return err
	}

	// Clamp the new radius within configured boundaries
	adjusted := newRadius
	if adjusted < MinRadius {
		adjusted = MinRadius
	} else if adjusted > MaxRadius {
		adjusted = MaxRadius
	}

	// Apply updates
	g.RadiusKm = adjusted
	g.UpdatedAt = time.Now().UTC()
	return nil
}

// Deactivate safely deactivates the geofence, preventing further updates or point checks.
// It performs the following steps:
//   1. Checks if the geofence is already inactive; returns an error if so.
//   2. Sets Active = false and updates the UpdatedAt timestamp.
//   3. Returns nil if the deactivation is successful, or an error otherwise.
func (g *Geofence) Deactivate() error {
	// Check if already inactive
	if !g.Active {
		return errors.New("deactivate error: geofence is already inactive")
	}
	// Deactivate the geofence
	g.Active = false
	g.UpdatedAt = time.Now().UTC()
	return nil
}